import SwiftUI

@main
struct NornsRemoteApp: App {
    @State private var norns = NornsConnection()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NornsView()
                .environment(norns)
                .frame(minWidth: 400, minHeight: 200)
                .onAppear {
                    appDelegate.norns = norns
                    appDelegate.setupFloatingWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 740, height: 460)

        // Menu bar extra — tiny norns icon in the menu bar
        MenuBarExtra {
            MenuBarView()
                .environment(norns)
        } label: {
            Image(systemName: "dial.low")
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @Environment(NornsConnection.self) private var norns

    var body: some View {
        // Device switcher
        Menu("Device: \(norns.host)") {
            ForEach(norns.devices) { device in
                Button(device.host == norns.host ? "\(device.name) ✓" : device.name) {
                    norns.switchDevice(device)
                }
            }
            Divider()
            Button("Add Device...") { promptAddDevice() }
            if norns.devices.count > 1 {
                Button("Remove Current...") {
                    if let dev = norns.devices.first(where: { $0.host == norns.host }) {
                        norns.removeDevice(dev)
                        if let first = norns.devices.first {
                            norns.switchDevice(first)
                        }
                    }
                }
            }
        }

        Divider()

        // Mode
        Button(norns.viewMode == .full ? "Full Mode ✓" : "Full Mode") {
            norns.viewMode = .full
            norns.isEditingLayout = false
            resizeWindow(mode: .full)
        }
        Button(norns.viewMode == .custom ? "Custom Mode ✓" : "Custom Mode") {
            norns.viewMode = .custom
            resizeWindow(mode: .custom)
        }
        Button(norns.viewMode == .mini ? "Mini Mode ✓" : "Mini Mode") {
            norns.viewMode = .mini
            norns.isEditingLayout = false
            resizeWindow(mode: .mini)
        }
        if norns.viewMode == .custom {
            Divider()
            Button(norns.isEditingLayout ? "Done Editing" : "Edit Layout") {
                norns.isEditingLayout.toggle()
                if !norns.isEditingLayout { norns.saveCustomLayout() }
            }
            Menu("Background") {
                ForEach(NornsConnection.BackgroundStyle.allCases, id: \.self) { style in
                    Button(norns.customBackground == style ? "\(style.rawValue.capitalized) ✓" : style.rawValue.capitalized) {
                        norns.customBackground = style
                    }
                }
            }
            Button("Reset Layout") {
                norns.customLayout = CustomLayout()
                norns.saveCustomLayout()
            }
        }

        Divider()

        // Screenshot & Recording
        Menu("Capture") {
            Button("Save Screenshot...") { norns.saveScreenshot() }
            Button("Copy Screenshot") { norns.copyScreenshot() }
            Divider()
            Button(norns.isRecording ? "Stop Recording & Save..." : "Start Recording GIF") {
                norns.toggleRecording()
            }
        }

        Divider()

        // Script Parameters
        Button(norns.showParams ? "Hide Parameters" : "Show Parameters") {
            norns.showParams.toggle()
            if norns.showParams { norns.fetchScriptParams() }
        }

        Divider()

        // Load Script
        Menu("Load Script") {
            ForEach(norns.scripts, id: \.self) { script in
                Button(script) {
                    norns.loadScript(script)
                }
            }
        }

        // My Scripts (GitHub)
        Menu("My Scripts") {
            if norns.githubUsername.isEmpty {
                Button("Set GitHub Username...") {
                    promptGitHubUsername()
                }
            } else {
                Text("GitHub: \(norns.githubUsername)")
                Button("Change Username...") {
                    promptGitHubUsername()
                }
                Button("Refresh") {
                    norns.fetchInstalledProjects()
                    norns.fetchUserRepos()
                }
                Divider()
                if norns.userRepos.isEmpty {
                    Text("No repos found")
                } else {
                    ForEach(norns.userRepos) { repo in
                        if repo.isInstalled {
                            Menu("\(repo.name) ✓") {
                                Button("Load") { norns.loadScript(repo.name) }
                                Button("Remove") { norns.removeScript(name: repo.name) }
                            }
                        } else {
                            Button("Install \(repo.name)") {
                                norns.installScript(url: repo.url)
                            }
                        }
                    }
                }
            }
        }

        // Community Scripts
        Menu("Community Scripts") {
            Button("Search...") { promptCommunitySearch() }
            Button("Browse Popular") { norns.searchCommunityScripts() }
            if !norns.communityScripts.isEmpty {
                Divider()
                ForEach(norns.communityScripts) { repo in
                    if repo.isInstalled {
                        Menu("\(repo.name) ✓") {
                            Text(repo.description)
                            Button("Load") { norns.loadScript(repo.name) }
                            Button("Remove") { norns.removeScript(name: repo.name) }
                        }
                    } else {
                        Menu(repo.name) {
                            Text(repo.description)
                            Button("Install") { norns.installScript(url: repo.url) }
                        }
                    }
                }
            }
        }

        Divider()

        // Audio Control
        Menu("Audio") {
            Button(norns.isStreamingAudio ? "⏹ Stop Streaming" : "▶ Stream to Mac") {
                norns.toggleAudioStream()
            }
            Divider()
            Button(norns.isMuted ? "🔇 Unmute" : "🔈 Mute") {
                norns.toggleMute()
            }
            Divider()
            let pct = Int(norns.volume * 100)
            let bar = String(repeating: "█", count: pct / 10) + String(repeating: "░", count: 10 - pct / 10)
            Text("Vol: \(bar) \(pct)%")
                .font(.system(size: 11, design: .monospaced))
            Button("    ＋ Volume Up") { norns.setVolume(min(1, norns.volume + 0.1)) }
            Button("    ﹣ Volume Down") { norns.setVolume(max(0, norns.volume - 0.1)) }
        }

        Divider()

        // Show / Hide
        Button("Show Window") {
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Button("Hide Window") {
            NSApplication.shared.windows.first?.orderOut(nil)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Alerts

    private func promptGitHubUsername() {
        let alert = NSAlert()
        alert.messageText = "GitHub Username"
        alert.informativeText = "Enter your GitHub username to browse your norns scripts:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = norns.githubUsername
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn {
            norns.githubUsername = input.stringValue
            norns.fetchInstalledProjects()
            norns.fetchUserRepos()
        }
    }

    private func promptAddDevice() {
        let alert = NSAlert()
        alert.messageText = "Add Norns Device"
        alert.informativeText = "Enter the device name and hostname/IP:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 56))
        stack.orientation = .vertical
        stack.spacing = 8
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        nameField.placeholderString = "Name (e.g. norns-shield)"
        let hostField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        hostField.placeholderString = "Host (e.g. norns.local or 192.168.1.50)"
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(hostField)
        alert.accessoryView = stack

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.isEmpty ? hostField.stringValue : nameField.stringValue
            let host = hostField.stringValue
            if !host.isEmpty {
                norns.addDevice(name: name, host: host)
            }
        }
    }

    private func promptCommunitySearch() {
        let alert = NSAlert()
        alert.messageText = "Search Community Scripts"
        alert.informativeText = "Search for norns scripts on GitHub:"
        alert.addButton(withTitle: "Search")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "e.g. sequencer, granular, drone"
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn {
            let query = input.stringValue.isEmpty ? "norns" : input.stringValue
            norns.searchCommunityScripts(query: query)
        }
    }

    private func resizeWindow(mode: NornsConnection.ViewMode) {
        guard let window = NSApplication.shared.windows.first else { return }
        let origin = window.frame.origin
        switch mode {
        case .mini:
            window.contentAspectRatio = NSSize(width: 2, height: 1)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: 400, height: 200),
                          display: true, animate: true)
        case .full:
            window.contentAspectRatio = NSSize(width: 716, height: 440)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: 740, height: 460),
                          display: true, animate: true)
        case .custom:
            window.resizeIncrements = NSSize(width: 1, height: 1)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var norns: NornsConnection?

    func setupFloatingWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let window = NSApplication.shared.windows.first else { return }
            window.level = .floating
            // Borderless — no system chrome at all
            window.styleMask = [.borderless, .resizable]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.contentAspectRatio = NSSize(width: 716, height: 440)
            window.isMovableByWindowBackground = true
        }
    }
}
