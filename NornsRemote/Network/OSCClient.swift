import Foundation
import Network

/// Sends OSC messages to the Norns over UDP.
@Observable
final class OSCClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "osc-client")
    private(set) var isReady = false

    func connect(host: String, port: UInt16 = 10111) {
        connection?.cancel()
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let conn = NWConnection(host: nwHost, port: nwPort, using: .udp)

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isReady = true
            case .failed, .cancelled:
                self?.isReady = false
            default:
                break
            }
        }

        conn.start(queue: queue)
        connection = conn
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isReady = false
    }

    /// Send encoder turn: n = 1/2/3, delta = signed integer.
    func sendEncoder(_ n: Int, delta: Int) {
        let msg = OSCMessage(
            address: "/remote/enc",
            arguments: [.int32(Int32(n)), .int32(Int32(delta))]
        )
        send(msg)
    }

    /// Send key press/release: n = 1/2/3, state = 0 (release) or 1 (press).
    func sendKey(_ n: Int, state: Int) {
        let msg = OSCMessage(
            address: "/remote/key",
            arguments: [.int32(Int32(n)), .int32(Int32(state))]
        )
        send(msg)
    }

    private func send(_ message: OSCMessage) {
        guard let connection, isReady else { return }
        let data = message.encode()
        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("[OSC] send error: \(error)")
            }
        })
    }
}
