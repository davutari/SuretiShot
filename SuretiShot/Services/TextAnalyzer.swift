import Foundation
import Vision
import AppKit
import NaturalLanguage

@MainActor
final class TextAnalyzer {
    
    // MARK: - Properties
    
    private let nlProcessor = NLLanguageRecognizer()
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    // Enhanced app patterns with confidence scoring
    private let appPatterns = [
        // Web browsers
        (pattern: #"(?i)(safari|chrome|firefox|edge|brave|opera|arc)"#, confidence: 0.9, category: "browser"),
        // Development tools
        (pattern: #"(?i)(xcode|visual studio|vs code|sublime|atom|intellij|android studio|terminal|iterm|warp)"#, confidence: 0.95, category: "development"),
        // Creative apps
        (pattern: #"(?i)(photoshop|lightroom|figma|sketch|blender|final cut|premiere|after effects)"#, confidence: 0.9, category: "creative"),
        // Productivity apps
        (pattern: #"(?i)(word|excel|powerpoint|keynote|pages|numbers|notion|obsidian|craft)"#, confidence: 0.85, category: "productivity"),
        // Communication apps
        (pattern: #"(?i)(slack|discord|teams|zoom|skype|telegram|whatsapp|signal)"#, confidence: 0.9, category: "communication"),
        // System apps
        (pattern: #"(?i)(finder|system preferences|system settings|activity monitor|console)"#, confidence: 0.95, category: "system")
    ]

    // MARK: - Public Methods

    func analyze(imageData: Data) async -> TextAnalysisResult {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .empty
        }

        // Perform enhanced OCR with multiple passes
        let recognizedText = await performEnhancedOCR(on: cgImage)
        
        // Advanced language detection
        let detectedLanguage = detectLanguage(from: recognizedText)
        
        // Enhanced app detection with confidence scoring
        let (appName, confidence) = detectAppNameWithConfidence(from: recognizedText)
        
        // Context-aware semantic analysis
        let hint = await determineContextualSemanticHint(from: recognizedText, language: detectedLanguage)
        
        // Extract entities (names, places, organizations)
        let entities = extractEntities(from: recognizedText)
        
        return TextAnalysisResult(
            appName: appName,
            recognizedText: recognizedText,
            semanticHint: hint,
            language: detectedLanguage,
            confidence: confidence,
            entities: entities,
            metadata: generateMetadata(from: recognizedText, hint: hint)
        )
    }

    // MARK: - Enhanced OCR

    private func performEnhancedOCR(on image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            var allText: [String] = []
            let group = DispatchGroup()
            
            // Multiple recognition passes with different settings for better accuracy
            let configurations = [
                // High accuracy pass
                (level: VNRequestTextRecognitionLevel.accurate, correction: true, languages: ["en-US", "tr-TR"]),
                // Fast pass for UI elements
                (level: VNRequestTextRecognitionLevel.fast, correction: false, languages: ["en-US"])
            ]
            
            for config in configurations {
                group.enter()
                
                let request = VNRecognizeTextRequest { request, error in
                    defer { group.leave() }
                    
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        return
                    }

                    let text = observations
                        .compactMap { observation in
                            // Get multiple candidates for better accuracy
                            observation.topCandidates(3)
                                .first(where: { $0.confidence > 0.5 })?
                                .string
                        }
                        .joined(separator: " ")
                    
                    if !text.isEmpty {
                        allText.append(text)
                    }
                }

                request.recognitionLevel = config.level
                request.usesLanguageCorrection = config.correction
                request.recognitionLanguages = config.languages
                
                // Enhanced for better symbol recognition
                request.customWords = ["macOS", "iOS", "iPadOS", "watchOS", "visionOS", "Xcode", "SwiftUI", "UIKit", "AppKit"]

                let handler = VNImageRequestHandler(cgImage: image, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    // Continue with other passes if one fails
                }
            }
            
            group.notify(queue: .main) {
                // Combine results and remove duplicates
                let combinedText = Array(Set(allText)).joined(separator: " ")
                continuation.resume(returning: combinedText)
            }
        }
    }

    // MARK: - Language Detection
    
    private func detectLanguage(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        nlProcessor.processString(text)
        guard let language = nlProcessor.dominantLanguage else {
            return nil
        }
        
        return language.rawValue
    }

    // MARK: - Enhanced App Detection

    private func detectAppNameWithConfidence(from text: String) -> (String?, Double) {
        let lowercasedText = text.lowercased()
        var bestMatch: (name: String, confidence: Double, category: String)?
        
        // Check patterns with confidence scoring
        for pattern in appPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern.pattern)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                if let match = matches.first,
                   let range = Range(match.range, in: text) {
                    let appName = String(text[range])
                        .trimmingCharacters(in: .whitespaces)
                        .capitalizingFirstLetter()
                    
                    if bestMatch == nil || pattern.confidence > bestMatch!.confidence {
                        bestMatch = (appName, pattern.confidence, pattern.category)
                    }
                }
            } catch {
                continue
            }
        }
        
        if let match = bestMatch {
            return (match.name, match.confidence)
        }
        
        // Fallback to original detection with lower confidence
        if let fallbackApp = detectAppNameFallback(from: text) {
            return (fallbackApp, 0.6)
        }
        
        return (nil, 0.0)
    }
    
