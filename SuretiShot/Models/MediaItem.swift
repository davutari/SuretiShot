import Foundation
import AppKit
import UniformTypeIdentifiers

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let filename: String
    let createdDate: Date
    let fileSize: Int64
    let mediaType: MediaItemType
    let dimensions: CGSize?

    // Parsed from filename
    let appName: String?
    let semanticHint: String?

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }

    var dimensionsString: String? {
        guard let dimensions = dimensions else { return nil }
        return "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.filename = url.lastPathComponent

        // Get file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.createdDate = (attributes?[.creationDate] as? Date) ?? Date()
        self.fileSize = (attributes?[.size] as? Int64) ?? 0

        // Determine media type
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "tiff", "gif"].contains(ext) {
            self.mediaType = .image
        } else if ["mov", "mp4", "m4v"].contains(ext) {
            self.mediaType = .video
        } else {
            self.mediaType = .unknown
        }

        // Get dimensions for images
        if self.mediaType == .image {
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                let width = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
                let height = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
                self.dimensions = CGSize(width: width, height: height)
            } else {
                self.dimensions = nil
            }
        } else {
            self.dimensions = nil
        }

        // Parse filename for metadata
        // Format: YYYY-MM-DD_HH-MM_AppName_SuretiHint.png
        let parsed = MediaItem.parseFilename(filename)
        self.appName = parsed.appName
        self.semanticHint = parsed.hint
    }

    private static func parseFilename(_ filename: String) -> (appName: String?, hint: String?) {
        let nameWithoutExtension = (filename as NSString).deletingPathExtension
        let components = nameWithoutExtension.split(separator: "_")

        guard components.count >= 4 else {
            return (nil, nil)
        }

        // Skip date (index 0) and time (index 1)
        // AppName is at index 2, hint at index 3
        let appName = components.count > 2 ? String(components[2]) : nil
        let hint = components.count > 3 ? String(components[3]) : nil

        return (appName, hint)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.url == rhs.url
    }
}

enum MediaItemType: String, CaseIterable, Identifiable {
    case image
    case video
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .image:
            return "Screenshot"
        case .video:
            return "Recording"
        case .unknown:
            return "Unknown"
        }
    }

    var systemImageName: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .unknown:
            return "doc"
        }
    }
}

enum GalleryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case screenshots = "Screenshots"
    case recordings = "Recordings"

    var id: String { rawValue }
}

enum GallerySortOrder: String, CaseIterable, Identifiable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case typeGrouped = "By Type"

    var id: String { rawValue }
}
