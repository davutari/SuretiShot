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
    
    private let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    // MARK: - Public Methods

    /// Generates a smart filename based on captured content and context
    /// Format: YYYY-MM-DD_HH-MM_AppName_SuretiHint.extension
    func generateFilename(
        appName: String?,
        hint: SemanticHint,
        type: FileMediaType,
        date: Date = Date(),
        entities: [String] = [],
        confidence: Double = 0.0
    ) -> String {
        let dateString = dateFormatter.string(from: date)
        let timeString = timeFormatter.string(from: date)

        // Enhanced app name processing
        let processedAppName = processAppName(appName, confidence: confidence)
        
        // Enhanced hint processing with confidence
        let processedHint = processHint(hint, entities: entities, confidence: confidence)

        // Build smart filename with optional entity context
        let components = buildFilenameComponents(
            date: dateString,
            time: timeString,
            appName: processedAppName,
            hint: processedHint,
            entities: entities
        )

        let baseName = components.joined(separator: "_")
        
        // Add sequence number if file exists
        return addSequenceIfNeeded(baseName: baseName, fileExtension: type.fileExtension)
    }
    
    /// Enhanced filename generation with smart context
    func generateSmartFilename(
        from analysisResult: TextAnalysisResult,
        type: FileMediaType,
        date: Date = Date()
    ) -> String {
        return generateFilename(
            appName: analysisResult.appName,
            hint: analysisResult.semanticHint,
            type: type,
            date: date,
            entities: analysisResult.entities,
            confidence: analysisResult.confidence
        )
    }

    /// Parses a filename to extract components with enhanced metadata
    func parseFilename(_ filename: String) -> ParsedFilename? {
        let nameWithoutExtension = (filename as NSString).deletingPathExtension
        let components = nameWithoutExtension.split(separator: "_")

        guard components.count >= 4 else {
            return nil
        }

        // Parse date and time
        let dateString = String(components[0])
        let timeString = String(components[1])
        
        let date = dateFormatter.date(from: dateString)
        let fullDateTime = fullDateTimeFormatter.date(from: "\(dateString)_\(timeString)-00")

        // Extract app name and hint
        let appName = String(components[2])
        let hint = String(components[3])

        // Extract entities if present
        let entities = components.count > 4 ? Array(components[4...]).map(String.init) : []

        return ParsedFilename(
            date: date,
            fullDateTime: fullDateTime,
            appName: appName,
            hint: hint,
            entities: entities,
            originalFilename: filename,
            fileExtension: (filename as NSString).pathExtension
        )
    }

    /// Suggests intelligent rename options
    func suggestRenames(for filename: String, analysisResult: TextAnalysisResult? = nil) -> [RenameOption] {
        guard let parsed = parseFilename(filename) else {
            return []
        }
        
        var options: [RenameOption] = []
        
        // Original with updated hint
        if let result = analysisResult {
            let smartName = generateSmartFilename(from: result, type: FileMediaType(fileExtension: parsed.fileExtension), date: parsed.fullDateTime ?? Date())
            options.append(RenameOption(
                type: .smart,
                filename: smartName,
                description: "AI-suggested name based on content",
                confidence: result.confidence
            ))
        }
        
        // Simplified version
        let simplifiedName = generateSimplifiedFilename(
            appName: parsed.appName,
            hint: parsed.hint,
            date: parsed.fullDateTime ?? Date(),
            fileExtension: parsed.fileExtension
        )
        options.append(RenameOption(
            type: .simplified,
            filename: simplifiedName,
            description: "Simplified naming convention",
            confidence: 0.8
        ))
        
        // Date-only version
        let dateOnlyName = generateDateOnlyFilename(
            date: parsed.fullDateTime ?? Date(),
            fileExtension: parsed.fileExtension
        )
        options.append(RenameOption(
            type: .dateOnly,
            filename: dateOnlyName,
            description: "Date-only naming",
            confidence: 1.0
        ))
        
        return options
    }

    // MARK: - Private Methods - Enhanced Processing

    private func processAppName(_ appName: String?, confidence: Double) -> String {
        guard let appName = appName else {
            return "UnknownApp"
        }
        
        // Special handling for common apps with aliases
        let normalizedName = normalizeAppName(appName)
        
        // If confidence is low, add qualifier
        if confidence < 0.5 {
            return "Detected-\(normalizedName)"
        }
        
        return sanitize(normalizedName) ?? "UnknownApp"
    }
    
    private func processHint(_ hint: SemanticHint, entities: [String], confidence: Double) -> String {
        // If we have high-confidence entities, incorporate them
        if confidence > 0.7 && !entities.isEmpty {
            let primaryEntity = entities.first!
            let shortEntity = String(primaryEntity.prefix(15))
            return "\(hint.rawValue.capitalized)-\(sanitize(shortEntity) ?? "Context")"
        }
        
        return hint.displayName
    }
    
    private func buildFilenameComponents(
        date: String,
        time: String,
        appName: String,
        hint: String,
        entities: [String]
    ) -> [String] {
        var components = [date, time, appName, hint]
        
        // Add primary entity if it adds meaningful context
        if !entities.isEmpty {
            let primaryEntity = entities.first!
            if primaryEntity.count >= 3 && primaryEntity.count <= 20 {
                let sanitizedEntity = sanitize(primaryEntity)
                if let entity = sanitizedEntity, !entity.isEmpty {
                    components.append(entity)
                }
            }
        }
        
        return components
    }
    
    private func normalizeAppName(_ appName: String) -> String {
        // Common app name normalizations
        let normalizations = [
            "Visual Studio Code": "VSCode",
            "VS Code": "VSCode",
            "Google Chrome": "Chrome",
            "Mozilla Firefox": "Firefox",
            "Microsoft Edge": "Edge",
            "Sublime Text": "Sublime",
            "Android Studio": "AndroidStudio",
            "IntelliJ IDEA": "IntelliJ",
            "System Preferences": "SystemPrefs",
            "System Settings": "SystemSettings",
            "Adobe Photoshop": "Photoshop",
            "Adobe Illustrator": "Illustrator"
        ]
        
        return normalizations[appName] ?? appName
    }
    
    private func addSequenceIfNeeded(baseName: String, fileExtension: String) -> String {
        let fullName = "\(baseName).\(fileExtension)"
        
        // Check if file exists (simplified - in real implementation would check actual file system)
        // For now, just return the name as-is
        return fullName
    }
    
    // MARK: - Simplified Naming Options
    
    private func generateSimplifiedFilename(
        appName: String,
        hint: String,
        date: Date,
        fileExtension: String
    ) -> String {
        let dateString = dateFormatter.string(from: date)
        let timeString = timeFormatter.string(from: date)
        
        return "\(dateString)_\(timeString)_\(appName).\(fileExtension)"
    }
    
    private func generateDateOnlyFilename(
        date: Date,
        fileExtension: String
    ) -> String {
        let fullDateTime = fullDateTimeFormatter.string(from: date)
        return "Screenshot_\(fullDateTime).\(fileExtension)"
    }

    private func sanitize(_ string: String?) -> String? {
        guard let string = string else { return nil }

        // Enhanced sanitization with Unicode support
        var sanitized = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "-")

        // Replace spaces with camelCase-like formatting
        sanitized = toCamelCase(sanitized)

        // Limit length while preserving readability
        if sanitized.count > 30 {
            sanitized = String(sanitized.prefix(30))
        }

        // Ensure it's not empty and doesn't start with invalid characters
        guard !sanitized.isEmpty,
              !sanitized.hasPrefix("."),
              !sanitized.hasPrefix("-") else {
            return nil
        }

        return sanitized
    }
    
    private func toCamelCase(_ string: String) -> String {
        let components = string.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !components.isEmpty else { return string }
        
        let first = components[0].lowercased()
        let rest = components.dropFirst().map { $0.capitalizingFirstLetter() }
        
        return ([first] + rest).joined()
    }
}

// MARK: - Supporting Types

struct ParsedFilename {
    let date: Date?
    let fullDateTime: Date?
    let appName: String
    let hint: String
    let entities: [String]
    let originalFilename: String
    let fileExtension: String
}

struct RenameOption {
    let type: RenameType
    let filename: String
    let description: String
    let confidence: Double
}

enum RenameType {
    case smart
    case simplified
    case dateOnly
    case custom
    
    var displayName: String {
        switch self {
        case .smart: return "Smart"
        case .simplified: return "Simple"
        case .dateOnly: return "Date Only"
        case .custom: return "Custom"
        }
    }
}

enum FileMediaType {
    case image
    case video
    case audio
    case document
    
    init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp":
            self = .image
        case "mov", "mp4", "avi", "mkv", "m4v", "webm":
            self = .video
        case "mp3", "aac", "wav", "m4a", "flac":
            self = .audio
        default:
            self = .document
        }
    }
    
    var fileExtension: String {
        switch self {
        case .image: return "png"
        case .video: return "mov"
        case .audio: return "m4a"
        case .document: return "pdf"
        }
    }
}

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
