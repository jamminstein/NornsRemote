import Foundation
import AVFoundation
import Network

/// Streams audio from the Norns to the Mac over TCP.
///
/// Flow:
/// 1. Sends Lua commands via Maiden to start `sox` capturing JACK output,
///    piped through `nc` (netcat) on a TCP port.
/// 2. Connects from Mac to receive raw PCM (48kHz, 16-bit signed LE, stereo).
/// 3. Buffers ~200ms then plays through AVAudioEngine in large chunks.
@Observable
final class AudioStreamer {
    var isStreaming = false
    var level: Float = 0

    private let streamPort: UInt16 = 12346
    private var connection: NWConnection?
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let outputFormat: AVAudioFormat

    // Accumulator: collect data into ~100ms chunks before scheduling
    private let audioQueue = DispatchQueue(label: "audio-streamer", qos: .userInteractive)
    private var accumulator = Data()
    // 48000 samples/s * 2ch * 2bytes * 0.1s = 19200 bytes per 100ms chunk
    private let chunkSize = 19200
    // Buffer 200ms before starting playback to avoid underruns
    private let prebufferSize = 19200 * 2
    private var prebuffered = false

    init() {
        outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }

    func start(host: String, maiden: MaidenWebSocket) {
        guard !isStreaming else { return }

        // 1. Tell norns to start audio capture → TCP stream
        let port = streamPort
        maiden.sendLua("""
        os.execute("pkill -f NornsRemoteCapture 2>/dev/null; sleep 0.2")
        os.execute("sox -t jack 'NornsRemoteCapture' -t raw -r 48000 -c 2 -b 16 -e signed - 2>/dev/null | nc -l -p \(port) &")
        os.execute("sleep 0.5 && jack_connect crone:output_1 NornsRemoteCapture:input_1 2>/dev/null && jack_connect crone:output_2 NornsRemoteCapture:input_2 2>/dev/null &")
        """)

        // 2. Setup AVAudioEngine
        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: eng.mainMixerNode, format: outputFormat)

        do {
            try eng.start()
        } catch {
            print("[Audio] Engine start error: \(error)")
            return
        }

        engine = eng
        playerNode = player
        isStreaming = true
        prebuffered = false
        accumulator = Data()

        // 3. Connect TCP after a delay (let sox/nc start on norns)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.connectTCP(host: host)
        }
    }

    func stop(maiden: MaidenWebSocket) {
        isStreaming = false
        prebuffered = false

        playerNode?.stop()
        engine?.stop()
        connection?.cancel()

        playerNode = nil
        engine = nil
        connection = nil
        accumulator = Data()

        maiden.sendLua("os.execute(\"pkill -f NornsRemoteCapture 2>/dev/null\")")
    }

    // MARK: - TCP

    private func connectTCP(host: String) {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: streamPort)!
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[Audio] TCP connected to \(host):\(self?.streamPort ?? 0)")
                self?.receiveLoop()
            case .failed(let error):
                print("[Audio] TCP failed: \(error)")
                DispatchQueue.main.async { self?.isStreaming = false }
            case .cancelled:
                break
            default:
                break
            }
        }

        conn.start(queue: audioQueue)
        connection = conn
    }

    private func receiveLoop() {
        guard let conn = connection, isStreaming else { return }

        // Request large chunks to reduce scheduling overhead
        conn.receive(minimumIncompleteLength: 4096, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.audioQueue.async {
                    self.accumulateAndPlay(data)
                }
            }

            if isComplete || error != nil {
                DispatchQueue.main.async { self.isStreaming = false }
                return
            }

            self.receiveLoop()
        }
    }

    // MARK: - Buffered Playback

    private func accumulateAndPlay(_ data: Data) {
        accumulator.append(data)

        // Prebuffer phase: wait until we have enough data
        if !prebuffered {
            if accumulator.count >= prebufferSize {
                prebuffered = true
                playerNode?.play()
                print("[Audio] Prebuffer complete, starting playback (\(accumulator.count) bytes)")
            } else {
                return
            }
        }

        // Schedule chunks when we have enough
        while accumulator.count >= chunkSize {
            let chunk = accumulator.prefix(chunkSize)
            accumulator.removeFirst(chunkSize)
            scheduleChunk(Data(chunk))
        }
    }

    private func scheduleChunk(_ data: Data) {
        guard let playerNode = playerNode else { return }

        let frameCount = UInt32(data.count / 4)  // 4 bytes per frame (2ch * 16bit)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount)
        else { return }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            guard let left = buffer.floatChannelData?[0],
                  let right = buffer.floatChannelData?[1] else { return }

            var peak: Float = 0
            for i in 0..<Int(frameCount) {
                let l = Float(samples[i * 2]) / 32768.0
                let r = Float(samples[i * 2 + 1]) / 32768.0
                left[i] = l
                right[i] = r
                peak = max(peak, abs(l), abs(r))
            }

            DispatchQueue.main.async { [weak self] in
                self?.level = peak
            }
        }

        playerNode.scheduleBuffer(buffer)
    }
}
