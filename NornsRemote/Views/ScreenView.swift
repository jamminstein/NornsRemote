import SwiftUI

/// Pixel-perfect rendering of the Norns 128x64 OLED screen.
/// Uses nearest-neighbor interpolation so the bitmap font and graphics
/// look exactly as they do on the real hardware — no smoothing, no blur.
struct ScreenView: View {
    let image: CGImage?
    let width: CGFloat
    let height: CGFloat
    var connectionHealth: NornsConnection.ConnectionHealth = .disconnected

    var body: some View {
        ZStack {
            // Black OLED background
            RoundedRectangle(cornerRadius: 4)
                .fill(.black)

            if let image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else {
                offlineText
            }

            // Status dot — top right corner of screen
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color(nsColor: connectionHealth.color))
                        .frame(width: 4, height: 4)
                        .padding(5)
                }
                Spacer()
            }
        }
        .frame(width: width, height: height)
    }

    private var offlineText: some View {
        VStack {
            Spacer()
            HStack {
                Text("offline.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
                Spacer()
            }
        }
    }
}
