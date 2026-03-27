import SwiftUI

/// Tiny norns silhouette for the menu bar — body, screen, encoders, buttons.
struct NornsMenuBarIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Body
            let body = Path(roundedRect: CGRect(x: 1, y: 2, width: w - 2, height: h - 4),
                           cornerRadius: 2)
            context.fill(body, with: .color(.primary.opacity(0.85)))

            // Screen (left side)
            let screen = Path(CGRect(x: 3, y: 4, width: 8, height: 5))
            context.fill(screen, with: .color(.primary.opacity(0.3)))

            // E1 — top right
            let e1 = Path(ellipseIn: CGRect(x: 12.5, y: 3.5, width: 3, height: 3))
            context.stroke(e1, with: .color(.primary.opacity(0.3)), lineWidth: 0.8)

            // E2 — middle right
            let e2 = Path(ellipseIn: CGRect(x: 12, y: 8, width: 3, height: 3))
            context.stroke(e2, with: .color(.primary.opacity(0.3)), lineWidth: 0.8)

            // E3 — far right
            let e3 = Path(ellipseIn: CGRect(x: 15.5, y: 8, width: 3, height: 3))
            context.stroke(e3, with: .color(.primary.opacity(0.3)), lineWidth: 0.8)

            // K2 — dot below E2
            let k2 = Path(ellipseIn: CGRect(x: 12.5, y: 12, width: 1.5, height: 1.5))
            context.fill(k2, with: .color(.primary.opacity(0.3)))

            // K3 — dot below E3
            let k3 = Path(ellipseIn: CGRect(x: 16, y: 12, width: 1.5, height: 1.5))
            context.fill(k3, with: .color(.primary.opacity(0.3)))
        }
        .frame(width: 20, height: 16)
    }
}
