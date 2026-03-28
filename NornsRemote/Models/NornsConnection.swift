import Foundation
import AppKit
import UniformTypeIdentifiers

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
    enum BackgroundStyle: String, Codable, CaseIterable {
        case original, black, white, gradient, glass, punk
    }
    var viewMode: ViewMode = .full
    var isEditingLayout = false
    var customLayout = CustomLayout.load()
    var customBackground: BackgroundStyle = {
        BackgroundStyle(rawValue: UserDefaults.standard.string(forKey: "NornsCustomBG") ?? "black") ?? .black
    }() {
        didSet { UserDefaults.standard.set(customBackground.rawValue, forKey: "NornsCustomBG") }
    }

    // Screenshot & Recording
    var isRecording = false
    private var recordedFrames: [CGImage] = []

    // Script Parameters
    var scriptParams: [ScriptParam] = []
    var showParams = false
    private var pendingParams: [ScriptParam] = []

    struct ScriptParam: Identifiable {
        let id: String
        let name: String
        let value: String
    }

    // Multi-Device
    var devices: [NornsDevice] = {
        if let data = UserDefaults.standard.data(forKey: "NornsDevices"),
           let devs = try? JSONDecoder().decode([NornsDevice].self, from: data) {
            return devs
        }
        return [NornsDevice(name: "norns", host: "norns.local")]
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(devices) {
                UserDefaults.standard.set(data, forKey: "NornsDevices")
            }
        }
    }

    struct NornsDevice: Identifiable, Codable, Hashable {
        var id: String { host }
        var name: String
        var host: String
    }

    // Audio Control
    var isMuted = false
    var isStreamingAudio = false

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
    let audioStreamer = AudioStreamer()

    private var pollingTask: Task<Void, Never>?

    func connect() {
        let h = host
        print("[Norns] Connecting to \(h)...")
        osc.connect(host: h, port: 10111)
        maiden.connect(host: h, port: 5555)
        screenFetcher.configure(host: h)

        maiden.onOutput = { [weak self] text in
            self?.handleMaidenOutput(text)
        }

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

    // MARK: - Script Management (install/remove via Maiden project manager)

    var installedProjects: [String] = []
    var githubUsername: String {
        get { UserDefaults.standard.string(forKey: "NornsGitHubUser") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "NornsGitHubUser") }
    }
    var userRepos: [GitHubRepo] = []
    var communityScripts: [GitHubRepo] = []

    struct GitHubRepo: Identifiable, Hashable {
        let id: String
        let name: String
        let url: String
        let description: String
        var isInstalled: Bool
    }

    func fetchInstalledProjects() {
        let h = host
        Task {
            guard let url = URL(string: "http://\(h)/api/v1/projects") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let names = json.compactMap { $0["name"] as? String }
                    await MainActor.run { self.installedProjects = names }
                }
            } catch {
                print("[Projects] fetch error: \(error)")
            }
        }
    }

    func fetchUserRepos() {
        let user = githubUsername
        guard !user.isEmpty else { return }
        Task {
            guard let url = URL(string: "https://api.github.com/users/\(user)/repos?per_page=100&sort=updated") else { return }
            do {
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let repos: [GitHubRepo] = json.compactMap { item in
                        guard let name = item["name"] as? String,
                              let htmlUrl = item["html_url"] as? String else { return nil }
                        let desc = item["description"] as? String ?? ""
                        let installed = self.installedProjects.contains(name)
                        return GitHubRepo(id: name, name: name, url: htmlUrl, description: desc, isInstalled: installed)
                    }
                    await MainActor.run { self.userRepos = repos }
                }
            } catch {
                print("[GitHub] fetch error: \(error)")
            }
        }
    }

    func installScript(url: String) {
        let h = host
        Task {
            guard let apiUrl = URL(string: "http://\(h)/api/v1/projects/install") else { return }
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["url": url + ".git"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    print("[Install] success: \(url)")
                    await MainActor.run {
                        fetchInstalledProjects()
                        fetchScripts()
                        fetchUserRepos()
                    }
                }
            } catch {
                print("[Install] error: \(error)")
            }
        }
    }

    func removeScript(name: String) {
        let h = host
        Task {
            guard let apiUrl = URL(string: "http://\(h)/api/v1/projects/remove") else { return }
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["name": name]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    print("[Remove] success: \(name)")
                    await MainActor.run {
                        fetchInstalledProjects()
                        fetchScripts()
                        fetchUserRepos()
                    }
                }
            } catch {
                print("[Remove] error: \(error)")
            }
        }
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

    // MARK: - Screenshot & Recording

    func saveScreenshot() {
        guard let image = screenImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let timestamp = Int(Date().timeIntervalSince1970)
        panel.nameFieldStringValue = "norns-\(currentScript.isEmpty ? "screen" : currentScript)-\(timestamp).png"
        if panel.runModal() == .OK, let url = panel.url {
            let rep = NSBitmapImageRep(cgImage: image)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }

    func copyScreenshot() {
        guard let image = screenImage else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let nsImage = NSImage(data: data)
        NSPasteboard.general.clearContents()
        if let img = nsImage {
            NSPasteboard.general.writeObjects([img])
        }
    }

    func toggleRecording() {
        if isRecording {
            isRecording = false
            guard !recordedFrames.isEmpty else { return }
            let frames = recordedFrames
            recordedFrames = []
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.gif]
            let timestamp = Int(Date().timeIntervalSince1970)
            panel.nameFieldStringValue = "norns-recording-\(timestamp).gif"
            if panel.runModal() == .OK, let url = panel.url {
                Task.detached { Self.createGIF(frames: frames, url: url) }
            }
        } else {
            recordedFrames = []
            isRecording = true
        }
    }

    private static func createGIF(frames: [CGImage], url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
        ) else { return }
        let gifProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(dest, gifProps as CFDictionary)
        let frameProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.2]
        ]
        for frame in frames {
            CGImageDestinationAddImage(dest, frame, frameProps as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
        print("[GIF] Saved \(frames.count) frames to \(url.path)")
    }

    // MARK: - Script Parameters

    func fetchScriptParams() {
        pendingParams = []
        maiden.sendLua(
            "for i=1,params.count do local p=params:lookup_param(i); " +
            "print('RPARAM:'..p.id..':'..p.name..':'..(p:string() or '')) end; " +
            "print('RPARAM_END')"
        )
    }

    private func handleMaidenOutput(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("RPARAM:") {
                let parts = String(trimmed.dropFirst(7)).components(separatedBy: ":")
                if parts.count >= 3 {
                    let param = ScriptParam(
                        id: parts[0],
                        name: parts[1],
                        value: parts[2...].joined(separator: ":")
                    )
                    pendingParams.append(param)
                }
            } else if trimmed.contains("RPARAM_END") {
                let finished = pendingParams
                pendingParams = []
                Task { @MainActor in
                    self.scriptParams = finished
                }
            }
        }
    }

    func setParam(id: String, delta: Int) {
        maiden.sendLua("params:delta('\(id)', \(delta))")
        // Refresh after a short delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            fetchScriptParams()
        }
    }

    // MARK: - Community Scripts

    func searchCommunityScripts(query: String = "norns") {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        Task {
            guard let url = URL(string:
                "https://api.github.com/search/repositories?q=\(q)+topic:norns&sort=stars&per_page=50"
            ) else { return }
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {
                    let repos = items.compactMap { item -> GitHubRepo? in
                        guard let name = item["name"] as? String,
                              let htmlUrl = item["html_url"] as? String else { return nil }
                        let desc = item["description"] as? String ?? ""
                        let stars = item["stargazers_count"] as? Int ?? 0
                        let installed = self.installedProjects.contains(name)
                        return GitHubRepo(
                            id: "\(htmlUrl)",
                            name: name,
                            url: htmlUrl,
                            description: "\(desc)\(stars > 0 ? " ★\(stars)" : "")",
                            isInstalled: installed
                        )
                    }
                    await MainActor.run { self.communityScripts = repos }
                }
            } catch {
                print("[Community] search error: \(error)")
            }
        }
    }

    // MARK: - Multi-Device

    func switchDevice(_ device: NornsDevice) {
        disconnect()
        host = device.host
        connect()
        fetchScripts()
        fetchInstalledProjects()
    }

    func addDevice(name: String, host: String) {
        let dev = NornsDevice(name: name, host: host)
        if !devices.contains(where: { $0.host == host }) {
            devices.append(dev)
        }
    }

    func removeDevice(_ device: NornsDevice) {
        devices.removeAll { $0.host == device.host }
    }

    // MARK: - Audio Control

    func toggleMute() {
        if isMuted {
            // Restore volume
            maiden.sendLua("_norns.audio_monitor_level(_norns_remote_saved_vol or 1.0)")
            maiden.sendLua("_norns.audio_output_level(_norns_remote_saved_out or 1.0)")
            isMuted = false
        } else {
            // Save current levels then mute
            maiden.sendLua("_norns_remote_saved_vol = _norns.audio_get_monitor_level and _norns.audio_get_monitor_level() or 1.0")
            maiden.sendLua("_norns_remote_saved_out = _norns.audio_get_output_level and _norns.audio_get_output_level() or 1.0")
            maiden.sendLua("_norns.audio_monitor_level(0)")
            maiden.sendLua("_norns.audio_output_level(0)")
            isMuted = true
        }
    }

    func volumeUp() {
        // Turn E1 (system volume) up
        encoderTurn(1, delta: 1)
    }

    func volumeDown() {
        // Turn E1 (system volume) down
        encoderTurn(1, delta: -1)
    }

    func toggleAudioStream() {
        if isStreamingAudio {
            audioStreamer.stop(maiden: maiden)
            isStreamingAudio = false
        } else {
            audioStreamer.start(host: host, maiden: maiden)
            isStreamingAudio = true
        }
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
                if isRecording { recordedFrames.append(image) }
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
