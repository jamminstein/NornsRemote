import Foundation

/// WebSocket connection to Norns Maiden (matron) on port 5555.
/// Requires the "bus.sp.nanomsg.org" subprotocol for ws-wrapper.
@Observable
final class MaidenWebSocket {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private(set) var isConnected = false
    var onOutput: ((String) -> Void)?

    func connect(host: String, port: Int = 5555) {
        disconnect()
        guard let url = URL(string: "ws://\(host):\(port)") else {
            print("[Maiden] invalid URL")
            return
        }
        print("[Maiden] connecting to \(url) with nanomsg protocol...")

        // ws-wrapper requires the nanomsg subprotocol
        let task = session.webSocketTask(with: url, protocols: ["bus.sp.nanomsg.org"])
        task.resume()
        webSocketTask = task
        isConnected = true
        listenForMessages()
        print("[Maiden] connected")
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    /// Send a Lua command to matron (newline-terminated).
    func sendLua(_ command: String) {
        guard let task = webSocketTask else { return }
        let message = URLSessionWebSocketTask.Message.string(command + "\n")
        task.send(message) { error in
            if let error {
                print("[Maiden] send error: \(error)")
            }
        }
    }

    /// Trigger a screen export on the Norns — save into dust/data so Maiden can serve it.
    func triggerScreenCapture() {
        sendLua("_norns.screen_export_png(\"/home/we/dust/data/screen.png\")")
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.onOutput?(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.onOutput?(text)
                    }
                @unknown default:
                    break
                }
                self?.listenForMessages()
            case .failure(let error):
                print("[Maiden] receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
}
