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

                // Components — matched to photo proportions
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: w, height: h)

                    // K1 — upper left, small
                    ButtonView(size: 38 * scale,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                        .position(x: 133 * scale, y: 175 * scale)

                    // E1 — right of K1, larger
                    EncoderView(size: 72 * scale) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                    .position(x: 215 * scale, y: 170 * scale)

                    // Screen — lower left, 2:1 ratio
                    ScreenView(
                        image: norns.screenImage,
                        width: 266 * scale,
                        height: 133 * scale,
                        connectionHealth: norns.connectionHealth
                    )
                    .position(x: 196 * scale, y: 305 * scale)

                    // E2 — right side, vertically centered
                    EncoderView(size: 72 * scale) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                    .position(x: 455 * scale, y: 215 * scale)

                    // E3 — right of E2
                    EncoderView(size: 72 * scale) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                    .position(x: 570 * scale, y: 215 * scale)

                    // K2 — below E2, shifted slightly left
                    ButtonView(size: 38 * scale,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                        .position(x: 440 * scale, y: 340 * scale)

                    // K3 — between E2 and E3, closer together than encoders
                    ButtonView(size: 38 * scale,
                              onPress: { norns.keyPress(3) },
                              onRelease: { norns.keyRelease(3) })
                        .position(x: 520 * scale, y: 340 * scale)
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
