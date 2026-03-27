import Foundation
import AppKit

/// Fetches the Norns screen PNG over HTTP from Maiden's dust API.
@Observable
final class ScreenFetcher {
    private let session: URLSession
    private var fetchURL: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func configure(host: String) {
        // Maiden serves dust files at /api/v1/dust/
        fetchURL = URL(string: "http://\(host)/api/v1/dust/data/screen.png")
        print("[Screen] fetch URL: \(fetchURL?.absoluteString ?? "nil")")
    }

    /// Fetch the current screen as a CGImage (128x64 grayscale).
    func fetchScreen() async -> CGImage? {
        guard let url = fetchURL else { return nil }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  !data.isEmpty else {
                return nil
            }

            // Decode PNG to CGImage
            guard let nsImage = NSImage(data: data),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }

            return cgImage
        } catch {
            return nil
        }
    }
}
