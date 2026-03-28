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
                    // EDIT MODE: static placeholders + draggable/resizable handles
                    // No real ButtonView/EncoderView — their NSViews steal mouse events

                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButtonK1 * s * norns.customLayout.k1.scale,
                               height: CustomLayout.baseButtonK1 * s * norns.customLayout.k1.scale)
                        .position(x: norns.customLayout.k1.x * size.width,
                                 y: norns.customLayout.k1.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s * norns.customLayout.e1.scale,
                               height: CustomLayout.baseEncoder * s * norns.customLayout.e1.scale)
                        .position(x: norns.customLayout.e1.x * size.width,
                                 y: norns.customLayout.e1.y * size.height)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black)
                        .frame(width: CustomLayout.baseScreenW * s * norns.customLayout.screen.scale,
                               height: CustomLayout.baseScreenH * s * norns.customLayout.screen.scale)
                        .position(x: norns.customLayout.screen.x * size.width,
                                 y: norns.customLayout.screen.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s * norns.customLayout.e2.scale,
                               height: CustomLayout.baseEncoder * s * norns.customLayout.e2.scale)
                        .position(x: norns.customLayout.e2.x * size.width,
                                 y: norns.customLayout.e2.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseEncoder * s * norns.customLayout.e3.scale,
                               height: CustomLayout.baseEncoder * s * norns.customLayout.e3.scale)
                        .position(x: norns.customLayout.e3.x * size.width,
                                 y: norns.customLayout.e3.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButton * s * norns.customLayout.k2.scale,
                               height: CustomLayout.baseButton * s * norns.customLayout.k2.scale)
                        .position(x: norns.customLayout.k2.x * size.width,
                                 y: norns.customLayout.k2.y * size.height)
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: CustomLayout.baseButton * s * norns.customLayout.k3.scale,
                               height: CustomLayout.baseButton * s * norns.customLayout.k3.scale)
                        .position(x: norns.customLayout.k3.x * size.width,
                                 y: norns.customLayout.k3.y * size.height)

                    // Drag + scroll-to-resize handles
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

                    Text("EDIT MODE — Drag to move, scroll to resize")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .position(x: size.width / 2, y: 20)

                } else {
                    // PLAY MODE: real interactive components with custom scale
                    ButtonView(size: CustomLayout.baseButtonK1 * s * norns.customLayout.k1.scale,
                              onPress: { norns.keyPress(1) },
                              onRelease: { norns.keyRelease(1) })
                        .position(x: norns.customLayout.k1.x * size.width,
                                 y: norns.customLayout.k1.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s * norns.customLayout.e1.scale) { delta in
                        norns.encoderTurn(1, delta: delta)
                    }
                    .position(x: norns.customLayout.e1.x * size.width,
                             y: norns.customLayout.e1.y * size.height)

                    ScreenView(
                        image: norns.screenImage,
                        width: CustomLayout.baseScreenW * s * norns.customLayout.screen.scale,
                        height: CustomLayout.baseScreenH * s * norns.customLayout.screen.scale,
                        connectionHealth: norns.connectionHealth
                    )
                    .position(x: norns.customLayout.screen.x * size.width,
                             y: norns.customLayout.screen.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s * norns.customLayout.e2.scale) { delta in
                        norns.encoderTurn(2, delta: delta)
                    }
                    .position(x: norns.customLayout.e2.x * size.width,
                             y: norns.customLayout.e2.y * size.height)

                    EncoderView(size: CustomLayout.baseEncoder * s * norns.customLayout.e3.scale) { delta in
                        norns.encoderTurn(3, delta: delta)
                    }
                    .position(x: norns.customLayout.e3.x * size.width,
                             y: norns.customLayout.e3.y * size.height)

                    ButtonView(size: CustomLayout.baseButton * s * norns.customLayout.k2.scale,
                              onPress: { norns.keyPress(2) },
                              onRelease: { norns.keyRelease(2) })
                        .position(x: norns.customLayout.k2.x * size.width,
                                 y: norns.customLayout.k2.y * size.height)

                    ButtonView(size: CustomLayout.baseButton * s * norns.customLayout.k3.scale,
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
            GlassBackground()
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
    @State private var dragOffset: CGSize = .zero

    private var scaledW: CGFloat { handleWidth * layout.scale }
    private var scaledH: CGFloat { handleHeight * layout.scale }

    var body: some View {
        ZStack {
            // NSView-based drag handler — blocks window drag, handles mouse directly
            DragHandlerNSViewRep(
                onDragDelta: { dx, dy in
                    dragOffset.width += dx
                    dragOffset.height += dy
                },
                onDragEnd: {
                    layout.x += dragOffset.width / containerSize.width
                    layout.y += dragOffset.height / containerSize.height
                    layout.x = max(0.05, min(0.95, layout.x))
                    layout.y = max(0.05, min(0.95, layout.y))
                    dragOffset = .zero
                },
                onScroll: { delta in
                    layout.scale = max(0.3, min(3.0, layout.scale + delta))
                }
            )
            // Visual overlay (hit testing disabled — NSView handles it)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.cyan.opacity(0.12))
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                .allowsHitTesting(false)
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text(String(format: "%.0f%%", layout.scale * 100))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.6))
            }
            .allowsHitTesting(false)
        }
        .frame(width: scaledW + 16, height: scaledH + 16)
        .position(
            x: layout.x * containerSize.width + dragOffset.width,
            y: layout.y * containerSize.height + dragOffset.height
        )
    }
}

