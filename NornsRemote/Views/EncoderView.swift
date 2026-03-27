import SwiftUI

/// A rotary encoder knob that can be dragged vertically to turn.
/// Norns encoders are endless — the indicator wraps around.
struct EncoderView: View {
    let size: CGFloat
    let onTurn: (Int) -> Void

    @State private var angle: Double = -135
    @State private var dragAccumulator: CGFloat = 0
    @State private var lastTickTime: Date = .distantPast

    private let sensitivity: CGFloat = 6
    private let degreesPerTick: Double = 15
    private let minTickInterval: TimeInterval = 0.03
    private let minAngle: Double = -135
    private let maxAngle: Double = 135

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.32),
                            Color(white: 0.25)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)

            // Knob body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.30),
                            Color(white: 0.20),
                            Color(white: 0.15)
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size - 4, height: size - 4)

            // Inner shadow
            Circle()
                .stroke(Color(white: 0.12), lineWidth: 1)
                .frame(width: size - 6, height: size - 6)

            // Knurling — subtle tick marks around the edge that rotate with the knob
            KnurlingView(size: size, tickCount: 32)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(dragGesture)
        .onScrollWheel { delta in
            let direction = delta > 0 ? 1 : -1
            angle += Double(direction) * degreesPerTick
            onTurn(direction)
        }
    }

    private var indicatorLine: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(white: 0.85))
                .frame(width: 2, height: size * 0.28)
            Spacer()
        }
        .frame(width: size, height: size)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let totalDelta = -value.translation.height
                let totalTicks = Int(totalDelta / sensitivity)
                let prevTicks = Int(dragAccumulator / sensitivity)
                let newTicks = totalTicks - prevTicks

                if newTicks != 0 {
                    let now = Date()
                    guard now.timeIntervalSince(lastTickTime) >= minTickInterval else { return }
                    lastTickTime = now

                    let direction = newTicks > 0 ? 1 : -1
                    dragAccumulator = CGFloat(totalTicks) * sensitivity
                    angle += Double(direction) * degreesPerTick
                    onTurn(direction)
                }
            }
            .onEnded { _ in
                dragAccumulator = 0
            }
    }
}

// MARK: - Knurling (subtle rotating tick marks)

struct KnurlingView: View {
    let size: CGFloat
    let tickCount: Int

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outerRadius = size / 2 - 3
            let innerRadius = outerRadius - size * 0.06

            for i in 0..<tickCount {
                let angleDeg = Double(i) * (360.0 / Double(tickCount))
                let angleRad = angleDeg * .pi / 180

                let outer = CGPoint(
                    x: center.x + outerRadius * CGFloat(cos(angleRad)),
                    y: center.y + outerRadius * CGFloat(sin(angleRad))
                )
                let inner = CGPoint(
                    x: center.x + innerRadius * CGFloat(cos(angleRad)),
                    y: center.y + innerRadius * CGFloat(sin(angleRad))
                )

                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Scroll Wheel Support

extension View {
    func onScrollWheel(_ handler: @escaping (CGFloat) -> Void) -> some View {
        self.background(ScrollWheelView(handler: handler))
    }
}

struct ScrollWheelView: NSViewRepresentable {
    let handler: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.handler = handler
    }
}

class ScrollWheelNSView: NSView {
    var handler: ((CGFloat) -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if abs(delta) > 0.1 {
            handler?(delta > 0 ? 1 : -1)
        }
    }
}
