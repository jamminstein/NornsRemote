import SwiftUI

struct NornsView: View {
    @Environment(NornsConnection.self) private var norns

    var body: some View {
        Group {
            switch norns.viewMode {
            case .full: fullView
            case .mini: miniView
            case .custom: customView
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

    private var fullView: some View {
        GeometryReader { geo in
            let bw: CGFloat = 700
            let bh: CGFloat = 452
            let scale = min(geo.size.width / (bw + 16), geo.size.height / (bh + 16))
            let w: CGFloat = bw * scale
            let h: CGFloat = bh * scale

            ZStack {
                Color(red: 0.70, green: 0.67, blue: 0.64)
                    .contextMenu { contextMenuItems }

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

                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: w, height: h)

                    ButtonView(size: 47 * scale,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                        .position(x: 102 * scale, y: 170 * scale)

                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                    .position(x: 202 * scale, y: 156 * scale)

                    ScreenView(
                        image: norns.screenImage,
                        width: 320 * scale,
                        height: 160 * scale,
                        connectionHealth: norns.connectionHealth
                    )
                    .position(x: 220 * scale, y: 318 * scale)

                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                    .position(x: 463 * scale, y: 262 * scale)

                    EncoderView(size: 65 * scale) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                    .position(x: 587 * scale, y: 262 * scale)

                    ButtonView(size: 43 * scale,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                        .position(x: 463 * scale, y: 363 * scale)

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

    // MARK: - Custom Mode

    private var customView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let editing = norns.isEditingLayout
            let layout = norns.customLayout

            ZStack {
                Color(red: 0.14, green: 0.14, blue: 0.14)
                    .contextMenu { contextMenuItems }

                // Screen
                customComponent(
                    layout: layout.screen,
                    keyPath: \.screen,
                    windowSize: geo.size
                ) {
                    ScreenView(
                        image: norns.screenImage,
                        width: CustomLayout.baseScreenW * layout.screen.scale,
                        height: CustomLayout.baseScreenH * layout.screen.scale,
                        connectionHealth: norns.connectionHealth
                    )
                }

                // K1
                customComponent(layout: layout.k1, keyPath: \.k1, windowSize: geo.size) {
                    ButtonView(size: CustomLayout.baseButtonK1 * layout.k1.scale,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                }

                // E1
                customComponent(layout: layout.e1, keyPath: \.e1, windowSize: geo.size) {
                    EncoderView(size: CustomLayout.baseEncoder * layout.e1.scale) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                }

                // E2
                customComponent(layout: layout.e2, keyPath: \.e2, windowSize: geo.size) {
                    EncoderView(size: CustomLayout.baseEncoder * layout.e2.scale) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                }

                // E3
                customComponent(layout: layout.e3, keyPath: \.e3, windowSize: geo.size) {
                    EncoderView(size: CustomLayout.baseEncoder * layout.e3.scale) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                }

                // K2
                customComponent(layout: layout.k2, keyPath: \.k2, windowSize: geo.size) {
                    ButtonView(size: CustomLayout.baseButton * layout.k2.scale,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                }

                // K3
                customComponent(layout: layout.k3, keyPath: \.k3, windowSize: geo.size) {
                    ButtonView(size: CustomLayout.baseButton * layout.k3.scale,
                              onPress: { norns.keyPress(3) },
                              onRelease: { norns.keyRelease(3) })
                }

                // Edit mode indicator
                if editing {
                    VStack {
                        HStack {
                            Text("EDIT MODE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func customComponent<Content: View>(
        layout: ComponentLayout,
        keyPath: WritableKeyPath<CustomLayout, ComponentLayout>,
        windowSize: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let editing = norns.isEditingLayout
        let posX = layout.x * windowSize.width
        let posY = layout.y * windowSize.height

        content()
            .position(x: posX, y: posY)
            .overlay(
                Group {
                    if editing {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                            .position(x: posX, y: posY)
                            .allowsHitTesting(false)
                    }
                }
            )
            .overlay(
                Group {
                    if editing {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 80, height: 80)
                            .position(x: posX, y: posY)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        var comp = norns.customLayout[keyPath: keyPath]
                                        comp.x = value.location.x / windowSize.width
                                        comp.y = value.location.y / windowSize.height
                                        norns.customLayout[keyPath: keyPath] = comp
                                    }
                                    .onEnded { _ in
                                        norns.saveCustomLayout()
                                    }
                            )
                            .onScrollWheel { delta in
                                var comp = norns.customLayout[keyPath: keyPath]
                                comp.scale = max(0.3, min(3.0, comp.scale + delta * 0.05))
                                norns.customLayout[keyPath: keyPath] = comp
                                norns.saveCustomLayout()
                            }
                    }
                }
            )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
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
                if !norns.isEditingLayout {
                    norns.saveCustomLayout()
                }
            }
            Button("Reset Layout") {
                norns.customLayout = CustomLayout()
                norns.saveCustomLayout()
            }
        }

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

    private func resizeWindow(mode: NornsConnection.ViewMode) {
        guard let window = NSApplication.shared.windows.first else { return }
        let origin = window.frame.origin
        switch mode {
        case .mini:
            window.contentAspectRatio = NSSize(width: 2, height: 1)
            window.contentMinSize = NSSize(width: 400, height: 200)
            window.minSize = NSSize(width: 400, height: 200)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: 400, height: 200),
                          display: true, animate: true)
        case .full:
            window.contentAspectRatio = NSSize(width: 716, height: 440)
            window.contentMinSize = NSSize(width: 370, height: 230)
            window.minSize = NSSize(width: 370, height: 230)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: 716, height: 440),
                          display: true, animate: true)
        case .custom:
            window.contentAspectRatio = NSSize(width: 0, height: 0)
            window.contentMinSize = NSSize(width: 300, height: 200)
            window.minSize = NSSize(width: 300, height: 200)
        }
    }
}
