import Foundation
import AppKit

/// Central model managing the connection to a Norns device.
@Observable
final class NornsConnection {
    var isConnected = false
    var connectionHealth: ConnectionHealth = .disconnected
    var host: String = "norns.local"
    var screenImage: CGImage?
    var scripts: [String] = []
    var currentScript: String = ""
    var miniMode = false

    private var failCount = 0

    enum ConnectionHealth {
        case connected, lagging, disconnected

        var color: NSColor {
            switch self {
            case .connected: return .systemGreen
            case .lagging: return .systemOrange
            case .disconnected: return .systemRed
            }
        }
    }

    let osc = OSCClient()
    let maiden = MaidenWebSocket()
    let screenFetcher = ScreenFetcher()

    private var pollingTask: Task<Void, Never>?

    func connect() {
        let h = host
        print("[Norns] Connecting to \(h)...")
        osc.connect(host: h, port: 10111)
        maiden.connect(host: h, port: 5555)
        screenFetcher.configure(host: h)

        // Start polling after a short delay
        pollingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            print("[Norns] Starting screen polling...")
            await pollScreen()
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        osc.disconnect()
        maiden.disconnect()
        isConnected = false
        screenImage = nil
    }

    // MARK: - Script Launcher

    func fetchScripts() {
        let h = host
        Task {
            guard let url = URL(string: "http://\(h)/api/v1/dust/code/") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let entries = json["entries"] as? [[String: Any]] {
                    let names = entries.compactMap { $0["name"] as? String }.sorted()
                    await MainActor.run { self.scripts = names }
                }
            } catch {
                print("[Scripts] fetch error: \(error)")
            }
        }
    }

    func loadScript(_ name: String) {
        currentScript = name
        maiden.sendLua("norns.script.load(\"code/\(name)/\(name).lua\")")
    }

    func encoderTurn(_ n: Int, delta: Int) {
        if !osc.isReady {
            osc.connect(host: host, port: 10111)
        }
        // E1 is system volume — needs a bigger delta to feel responsive
        let scaledDelta = (n == 1) ? delta * 2 : delta
        osc.sendEncoder(n, delta: scaledDelta)
    }

    func keyPress(_ n: Int) {
        osc.sendKey(n, state: 1)
    }

    func keyRelease(_ n: Int) {
        osc.sendKey(n, state: 0)
    }

    // MARK: - Screen Polling

    @MainActor
    private func pollScreen() async {
        while !Task.isCancelled {
            // Trigger screen export
            maiden.triggerScreenCapture()

            // Wait a bit for the PNG to be written
            try? await Task.sleep(for: .milliseconds(80))

            // Fetch the screenshot
            if let image = await screenFetcher.fetchScreen() {
                screenImage = image
                failCount = 0
                isConnected = true
                connectionHealth = .connected
            } else {
                failCount += 1
                if failCount >= 10 {
                    connectionHealth = .disconnected
                    isConnected = false
                    // Try to reconnect
                    maiden.connect(host: host, port: 5555)
                    failCount = 0
                } else if failCount >= 3 {
                    connectionHealth = .lagging
                }
            }

            // ~5 FPS to be safe
            try? await Task.sleep(for: .milliseconds(120))
        }
    }
}
