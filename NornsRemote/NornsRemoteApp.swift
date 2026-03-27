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
        // Mode
        Button(norns.miniMode ? "Full Mode" : "Mini Mode") {
            norns.miniMode.toggle()
            resizeWindow(mini: norns.miniMode)
        }

        Divider()

        // Scripts
        Menu("Load Script") {
            ForEach(norns.scripts, id: \.self) { script in
                Button(script) {
                    norns.loadScript(script)
                }
            }
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

    private func resizeWindow(mini: Bool) {
        guard let window = NSApplication.shared.windows.first else { return }
        if mini {
            window.contentAspectRatio = NSSize(width: 2, height: 1)
            let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y,
                             width: 400, height: 200)
            window.setFrame(frame, display: true, animate: true)
        } else {
            window.contentAspectRatio = NSSize(width: 716, height: 440)
            let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y,
                             width: 740, height: 460)
            window.setFrame(frame, display: true, animate: true)
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
