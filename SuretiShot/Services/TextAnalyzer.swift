import Foundation
import Vision
import AppKit

final class TextAnalyzer {

    // MARK: - Public Methods

    func analyze(imageData: Data) async -> TextAnalysisResult {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .empty
        }

        // Perform OCR
        let recognizedText = await performOCR(on: cgImage)

        // Detect app name from menu bar or window title
        let appName = detectAppName(from: recognizedText)

        // Determine semantic hint based on keywords
        let hint = determineSemanticHint(from: recognizedText)

        return TextAnalysisResult(
            appName: appName,
            recognizedText: recognizedText,
            semanticHint: hint
        )
    }

    // MARK: - Private Methods

    private func performOCR(on image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "tr-TR"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private func detectAppName(from text: String) -> String? {
        // Common app names to look for
        let knownApps = [
            "Safari", "Chrome", "Firefox", "Edge", "Brave",
            "Xcode", "Visual Studio Code", "VS Code", "Sublime Text", "Atom",
            "Terminal", "iTerm", "Warp",
            "Finder", "Preview", "Notes", "Reminders", "Calendar",
            "Mail", "Messages", "Slack", "Discord", "Teams", "Zoom",
            "Spotify", "Music", "Podcasts",
            "Photos", "Lightroom", "Photoshop", "Figma", "Sketch",
            "Numbers", "Pages", "Keynote", "Word", "Excel", "PowerPoint",
            "System Preferences", "System Settings",
        ]

        let lowercasedText = text.lowercased()

        // Check for known apps (case-insensitive)
        for app in knownApps {
            if lowercasedText.contains(app.lowercased()) {
                return app
            }
        }

        // Try to extract from common patterns
        // Pattern: "AppName - " or "AppName — " at the start
        let patterns = [
            "^([A-Za-z0-9 ]+) [-—–]",
            "\\| ([A-Za-z0-9]+)$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let appName = String(text[range]).trimmingCharacters(in: .whitespaces)
                if appName.count > 2 && appName.count < 30 {
                    return appName
                }
            }
        }

        return nil
    }

    private func determineSemanticHint(from text: String) -> SemanticHint {
        let lowercasedText = text.lowercased()

        // Score each hint based on keyword matches
        var scores: [SemanticHint: Int] = [:]

        for hint in SemanticHint.allCases where hint != .screen {
            let keywords = hint.keywords
            var score = 0

            for keyword in keywords {
                if lowercasedText.contains(keyword.lowercased()) {
                    // Weight longer keywords more heavily
                    score += keyword.count > 5 ? 2 : 1
                }
            }

            if score > 0 {
                scores[hint] = score
            }
        }

        // Return the highest scoring hint, or .screen as fallback
        if let bestMatch = scores.max(by: { $0.value < $1.value }),
           bestMatch.value >= 2 {
            return bestMatch.key
        }

        return .screen
    }
}
