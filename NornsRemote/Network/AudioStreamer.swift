import Foundation
import AVFoundation
import Network

/// Streams audio from the Norns to the Mac over TCP.
///
/// Pipeline on norns: JACK capture → raw PCM → nc (netcat) → TCP → Mac
/// Tries ffmpeg first, falls back to jack_capture, then arecord+JACK ALSA plugin.
@Observable
final class AudioStreamer {
    var isStreaming = false
    var level: Float = 0
    var statusMessage: String = ""

    private let streamPort: UInt16 = 12346
    private var connection: NWConnection?
    private(set) var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let outputFormat: AVAudioFormat

    private let audioQueue = DispatchQueue(label: "audio-streamer", qos: .userInteractive)
    private var accumulator = Data()
    private let chunkSize = 19200       // ~100ms of 48kHz stereo 16-bit
    private let prebufferSize = 38400   // ~200ms prebuffer
    private var prebuffered = false

    init() {
        outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }

    func start(host: String, maiden: MaidenWebSocket) {
        guard !isStreaming else { return }

        statusMessage = "Starting stream…"
        isStreaming = true
        prebuffered = false
        accumulator = Data()

        let port = streamPort

        // 1. Kill any previous stream processes (aggressive cleanup)
        maiden.sendLua("os.execute([[pkill -9 -f NornsRemoteAudio 2>/dev/null]])")
        maiden.sendLua("os.execute([[pkill -9 -f 'nc.*\(port)' 2>/dev/null]])")
        maiden.sendLua("os.execute([[sleep 0.5]])")

        // 2. Start ffmpeg → nc pipeline with -k (keep-alive: re-accepts after disconnect)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            maiden.sendLua("os.execute([[ffmpeg -f jack -i NornsRemoteAudio -f s16le -ar 48000 -ac 2 pipe:1 2>/dev/null | nc -lk -p \(port) &]])")
            print("[Audio] Sent ffmpeg+nc start command (keep-alive)")
        }

        // 3. Connect JACK ports after ffmpeg registers with JACK
        DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
            maiden.sendLua("os.execute([[jack_connect crone:output_1 NornsRemoteAudio:input_1]])")
            maiden.sendLua("os.execute([[jack_connect crone:output_2 NornsRemoteAudio:input_2]])")
            print("[Audio] Sent jack_connect commands")
        }

        // 3. Setup AVAudioEngine on Mac side
        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: eng.mainMixerNode, format: outputFormat)

        do {
            try eng.start()
        } catch {
            print("[Audio] Engine start error: \(error)")
            statusMessage = "Engine error: \(error.localizedDescription)"
            isStreaming = false
            return
        }

        engine = eng
        playerNode = player

        // 4. Connect TCP after giving norns time to start the pipeline
        //    Retry up to 5 times if connection refused (nc not ready yet)
        DispatchQueue.global().asyncAfter(deadline: .now() + 4.5) { [weak self] in
            guard let self = self, self.isStreaming else { return }
            print("[Audio] Connecting TCP to \(host):\(port)...")
            self.statusMessage = "Connecting…"
            self.connectTCP(host: host, retriesLeft: 5)
        }
    }

    func stop(maiden: MaidenWebSocket) {
        isStreaming = false
        prebuffered = false
        statusMessage = ""

        playerNode?.stop()
        engine?.stop()
        connection?.cancel()

        playerNode = nil
        engine = nil
        connection = nil
        accumulator = Data()

        // Kill everything on norns
        maiden.sendLua("os.execute([[pkill -9 -f NornsRemoteAudio 2>/dev/null]])")
        maiden.sendLua("os.execute([[pkill -9 -f 'nc.*\(streamPort)' 2>/dev/null]])")
    }

    // MARK: - TCP

    private var retryHost: String = ""

    private func connectTCP(host: String, retriesLeft: Int) {
        guard isStreaming else { return }

        retryHost = host
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: streamPort)!
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        let params = NWParameters(tls: nil, tcp: tcp)
        let conn = NWConnection(host: nwHost, port: nwPort, using: params)

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("[Audio] TCP connected to \(host):\(self.streamPort)")
                DispatchQueue.main.async {
                    self.statusMessage = "Connected — waiting for audio…"
                }
                self.receiveLoop()
            case .waiting(let error):
                print("[Audio] TCP waiting: \(error) — retries left: \(retriesLeft)")
                conn.cancel()
                if retriesLeft > 0 {
                    DispatchQueue.main.async {
                        self.statusMessage = "Retrying… (\(retriesLeft))"
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                        self.connectTCP(host: host, retriesLeft: retriesLeft - 1)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "Connection failed"
                        self.isStreaming = false
                    }
                }
            case .failed(let error):
                print("[Audio] TCP failed: \(error) — retries left: \(retriesLeft)")
                conn.cancel()
                if retriesLeft > 0 {
                    DispatchQueue.main.async {
                        self.statusMessage = "Retrying… (\(retriesLeft))"
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                        self.connectTCP(host: host, retriesLeft: retriesLeft - 1)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "Connection failed"
                        self.isStreaming = false
                    }
                }
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

        conn.receive(minimumIncompleteLength: 4096, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.accumulateAndPlay(data)
            }

            if isComplete || error != nil {
                print("[Audio] Stream ended: complete=\(isComplete), error=\(String(describing: error))")
                DispatchQueue.main.async {
                    self.statusMessage = "Stream ended"
                    self.isStreaming = false
                }
                return
            }

            self.receiveLoop()
        }
    }

    // MARK: - Buffered Playback

    private func accumulateAndPlay(_ data: Data) {
        accumulator.append(data)

        if !prebuffered {
            if accumulator.count >= prebufferSize {
                prebuffered = true
                playerNode?.play()
                print("[Audio] Prebuffer complete (\(accumulator.count) bytes), starting playback")
                DispatchQueue.main.async {
                    self.statusMessage = "Playing"
                }
            } else {
                return
            }
        }

        while accumulator.count >= chunkSize {
            let chunk = accumulator.prefix(chunkSize)
            accumulator.removeFirst(chunkSize)
            scheduleChunk(Data(chunk))
        }
    }

    private func scheduleChunk(_ data: Data) {
        guard let playerNode = playerNode else { return }

        let frameCount = UInt32(data.count / 4)
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
