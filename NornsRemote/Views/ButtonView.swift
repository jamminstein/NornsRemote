import SwiftUI
import AppKit

/// A clickable button matching the small round keys on the Norns.
/// Long-press (hold mouse ~0.4s) to lock held, quick click to release.
struct ButtonView: View {
    let size: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isDown = false
    @State private var isHeld = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Shadow well
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: size, height: size)

                // Outer ring
                Circle()
                    .fill(Color(white: (isDown || isHeld) ? 0.20 : 0.28))
                    .frame(width: size - ((isDown || isHeld) ? 2 : 0),
                           height: size - ((isDown || isHeld) ? 2 : 0))

                // Button body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: (isDown || isHeld) ? 0.16 : 0.26),
                                Color(white: (isDown || isHeld) ? 0.10 : 0.18)
                            ],
                            center: UnitPoint(x: 0.4, y: (isDown || isHeld) ? 0.5 : 0.35),
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                    .frame(width: size - 4, height: size - 4)
                    .scaleEffect((isDown || isHeld) ? 0.92 : 1.0)
                    .offset(y: (isDown || isHeld) ? 1 : 0)

                // Highlight rim
                if !isDown && !isHeld {
                    Circle()
                        .trim(from: 0.35, to: 0.65)
                        .stroke(Color(white: 0.38), lineWidth: 0.5)
                        .frame(width: size - 5, height: size - 5)
                }

                // Inner shadow
                Circle()
                    .stroke(Color(white: (isDown || isHeld) ? 0.06 : 0.10), lineWidth: 0.5)
                    .frame(width: size - 5, height: size - 5)
            }
            .frame(width: size, height: size)
            .overlay(
                RawButtonHandler(
                    onMouseDown: {
                        if isHeld {
                            // Quick click while held — release
                            isHeld = false
                            isDown = false
                            onRelease()
                        } else {
                            isDown = true
                            onPress()
                        }
                    },
                    onMouseUp: { duration in
                        if isHeld { return } // already handled in onMouseDown
                        if duration >= 0.4 {
                            // Long press — lock held
                            isDown = false
                            isHeld = true
                        } else {
                            // Quick click — release
                            isDown = false
                            onRelease()
                        }
                    }
                )
            )

            // Hold indicator dot
            Circle()
                .fill(Color.white.opacity(isHeld ? 0.6 : 0))
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .animation(.easeInOut(duration: 0.06), value: isDown)
        .animation(.easeInOut(duration: 0.06), value: isHeld)
    }
}

// MARK: - Raw NSView for precise mouse timing

struct RawButtonHandler: NSViewRepresentable {
    let onMouseDown: () -> Void
    let onMouseUp: (TimeInterval) -> Void

    func makeNSView(context: Context) -> RawButtonNSView {
        let view = RawButtonNSView()
        view.onMouseDown = onMouseDown
        view.onMouseUp = onMouseUp
        return view
    }

    func updateNSView(_ nsView: RawButtonNSView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onMouseUp = onMouseUp
    }
}

class RawButtonNSView: NSView {
    var onMouseDown: (() -> Void)?
    var onMouseUp: ((TimeInterval) -> Void)?
    private var pressTime: Date?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        pressTime = Date()
        onMouseDown?()
    }

    override func mouseUp(with event: NSEvent) {
        let duration = pressTime.map { Date().timeIntervalSince($0) } ?? 0
        pressTime = nil
        onMouseUp?(duration)
    }
}
