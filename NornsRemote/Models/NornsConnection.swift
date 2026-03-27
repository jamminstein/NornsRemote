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
    enum ViewMode: String, CaseIterable {
        case full, custom, mini
    }
    var viewMode: ViewMode = .full
    var isEditingLayout = false
    var customLayout = CustomLayout.load()

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

    func saveCustomLayout() {
        customLayout.save()
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

// MARK: - Custom Layout

struct ComponentLayout: Codable, Equatable {
    var x: CGFloat    // center X as fraction of window width (0–1)
    var y: CGFloat    // center Y as fraction of window height (0–1)
    var scale: CGFloat // size multiplier (1.0 = default)
}

struct CustomLayout: Codable, Equatable {
    // Defaults match the full-mode photo proportions
    var screen = ComponentLayout(x: 0.314, y: 0.704, scale: 1.0)
    var k1 = ComponentLayout(x: 0.146, y: 0.376, scale: 1.0)
    var e1 = ComponentLayout(x: 0.289, y: 0.345, scale: 1.0)
    var e2 = ComponentLayout(x: 0.661, y: 0.580, scale: 1.0)
    var e3 = ComponentLayout(x: 0.839, y: 0.580, scale: 1.0)
    var k2 = ComponentLayout(x: 0.661, y: 0.803, scale: 1.0)
    var k3 = ComponentLayout(x: 0.819, y: 0.803, scale: 1.0)

    static let baseEncoder: CGFloat = 65
    static let baseButtonK1: CGFloat = 47
    static let baseButton: CGFloat = 43
    static let baseScreenW: CGFloat = 320
    static let baseScreenH: CGFloat = 160

    private static let key = "NornsCustomLayout"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> CustomLayout {
        guard let data = UserDefaults.standard.data(forKey: key),
              let layout = try? JSONDecoder().decode(CustomLayout.self, from: data)
        else { return CustomLayout() }
        return layout
    }
}
