import SwiftUI

struct NornsView: View {
    @Environment(NornsConnection.self) private var norns

    var body: some View {
        Group {
            if norns.miniMode {
                miniView
            } else {
                fullView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            norns.connect()
            norns.fetchScripts()
        }
        .onDisappear {
            norns.disconnect()
        }
    }

    // MARK: - Mini Mode

    private var miniView: some View {
        GeometryReader { geo in
            ScreenView(
                image: norns.screenImage,
                width: geo.size.width - 12,
                height: geo.size.height - 12,
                connectionHealth: norns.connectionHealth
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color.black)
            .contextMenu { contextMenuItems }
        }
        .ignoresSafeArea()
    }

    // MARK: - Full Hardware View

    private let cr: CGFloat = 16

    private var fullView: some View {
        GeometryReader { geo in
            // Real norns proportions: ~1.55:1
            let bw: CGFloat = 700
            let bh: CGFloat = 452
            let scale = min(geo.size.width / (bw + 16), geo.size.height / (bh + 16))
            let w: CGFloat = bw * scale
            let h: CGFloat = bh * scale

            ZStack {
                // Fill window with body color
                Color(red: 0.70, green: 0.67, blue: 0.64)
                    .contextMenu { contextMenuItems }

                // Main body
                RoundedRectangle(cornerRadius: 6 * scale)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.69, blue: 0.66),
                                Color(red: 0.68, green: 0.65, blue: 0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)

                // Components — pixel-measured from norns photo (700×452 grid)
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: w, height: h)

                    // K1 — upper left
                    ButtonView(size: 47 * scale,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                        .position(x: 102 * scale, y: 170 * scale)

                    // E1 — right of K1
                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                    .position(x: 202 * scale, y: 156 * scale)

                    // Screen — lower left, 128×64 OLED (2:1)
                    ScreenView(
                        image: norns.screenImage,
                        width: 292 * scale,
                        height: 146 * scale,
                        connectionHealth: norns.connectionHealth
                    )
                    .position(x: 220 * scale, y: 318 * scale)

                    // E2 — right side
                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                    .position(x: 463 * scale, y: 262 * scale)

                    // E3 — far right, same height as E2
                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                    .position(x: 587 * scale, y: 262 * scale)

                    // K2 — directly below E2
                    ButtonView(size: 43 * scale,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                        .position(x: 463 * scale, y: 363 * scale)

                    // K3 — below E3, slightly inward
                    ButtonView(size: 43 * scale,
                              onPress: { norns.keyPress(3) },
                              onRelease: { norns.keyRelease(3) })
                        .position(x: 573 * scale, y: 363 * scale)
                }
                .frame(width: w, height: h)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Toggle("Mini Mode", isOn: Binding(
            get: { norns.miniMode },
            set: { newVal in
                norns.miniMode = newVal
                resizeWindow(mini: newVal)
            }
        ))

        Divider()

        Menu("Load Script") {
            ForEach(norns.scripts, id: \.self) { script in
                Button(script) {
                    norns.loadScript(script)
                }
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Window Resize

    private func resizeWindow(mini: Bool) {
        guard let window = NSApplication.shared.windows.first else { return }
        if mini {
            window.contentAspectRatio = NSSize(width: 2, height: 1)
            window.contentMinSize = NSSize(width: 400, height: 200)
            window.minSize = NSSize(width: 400, height: 200)
            let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y,
                             width: 400, height: 200)
            window.setFrame(frame, display: true, animate: true)
        } else {
            window.contentAspectRatio = NSSize(width: 716, height: 440)
            window.contentMinSize = NSSize(width: 370, height: 230)
            window.minSize = NSSize(width: 370, height: 230)
            let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y,
                             width: 716, height: 440)
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