// MARK: - AppKit Drag Handler (bypasses window.isMovableByWindowBackground)

struct DragHandlerNSViewRep: NSViewRepresentable {
    let onDragDelta: (CGFloat, CGFloat) -> Void
    let onDragEnd: () -> Void
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> DragHandlerNSView {
        let view = DragHandlerNSView()
        view.coordinator = context.coordinator
        context.coordinator.onDragDelta = onDragDelta
        context.coordinator.onDragEnd = onDragEnd
        context.coordinator.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: DragHandlerNSView, context: Context) {
        context.coordinator.onDragDelta = onDragDelta
        context.coordinator.onDragEnd = onDragEnd
        context.coordinator.onScroll = onScroll
    }

    class Coordinator {
        var onDragDelta: ((CGFloat, CGFloat) -> Void)?
        var onDragEnd: (() -> Void)?
        var onScroll: ((CGFloat) -> Void)?
    }
}

class DragHandlerNSView: NSView {
    var coordinator: DragHandlerNSViewRep.Coordinator?
    private var trackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = event.deltaX
        let dy = event.deltaY
        coordinator?.onDragDelta?(dx, dy)
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.onDragEnd?()
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if abs(delta) > 0.1 {
            coordinator?.onScroll?(delta > 0 ? 0.05 : -0.05)
        }
        // Don't pass to super — consume the event
    }

    // Also support right-click drag as alternative resize
    override func rightMouseDragged(with event: NSEvent) {
        let delta = -event.deltaY * 0.01
        coordinator?.onScroll?(delta)
    }
}

// MARK: - Animated Gradient Background (international orange ↔ light gray, heavily dithered)

