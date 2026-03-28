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

            ZStack {
                customBackground
                    .contextMenu { contextMenuItems }

                // Screen
                ScreenView(
                    image: norns.screenImage,
                    width: CustomLayout.baseScreenW * norns.customLayout.screen.scale,
                    height: CustomLayout.baseScreenH * norns.customLayout.screen.scale,
                    connectionHealth: norns.connectionHealth
                )
                .editablePosition(keyPath: \.screen, windowSize: geo.size, norns: norns)

                // K1
                ButtonView(size: CustomLayout.baseButtonK1 * norns.customLayout.k1.scale,
                          onPress: { norns.keyPress(1) },
                          onRelease: { norns.keyRelease(1) })
                .editablePosition(keyPath: \.k1, windowSize: geo.size, norns: norns)

                // E1
                EncoderView(size: CustomLayout.baseEncoder * norns.customLayout.e1.scale) { delta in
                    norns.encoderTurn(1, delta: delta)
                }
                .editablePosition(keyPath: \.e1, windowSize: geo.size, norns: norns)

                // E2
                EncoderView(size: CustomLayout.baseEncoder * norns.customLayout.e2.scale) { delta in
                    norns.encoderTurn(2, delta: delta)
                }
                .editablePosition(keyPath: \.e2, windowSize: geo.size, norns: norns)

                // E3
                EncoderView(size: CustomLayout.baseEncoder * norns.customLayout.e3.scale) { delta in
                    norns.encoderTurn(3, delta: delta)
                }
                .editablePosition(keyPath: \.e3, windowSize: geo.size, norns: norns)

                // K2
                ButtonView(size: CustomLayout.baseButton * norns.customLayout.k2.scale,
                          onPress: { norns.keyPress(2) },
                          onRelease: { norns.keyRelease(2) })
                .editablePosition(keyPath: \.k2, windowSize: geo.size, norns: norns)

                // K3
                ButtonView(size: CustomLayout.baseButton * norns.customLayout.k3.scale,
                          onPress: { norns.keyPress(3) },
                          onRelease: { norns.keyRelease(3) })
                .editablePosition(keyPath: \.k3, windowSize: geo.size, norns: norns)

                // Edit mode indicator
                if norns.isEditingLayout {
                    VStack {
                        HStack {
                            Text("EDIT MODE — drag to move, scroll to resize")
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
    private var customBackground: some View {
        switch norns.customBackground {
        case .original:
            Color(red: 0.70, green: 0.67, blue: 0.64)
        case .black:
            Color(red: 0.10, green: 0.10, blue: 0.10)
        case .gradient:
            AnimatedGradientView()
        case .glass:
            VisualEffectBackground()
        }
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
            Menu("Background") {
                Button(norns.customBackground == .black ? "Black ✓" : "Black") {
                    norns.customBackground = .black
                }
                Button(norns.customBackground == .original ? "Original ✓" : "Original") {
                    norns.customBackground = .original
                }
                Button(norns.customBackground == .gradient ? "Gradient ✓" : "Gradient") {
                    norns.customBackground = .gradient
                }
                Button(norns.customBackground == .glass ? "Glass ✓" : "Glass") {
                    norns.customBackground = .glass
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
            window.resizeIncrements = NSSize(width: 1, height: 1) // clears aspect ratio lock
            window.contentMinSize = NSSize(width: 300, height: 200)
            window.minSize = NSSize(width: 300, height: 200)
        }
    }
}

// MARK: - Editable Position Modifier

struct EditablePositionModifier: ViewModifier {
    let keyPath: WritableKeyPath<CustomLayout, ComponentLayout>
    let windowSize: CGSize
    let norns: NornsConnection

    @State private var dragOffset: CGSize = .zero

    func body(content: Content) -> some View {
        let layout = norns.customLayout[keyPath: keyPath]
        let x = layout.x * windowSize.width + dragOffset.width
        let y = layout.y * windowSize.height + dragOffset.height

        content
            .overlay(
                Group {
                    if norns.isEditingLayout {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)
                            .allowsHitTesting(false)
                    }
                }
            )
            .position(x: x, y: y)
            .gesture(norns.isEditingLayout ?
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        var comp = norns.customLayout[keyPath: keyPath]
                        comp.x += value.translation.width / windowSize.width
                        comp.y += value.translation.height / windowSize.height
                        comp.x = max(0.05, min(0.95, comp.x))
                        comp.y = max(0.05, min(0.95, comp.y))
                        norns.customLayout[keyPath: keyPath] = comp
                        norns.saveCustomLayout()
                        dragOffset = .zero
                    }
                : nil
            )
    }
}

extension View {
    func editablePosition(
        keyPath: WritableKeyPath<CustomLayout, ComponentLayout>,
        windowSize: CGSize,
        norns: NornsConnection
    ) -> some View {
        modifier(EditablePositionModifier(keyPath: keyPath, windowSize: windowSize, norns: norns))
    }
}

// MARK: - Animated Gradient Background (warm dark with film grain)

struct AnimatedGradientView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Black base
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                // Warm light source 1 — bottom left, drifting
                let x1 = w * (0.15 + 0.1 * sin(t * 0.15))
                let y1 = h * (0.95 + 0.05 * cos(t * 0.12))
                let r1 = max(w, h) * 0.7
                let hue1 = 0.98 + 0.02 * sin(t * 0.08) // warm red-pink
                context.fill(
                    Path(ellipseIn: CGRect(x: x1 - r1, y: y1 - r1, width: r1 * 2, height: r1 * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(hue: hue1, saturation: 0.55, brightness: 0.28, opacity: 0.7),
                            Color(hue: hue1, saturation: 0.4, brightness: 0.12, opacity: 0.3),
                            .clear
                        ]),
                        center: CGPoint(x: x1, y: y1),
                        startRadius: 0,
                        endRadius: r1
                    )
                )

                // Warm light source 2 — bottom right, drifting opposite
                let x2 = w * (0.85 + 0.1 * cos(t * 0.13))
                let y2 = h * (0.95 + 0.05 * sin(t * 0.1))
                let r2 = max(w, h) * 0.65
                let hue2 = 0.02 + 0.02 * cos(t * 0.09) // salmon/pink
                context.fill(
                    Path(ellipseIn: CGRect(x: x2 - r2, y: y2 - r2, width: r2 * 2, height: r2 * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(hue: hue2, saturation: 0.5, brightness: 0.25, opacity: 0.6),
                            Color(hue: hue2, saturation: 0.35, brightness: 0.10, opacity: 0.2),
                            .clear
                        ]),
                        center: CGPoint(x: x2, y: y2),
                        startRadius: 0,
                        endRadius: r2
                    )
                )

                // Film grain / dither overlay
                let seed = UInt64(t * 24) &* 6364136223846793005 &+ 1442695040888963407
                for _ in 0..<Int(w * h * 0.04) {
                    var s = seed &* UInt64.random(in: 1...UInt64.max)
                    s ^= s >> 12; s ^= s << 25; s ^= s >> 27
                    let gx = CGFloat(s % UInt64(w))
                    s = s &* 6364136223846793005 &+ 1442695040888963407
                    s ^= s >> 12; s ^= s << 25; s ^= s >> 27
                    let gy = CGFloat(s % UInt64(h))
                    let brightness = CGFloat(s % 100) / 100.0
                    let opacity = brightness * 0.06
                    context.fill(
                        Path(CGRect(x: gx, y: gy, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Glass Background (transparent, desktop shows through)

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
