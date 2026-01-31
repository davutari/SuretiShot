import Foundation

final class FileNamingEngine {

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH-mm"
        return formatter
    }()

    // MARK: - Public Methods

    /// Generates a deterministic filename based on captured content
    /// Format: YYYY-MM-DD_HH-MM_AppName_SuretiHint.extension
    func generateFilename(
        appName: String?,
        hint: SemanticHint,
        type: MediaType,
        date: Date = Date()
    ) -> String {
        let dateString = dateFormatter.string(from: date)
        let timeString = timeFormatter.string(from: date)

        // Sanitize app name
        let sanitizedAppName = sanitize(appName) ?? "Unknown"

        // Build filename
        let components = [
            dateString,
            timeString,
            sanitizedAppName,
            hint.rawValue.capitalized
        ]

        let baseName = components.joined(separator: "_")

        return "\(baseName).\(type.fileExtension)"
    }

    /// Parses a filename to extract components
    func parseFilename(_ filename: String) -> (date: Date?, appName: String?, hint: String?)? {
        let nameWithoutExtension = (filename as NSString).deletingPathExtension
        let components = nameWithoutExtension.split(separator: "_")

        guard components.count >= 4 else {
            return nil
        }

        // Parse date
        let dateString = String(components[0])
        let date = dateFormatter.date(from: dateString)

        // Extract app name and hint
        let appName = String(components[2])
        let hint = String(components[3])

        return (date, appName, hint)
    }

    /// Suggests a new filename while preserving the pattern
    func suggestRename(currentFilename: String, newHint: String? = nil, newAppName: String? = nil) -> String? {
        guard parseFilename(currentFilename) != nil else {
            return nil
        }

        let ext = (currentFilename as NSString).pathExtension
        let nameWithoutExtension = (currentFilename as NSString).deletingPathExtension
        let components = nameWithoutExtension.split(separator: "_")

        guard components.count >= 4 else {
            return nil
        }

        var newComponents = [String](components.map { String($0) })

        if let appName = newAppName {
            newComponents[2] = sanitize(appName) ?? "Unknown"
        }

        if let hint = newHint {
            newComponents[3] = sanitize(hint) ?? "Screen"
        }

        return newComponents.joined(separator: "_") + "." + ext
    }

    // MARK: - Private Methods

    private func sanitize(_ string: String?) -> String? {
        guard let string = string else { return nil }

        // Remove invalid filename characters
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = string
            .components(separatedBy: invalidCharacters)
            .joined()
            .trimmingCharacters(in: .whitespaces)

        // Replace spaces with nothing (camelCase-ish)
        sanitized = sanitized.replacingOccurrences(of: " ", with: "")

        // Limit length
        if sanitized.count > 30 {
            sanitized = String(sanitized.prefix(30))
        }

        // Ensure it's not empty
        guard !sanitized.isEmpty else {
            return nil
        }

        return sanitized
    }
}