    private func detectAppNameFallback(from text: String) -> String? {
        // Common title bar patterns
        let patterns = [
            #"^([A-Za-z0-9 ]+) [-—–]"#,  // "AppName - Document"
            #"\\| ([A-Za-z0-9 ]+)$"#,      // "Document | AppName"
            #"^([A-Za-z]{3,20})$"#          // Single word apps
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let appName = String(text[range]).trimmingCharacters(in: .whitespaces)
                if appName.count >= 3 && appName.count <= 30 {
                    return appName.capitalizingFirstLetter()
                }
            }
        }
        
        return nil
    }

    // MARK: - Contextual Semantic Analysis

    private func determineContextualSemanticHint(from text: String, language: String?) async -> SemanticHint {
        let lowercasedText = text.lowercased()
        
        // Advanced scoring with context awareness
        var scores: [SemanticHint: Double] = [:]
        
        for hint in SemanticHint.allCases where hint != .screen {
            let baseScore = calculateKeywordScore(text: lowercasedText, keywords: hint.keywords)
            let contextScore = await calculateContextScore(text: lowercasedText, hint: hint)
            let languageBonus = calculateLanguageBonus(language: language, hint: hint)
            
            let totalScore = baseScore + contextScore + languageBonus
            
            if totalScore > 0 {
                scores[hint] = totalScore
            }
        }
        
        // Use weighted scoring for better accuracy
        if let bestMatch = scores.max(by: { $0.value < $1.value }),
           bestMatch.value >= 1.5 {
            return bestMatch.key
        }
        
        return .screen
    }
    
    private func calculateKeywordScore(text: String, keywords: [String]) -> Double {
        var score: Double = 0
        let words = Set(text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).map { $0.lowercased() })
        
        for keyword in keywords {
            let keywordLower = keyword.lowercased()
            
            // Exact word match (highest score)
            if words.contains(keywordLower) {
                score += keyword.count > 5 ? 3.0 : 2.0
            }
            // Substring match (lower score)
            else if text.contains(keywordLower) {
                score += keyword.count > 5 ? 1.5 : 1.0
            }
        }
        
        return score
    }
    
    private func calculateContextScore(text: String, hint: SemanticHint) async -> Double {
        // Use NLTagger for part-of-speech and named entity recognition
        tagger.string = text
        
        var contextScore: Double = 0
        
        // Look for specific patterns that indicate context
        switch hint {
        case .code:
            // Look for code-like structures
            let codePatterns = [#"\{[^}]*\}"#, #"\([^)]*\)"#, #"[a-zA-Z_][a-zA-Z0-9_]*\s*="#, #"\w+\.\w+"#]
            contextScore += countPatternMatches(text: text, patterns: codePatterns) * 0.5
            
        case .email:
            // Email-specific patterns
            let emailPatterns = [#"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#]
            contextScore += countPatternMatches(text: text, patterns: emailPatterns) * 2.0
            
        case .invoice:
            // Currency and number patterns
            let invoicePatterns = [#"\$\d+\.?\d*"#, #"€\d+\.?\d*"#, #"£\d+\.?\d*"#, #"#\d+"#]
            contextScore += countPatternMatches(text: text, patterns: invoicePatterns) * 1.5
            
        default:
            break
        }
        
        return contextScore
    }
    
    private func calculateLanguageBonus(language: String?, hint: SemanticHint) -> Double {
        guard let language = language else { return 0 }
        
        // Some hints might be more relevant for certain languages
        switch hint {
        case .terminal where language.hasPrefix("en"):
            return 0.5  // English terminal commands are common
        case .code:
            return 0.3  // Code is often in English regardless of system language
        default:
            return 0
        }
    }
    
    private func countPatternMatches(text: String, patterns: [String]) -> Double {
        var totalMatches: Double = 0
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
                totalMatches += Double(matches)
            } catch {
                continue
            }
        }
        
        return totalMatches
    }

    // MARK: - Entity Extraction

    private func extractEntities(from text: String) -> [String] {
        tagger.string = text
        var entities: [String] = []
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, tokenRange in
            if let tag = tag,
               (tag == .personalName || tag == .placeName || tag == .organizationName) {
                let entity = String(text[tokenRange])
                if entity.count > 2 && entity.count < 50 {
                    entities.append(entity)
                }
            }
            return true
        }
        
        return Array(Set(entities)) // Remove duplicates
    }

    // MARK: - Metadata Generation

    private func generateMetadata(from text: String, hint: SemanticHint) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        metadata["textLength"] = text.count
        metadata["wordCount"] = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }.count
        metadata["hasNumbers"] = text.rangeOfCharacter(from: .decimalDigits) != nil
        metadata["hasSpecialChars"] = text.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        metadata["hint"] = hint.rawValue
        metadata["analysisTimestamp"] = Date()
        
        return metadata
    }
}

// MARK: - Extensions

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
