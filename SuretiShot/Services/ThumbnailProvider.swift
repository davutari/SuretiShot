import Foundation
import QuickLookThumbnailing
import AppKit

actor ThumbnailProvider {

    private var cache = NSCache<NSURL, CGImageWrapper>()
    private var pendingRequests = Set<URL>()

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func thumbnail(for url: URL, size: CGSize) async -> CGImage? {
        // Check cache
        if let cached = cache.object(forKey: url as NSURL) {
            return cached.image
        }

        // Avoid duplicate requests
        guard !pendingRequests.contains(url) else {
            return nil
        }
        pendingRequests.insert(url)

        defer {
            pendingRequests.remove(url)
        }

        // Generate thumbnail
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)

            let cgImage = representation.cgImage
            cache.setObject(CGImageWrapper(image: cgImage), forKey: url as NSURL)
            return cgImage
        } catch {
            // Fallback for images: try loading directly
            if let image = NSImage(contentsOf: url),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                cache.setObject(CGImageWrapper(image: cgImage), forKey: url as NSURL)
                return cgImage
            }
        }

        return nil
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    func removeCachedThumbnail(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

// Wrapper class for caching CGImage
private final class CGImageWrapper {
    let image: CGImage

    init(image: CGImage) {
        self.image = image
    }
}
