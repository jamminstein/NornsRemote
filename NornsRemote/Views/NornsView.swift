import SwiftUI

struct NornsView: View {
    @Environment(NornsConnection.self) private var norns

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                switch norns.viewMode {
                case .full: fullView
                case .mini: miniView
                case .custom: customView
                }
            }
            .ignoresSafeArea()

            // Parameters sidebar
            if norns.showParams {
                ParamsSidebar()
                    .environment(norns)
                    .transition(.move(edge: .trailing))
            }

            // Recording indicator
            if norns.isRecording {
                VStack {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            norns.connect()
            norns.fetchScripts()
            norns.fetchInstalledProjects()
            if !norns.githubUsername.isEmpty { norns.fetchUserRepos() }
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
            @Bindable var norns = norns
            let size = geo.size
            let s = min(size.width / 700, size.height / 452)

            ZStack {
                customBackground
                    .contextMenu { contextMenuItems }

                if norns.isEditingLayout {
                    // EDIT MODE: static placeholders + draggable handles
                    // No real ButtonView/EncoderView — their NSViews steal mouse events

                    // Static placeholder circles for knobs/buttons
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButtonK1 * s, height: CustomLayout.baseButtonK1 * s)
                        .position(x: norns.customLayout.k1.x * size.width,
                                 y: norns.customLayout.k1.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s, height: CustomLayout.baseEncoder * s)
                        .position(x: norns.customLayout.e1.x * size.width,
                                 y: norns.customLayout.e1.y * size.height)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black)
                        .frame(width: CustomLayout.baseScreenW * s, height: CustomLayout.baseScreenH * s)
                        .position(x: norns.customLayout.screen.x * size.width,
                                 y: norns.customLayout.screen.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s, height: CustomLayout.baseEncoder * s)
                        .position(x: norns.customLayout.e2.x * size.width,
                                 y: norns.customLayout.e2.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s, height: CustomLayout.baseEncoder * s)
                        .position(x: norns.customLayout.e3.x * size.width,
                                 y: norns.customLayout.e3.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButton * s, height: CustomLayout.baseButton * s)
                        .position(x: norns.customLayout.k2.x * size.width,
                                 y: norns.customLayout.k2.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButton * s, height: CustomLayout.baseButton * s)
                        .position(x: norns.customLayout.k3.x * size.width,
                                 y: norns.customLayout.k3.y * size.height)

                    // Drag handles on top
                    DragHandle(layout: $norns.customLayout.k1, containerSize: size,
                              handleWidth: CustomLayout.baseButtonK1 * s,
                              handleHeight: CustomLayout.baseButtonK1 * s, label: "K1")
                    DragHandle(layout: $norns.customLayout.e1, containerSize: size,
                              handleWidth: CustomLayout.baseEncoder * s,
                              handleHeight: CustomLayout.baseEncoder * s, label: "E1")
                    DragHandle(layout: $norns.customLayout.screen, containerSize: size,
                              handleWidth: CustomLayout.baseScreenW * s,
                              handleHeight: CustomLayout.baseScreenH * s, label: "Screen")
                    DragHandle(layout: $norns.customLayout.e2, containerSize: size,
                              handleWidth: CustomLayout.baseEncoder * s,
                              handleHeight: CustomLayout.baseEncoder * s, label: "E2")
                    DragHandle(layout: $norns.customLayout.e3, containerSize: size,
                              handleWidth: CustomLayout.baseEncoder * s,
                              handleHeight: CustomLayout.baseEncoder * s, label: "E3")
                    DragHandle(layout: $norns.customLayout.k2, containerSize: size,
                              handleWidth: CustomLayout.baseButton * s,
                              handleHeight: CustomLayout.baseButton * s, label: "K2")
                    DragHandle(layout: $norns.customLayout.k3, containerSize: size,
                              handleWidth: CustomLayout.baseButton * s,
                              handleHeight: CustomLayout.baseButton * s, label: "K3")

                    Text("EDIT MODE — Drag to reposition")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .position(x: size.width / 2, y: 20)

                } else {
                    // PLAY MODE: real interactive components
                    ButtonView(size: CustomLayout.baseButtonK1 * s,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                        .position(x: norns.customLayout.k1.x * size.width,
                                 y: norns.customLayout.k1.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                    .position(x: norns.customLayout.e1.x * size.width,
                             y: norns.customLayout.e1.y * size.height)

                    ScreenView(
                        image: norns.screenImage,
                        width: CustomLayout.baseScreenW * s,
                        height: CustomLayout.baseScreenH * s,
                        connectionHealth: norns.connectionHealth
                    )
                    .position(x: norns.customLayout.screen.x * size.width,
                             y: norns.customLayout.screen.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                    .position(x: norns.customLayout.e2.x * size.width,
                             y: norns.customLayout.e2.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                    .position(x: norns.customLayout.e3.x * size.width,
                             y: norns.customLayout.e3.y * size.height)

                    ButtonView(size: CustomLayout.baseButton * s,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                        .position(x: norns.customLayout.k2.x * size.width,
                                 y: norns.customLayout.k2.y * size.height)

                    ButtonView(size: CustomLayout.baseButton * s,
                              onPress: { norns.keyPress(3) },
                              onRelease: { norns.keyRelease(3) })
                        .position(x: norns.customLayout.k3.x * size.width,
                                 y: norns.customLayout.k3.y * size.height)
                }
            }
            .frame(width: size.width, height: size.height)
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
        case .white:
            VisualEffectBackground()
        case .gradient:
            AnimatedGradientView()
        case .glass:
            Color.clear
                .contentShape(Rectangle())
        case .punk:
            PunkDitherBackground()
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
                Button(norns.customBackground == .punk ? "Punk ✓" : "Punk") {
                    norns.customBackground = .punk
                }
            }
            Button("Reset Layout") {
                norns.customLayout = CustomLayout()
                norns.saveCustomLayout()
            }
        }

        Divider()

        // Capture
        Button("Save Screenshot...") { norns.saveScreenshot() }
        Button("Copy Screenshot") { norns.copyScreenshot() }
        Button(norns.isRecording ? "Stop Recording & Save..." : "Record GIF") {
            norns.toggleRecording()
        }

        Divider()

        // Params
        Button(norns.showParams ? "Hide Parameters" : "Show Parameters") {
            norns.showParams.toggle()
            if norns.showParams { norns.fetchScriptParams() }
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

// MARK: - Parameters Sidebar

struct ParamsSidebar: View {
    @Environment(NornsConnection.self) private var norns

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PARAMS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button(action: { norns.fetchScriptParams() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                Button(action: { norns.showParams = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider().overlay(Color.white.opacity(0.1))

            if norns.scriptParams.isEmpty {
                Text("No params loaded.\nLoad a script first.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(10)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(norns.scriptParams) { param in
                            ParamRow(param: param) { delta in
                                norns.setParam(id: param.id, delta: delta)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 200)
        .background(Color.black.opacity(0.85))
    }
}

struct ParamRow: View {
    let param: NornsConnection.ScriptParam
    let onDelta: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(param.name)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                Text(param.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { onDelta(-1) }) {
                Image(systemName: "minus")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            Button(action: { onDelta(1) }) {
                Image(systemName: "plus")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.03))
        .cornerRadius(3)
    }
}

// MARK: - Drag Handle (edit mode overlay)

private struct DragHandle: View {
    @Binding var layout: ComponentLayout
    let containerSize: CGSize
    let handleWidth: CGFloat
    let handleHeight: CGFloat
    let label: String

    var body: some View {
        ZStack {
            // NSView-based drag handler — blocks window drag, handles mouse directly
            DragHandlerNSViewRep(
                onDrag: { dx, dy in
                    layout.x += dx / containerSize.width
                    layout.y += dy / containerSize.height
                    layout.x = max(0.05, min(0.95, layout.x))
                    layout.y = max(0.05, min(0.95, layout.y))
                }
            )
            // Visual overlay
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.cyan.opacity(0.12))
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                .allowsHitTesting(false)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .offset(y: -(handleHeight / 2 + 14))
                .allowsHitTesting(false)
        }
        .frame(width: handleWidth + 16, height: handleHeight + 16)
        .position(
            x: layout.x * containerSize.width,
            y: layout.y * containerSize.height
        )
    }
}

// MARK: - AppKit Drag Handler (bypasses window.isMovableByWindowBackground)

struct DragHandlerNSViewRep: NSViewRepresentable {
    let onDrag: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> DragHandlerNSView {
        let view = DragHandlerNSView()
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: DragHandlerNSView, context: Context) {
        nsView.onDrag = onDrag
    }
}

class DragHandlerNSView: NSView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    private var lastPoint: NSPoint?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        lastPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let last = lastPoint else { return }
        let current = event.locationInWindow
        let dx = current.x - last.x
        let dy = -(current.y - last.y) // flip Y: AppKit Y-up → SwiftUI Y-down
        onDrag?(dx, dy)
        lastPoint = current
    }

    override func mouseUp(with event: NSEvent) {
        lastPoint = nil
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

// MARK: - Punk Dither Background (1-bit glitch aesthetic)

struct PunkDitherBackground: View {
    private static let bayer: [CGFloat] = [
        0.0/16, 8.0/16, 2.0/16, 10.0/16,
        12.0/16, 4.0/16, 14.0/16, 6.0/16,
        3.0/16, 11.0/16, 1.0/16, 9.0/16,
        15.0/16, 7.0/16, 13.0/16, 5.0/16
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                Self.draw(ctx: &ctx, size: size, t: t)
            }
        }
    }

    private static func pixelValue(fx: CGFloat, fy: CGFloat, px: Int, py: Int, t: Double) -> Bool {
        var val: CGFloat = 0

        // Morphing blob 1
        let bx1: CGFloat = 0.5 + 0.4 * sin(t * 0.13 + 1.7)
        let by1: CGFloat = 0.5 + 0.3 * cos(t * 0.11 + 0.5)
        let dx1 = fx - bx1
        let dy1 = fy - by1
        let d1 = sqrt(dx1 * dx1 + dy1 * dy1)
        val += max(0, 0.5 - d1) * 1.6

        // Morphing blob 2
        let bx2: CGFloat = 0.5 + 0.35 * cos(t * 0.09 + 3.1)
        let by2: CGFloat = 0.5 + 0.4 * sin(t * 0.14 + 2.2)
        let dx2 = fx - bx2
        let dy2 = fy - by2
        let d2 = sqrt(dx2 * dx2 + dy2 * dy2)
        val += max(0, 0.4 - d2) * 1.4

        // Wave bands
        let waveArg: CGFloat = (fx * 8 + fy * 6 + CGFloat(t) * 0.3) * .pi
        val += sin(waveArg) * 0.3

        // Glitch bars
        let glitchSeed: Int = Int(t * 2) &* 2654435761
        if (px / 20 + glitchSeed) % 7 == 0 { val += 0.4 }

        // Scan lines
        let scan = sin(CGFloat(py) * 0.5 + CGFloat(t) * 4.0)
        if scan > 0.95 { val += 0.6 }

        // Bayer dither threshold
        let threshold = bayer[(py % 4) * 4 + (px % 4)]
        return val > threshold
    }

    private static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = Int(size.width)
        let h = Int(size.height)
        let step = 3

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

        let whiteColor = Color.white.opacity(0.85)
        for py in stride(from: 0, to: h, by: step) {
            let fy = CGFloat(py) / CGFloat(h)
            for px in stride(from: 0, to: w, by: step) {
                let fx = CGFloat(px) / CGFloat(w)
                if pixelValue(fx: fx, fy: fy, px: px, py: py, t: t) {
                    ctx.fill(
                        Path(CGRect(x: px, y: py, width: step, height: step)),
                        with: .color(whiteColor)
                    )
                }
            }
        }

        // Glitch tears
        let tearCount = (Int(t * 3) % 4) + 1
        for i in 0..<tearCount {
            let seed: UInt64 = UInt64(t * 7 + Double(i) * 13) &* 6364136223846793005
            let tearY = CGFloat(seed % UInt64(h))
            let tearH = CGFloat(2 + (seed >> 16) % 8)
            let offset = CGFloat(Int(seed >> 32) % 20) - 10
            ctx.fill(
                Path(CGRect(x: offset, y: tearY, width: size.width, height: tearH)),
                with: .color(.black)
            )
        }
    }
}