struct AnimatedGradientView: View {
    // Bayer 4x4 ordered dither matrix
    private static let bayer: [CGFloat] = [
        0.0/16, 8.0/16, 2.0/16, 10.0/16,
        12.0/16, 4.0/16, 14.0/16, 6.0/16,
        3.0/16, 11.0/16, 1.0/16, 9.0/16,
        15.0/16, 7.0/16, 13.0/16, 5.0/16
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                Self.draw(ctx: &ctx, size: size, t: t)
            }
        }
    }

    private static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = Int(size.width)
        let h = Int(size.height)
        let step = 3  // pixel block size for dithered look

        // Light gray base
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.78, green: 0.76, blue: 0.74)))

        // International orange: RGB ~(1.0, 0.31, 0.0) / hue ~0.05
        // Light gray: RGB ~(0.78, 0.76, 0.74)

        for py in stride(from: 0, to: h, by: step) {
            let fy = CGFloat(py) / CGFloat(h)
            for px in stride(from: 0, to: w, by: step) {
                let fx = CGFloat(px) / CGFloat(w)

                // Morphing orange blob 1 — large, drifting
                let bx1: CGFloat = 0.3 + 0.35 * sin(t * 0.1 + 1.2)
                let by1: CGFloat = 0.5 + 0.35 * cos(t * 0.08 + 0.7)
                let d1 = sqrt((fx - bx1) * (fx - bx1) + (fy - by1) * (fy - by1))
                var val: CGFloat = max(0, 0.55 - d1) * 1.8

                // Morphing blob 2 — smaller, faster
                let bx2: CGFloat = 0.7 + 0.3 * cos(t * 0.13 + 3.0)
                let by2: CGFloat = 0.4 + 0.3 * sin(t * 0.11 + 1.5)
                let d2 = sqrt((fx - bx2) * (fx - bx2) + (fy - by2) * (fy - by2))
                val += max(0, 0.4 - d2) * 1.5

                // Distortion waves
                let wave1 = sin((fx * 6.0 + fy * 4.0 + CGFloat(t) * 0.2) * .pi)
                val += wave1 * 0.15

                // Horizontal distortion bands
                let band = sin(fy * 20.0 + CGFloat(t) * 0.5)
                if band > 0.85 { val += 0.2 }

                // Noise distortion
                let noiseSeed = UInt64(Double(px * 31 + py * 97) + t * 3.0)
                let noise = CGFloat((noiseSeed &* 2654435761) % 256) / 256.0
                val += (noise - 0.5) * 0.15

                // Bayer ordered dither
                let threshold = bayer[(py % 4) * 4 + (px % 4)]
                let dithered = val > threshold

                if dithered {
                    // International orange with slight variation
                    let orangeShift = sin(CGFloat(t) * 0.15 + fx * 2.0) * 0.05
                    ctx.fill(
                        Path(CGRect(x: px, y: py, width: step, height: step)),
                        with: .color(Color(
                            red: min(1.0, 0.95 + orangeShift),
                            green: 0.31 + orangeShift * 0.5,
                            blue: 0.0
                        ))
                    )
                }
                // else: light gray base shows through
            }
        }

        // Glitch tears — horizontal displacement artifacts
        let tearCount = (Int(t * 2.5) % 3) + 1
        for i in 0..<tearCount {
            let seed: UInt64 = UInt64(t * 5.0 + Double(i) * 17.0) &* 6364136223846793005
            let tearY = CGFloat(seed % UInt64(h))
            let tearH = CGFloat(1 + (seed >> 16) % 4)
            let offset = CGFloat(Int(seed >> 32) % 12) - 6
            ctx.fill(
                Path(CGRect(x: offset, y: tearY, width: size.width, height: tearH)),
                with: .color(Color(red: 0.78, green: 0.76, blue: 0.74))
            )
        }

        // Heavy grain overlay
        let grainSeed = UInt64(t * 18) &* 6364136223846793005
        let grainCount = Int(size.width * size.height * 0.06)
        for i in 0..<grainCount {
            var s = grainSeed &+ UInt64(i) &* 2654435761
            s ^= s >> 12; s ^= s << 25; s ^= s >> 27
            let gx = CGFloat(s % UInt64(w))
            s = s &* 6364136223846793005 &+ 1442695040888963407
            s ^= s >> 12; s ^= s << 25; s ^= s >> 27
            let gy = CGFloat(s % UInt64(h))
            let isOrange = (s >> 40) % 3 == 0
            let opacity: CGFloat = CGFloat((s >> 48) % 80 + 20) / 1000.0
            ctx.fill(
                Path(CGRect(x: gx, y: gy, width: 2, height: 2)),
                with: .color(isOrange
                    ? Color(red: 1.0, green: 0.31, blue: 0.0, opacity: opacity * 3)
                    : Color.white.opacity(opacity))
            )
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

// MARK: - Glass Background (frosted desktop blur)

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI        // lighter frosted glass
        view.blendingMode = .behindWindow    // blurs whatever is behind the window
        view.state = .active                 // always active, even when unfocused
        view.isEmphasized = true
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
