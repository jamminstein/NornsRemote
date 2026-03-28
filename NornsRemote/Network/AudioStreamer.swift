import Foundation
import AVFoundation
import Network

/// Streams audio from the Norns to the Mac over TCP.
///
/// Flow:
/// 1. Sends Lua commands via Maiden to start `sox` capturing JACK output,
///    piped through `nc` (netcat) on a TCP port.
/// 2. Connects from Mac to receive raw PCM (48kHz, 16-bit signed LE, stereo).
/// 3. Plays through AVAudioEngine.
@Observable
final class AudioStreamer {
    var isStreaming = false
    var level: Float = 0  // current peak level for UI metering

    private let streamPort: UInt16 = 12346
    private var connection: NWConnection?
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let outputFormat: AVAudioFormat

    init() {
        // Standard format for playback: 48kHz stereo float32 non-interleaved
        outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }

    /// Start streaming audio from the norns.
    /// - Parameters:
    ///   - host: norns hostname/IP
    ///   - maiden: MaidenWebSocket to send Lua commands
    func start(host: String, maiden: MaidenWebSocket) {
        guard !isStreaming else { return }

        // 1. Tell norns to start audio capture → TCP stream
        //    sox captures JACK output, pipes raw PCM to netcat listener
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
            player.play()
        } catch {
            print("[Audio] Engine start error: \(error)")
            return
        }

        engine = eng
        playerNode = player
        isStreaming = true

        // 3. Connect TCP to norns after a delay (let sox/nc start)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.connectTCP(host: host)
        }
    }

    /// Stop streaming and clean up norns-side processes.
    func stop(maiden: MaidenWebSocket) {
        isStreaming = false

        // Stop Mac-side playback
        playerNode?.stop()
        engine?.stop()
        connection?.cancel()

        playerNode = nil
        engine = nil
        connection = nil

        // Kill norns-side processes
        maiden.sendLua("os.execute(\"pkill -f NornsRemoteCapture 2>/dev/null\")")
    }

    // MARK: - TCP Connection

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
                print("[Audio] TCP connection failed: \(error)")
                DispatchQueue.main.async { self?.isStreaming = false }
            case .cancelled:
                break
            default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInteractive))
        connection = conn
    }

    private func receiveLoop() {
        guard let conn = connection, isStreaming else { return }

        // Read ~10ms of audio at a time (48000 * 2ch * 2bytes * 0.01s = 1920 bytes)
        conn.receive(minimumIncompleteLength: 1920, maximumLength: 19200) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.playPCMData(data)
            }

            if isComplete || error != nil {
                DispatchQueue.main.async { self.isStreaming = false }
                return
            }

            self.receiveLoop()
        }
    }

    // MARK: - PCM Playback

    private func playPCMData(_ data: Data) {
        guard let playerNode = playerNode else { return }

        // Input: interleaved Int16 stereo (4 bytes per frame)
        let frameCount = UInt32(data.count / 4)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount)
        else { return }

        buffer.frameLength = frameCount

        // De-interleave Int16 → Float32
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
