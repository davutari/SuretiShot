import Foundation

enum SemanticHint: String, CaseIterable, Codable {
    case login
    case error
    case code
    case invoice
    case settings
    case email
    case chat
    case terminal
    case browser
    case document
    case spreadsheet
    case presentation
    case calendar
    case music
    case video
    case photo
    case map
    case social
    case shopping
    case form
    case dashboard
    case recording
    case game
    case design
    case finance
    case education
    case health
    case news
    case weather
    case screen // fallback

    var displayName: String {
        switch self {
        case .login: return "Login"
        case .error: return "Error"
        case .code: return "Code"
        case .invoice: return "Invoice"
        case .settings: return "Settings"
        case .email: return "Email"
        case .chat: return "Chat"
        case .terminal: return "Terminal"
        case .browser: return "Browser"
        case .document: return "Document"
        case .spreadsheet: return "Spreadsheet"
        case .presentation: return "Presentation"
        case .calendar: return "Calendar"
        case .music: return "Music"
        case .video: return "Video"
        case .photo: return "Photo"
        case .map: return "Map"
        case .social: return "Social"
        case .shopping: return "Shopping"
        case .form: return "Form"
        case .dashboard: return "Dashboard"
        case .recording: return "Recording"
        case .game: return "Game"
        case .design: return "Design"
        case .finance: return "Finance"
        case .education: return "Education"
        case .health: return "Health"
        case .news: return "News"
        case .weather: return "Weather"
        case .screen: return "Screen"
        }
    }

    var emoji: String {
        switch self {
        case .login: return "🔐"
        case .error: return "❌"
        case .code: return "💻"
        case .invoice: return "🧾"
        case .settings: return "⚙️"
        case .email: return "📧"
        case .chat: return "💬"
        case .terminal: return "🖥️"
        case .browser: return "🌐"
        case .document: return "📄"
        case .spreadsheet: return "📊"
        case .presentation: return "📽️"
        case .calendar: return "📅"
        case .music: return "🎵"
        case .video: return "🎬"
        case .photo: return "🖼️"
        case .map: return "🗺️"
        case .social: return "👥"
        case .shopping: return "🛒"
        case .form: return "📝"
        case .dashboard: return "📈"
        case .recording: return "⏺️"
        case .game: return "🎮"
        case .design: return "🎨"
        case .finance: return "💰"
        case .education: return "🎓"
        case .health: return "⚕️"
        case .news: return "📰"
        case .weather: return "🌤️"
        case .screen: return "🖥️"
        }
    }

    // Enhanced keywords with contextual patterns
    var keywords: [String] {
        switch self {
        case .login:
            return ["login", "sign in", "sign-in", "signin", "log in", "password", "username", "email address", "forgot password", "authentication", "authenticate", "credentials", "two-factor", "2fa", "biometric", "face id", "touch id"]
        case .error:
            return ["error", "failed", "failure", "exception", "crash", "warning", "alert", "denied", "invalid", "not found", "404", "500", "503", "403", "401", "timeout", "cannot", "unable", "oops", "something went wrong"]
        case .code:
            return ["func ", "function", "class ", "struct ", "enum ", "import ", "var ", "let ", "const ", "def ", "return", "if (", "if(", "for (", "for(", "while", "switch", "case:", "=>", "->", "#!/", "git ", "npm ", "yarn", "pod ", "swift", "python", "javascript", "typescript", "react", "vue", "angular", "node", "docker", "kubernetes", "api", "json", "xml", "sql", "database"]
        case .invoice:
            return ["invoice", "receipt", "total", "subtotal", "tax", "vat", "amount due", "payment", "bill", "price", "cost", "$", "€", "£", "¥", "usd", "eur", "gbp", "order #", "order number", "transaction", "payment method", "credit card", "debit", "paypal", "stripe"]
        case .settings:
            return ["settings", "preferences", "configuration", "options", "general", "advanced", "privacy", "security", "notifications", "account", "profile", "permissions", "customize", "configure", "setup"]
        case .email:
            return ["inbox", "compose", "draft", "sent", "reply", "forward", "to:", "from:", "subject:", "cc:", "bcc:", "attachment", "unread", "spam", "trash", "gmail", "outlook", "mail", "message", "@", ".com", ".org"]
        case .chat:
            return ["message", "send", "typing", "online", "offline", "chat", "conversation", "direct message", "dm", "slack", "teams", "discord", "whatsapp", "telegram", "signal", "messenger", "thread", "channel"]
        case .terminal:
            return ["terminal", "command", "shell", "bash", "zsh", "fish", "prompt", "sudo", "cd ", "ls ", "pwd", "mkdir", "rm ", "cp ", "mv ", "echo", "cat ", "grep", "curl", "wget", "ssh", "scp", "$", "~"]
        case .browser:
            return ["safari", "chrome", "firefox", "edge", "brave", "opera", "arc", "http://", "https://", "www.", ".com", ".org", ".net", "bookmark", "history", "tab", "new tab", "address bar", "url", "website"]
        case .document:
            return ["document", "word", "pages", "writing", "paragraph", "text", "edit", "format", "font", "heading", "title", "chapter", "essay", "report", "manuscript", "draft", "review"]
        case .spreadsheet:
            return ["spreadsheet", "excel", "numbers", "google sheets", "cell", "row", "column", "formula", "sum", "average", "chart", "graph", "pivot", "table", "data", "calculation"]
        case .presentation:
            return ["presentation", "slide", "keynote", "powerpoint", "google slides", "speaker notes", "transition", "animation", "slideshow", "deck", "pitch"]
        case .calendar:
            return ["calendar", "event", "meeting", "appointment", "schedule", "reminder", "date", "time", "month", "week", "day", "agenda", "google calendar", "outlook calendar"]
        case .music:
            return ["music", "spotify", "apple music", "youtube music", "playlist", "song", "album", "artist", "play", "pause", "shuffle", "repeat", "volume", "track", "audio"]
        case .video:
            return ["video", "youtube", "netflix", "hulu", "amazon prime", "disney+", "movie", "watch", "stream", "player", "fullscreen", "subtitles", "captions", "episode", "series"]
        case .photo:
            return ["photo", "image", "picture", "gallery", "album", "edit", "filter", "crop", "adjust", "photos app", "lightroom", "photoshop", "camera", "jpeg", "png"]
        case .map:
            return ["map", "maps", "google maps", "apple maps", "location", "directions", "navigate", "route", "gps", "latitude", "longitude", "search nearby", "address", "traffic"]
        case .social:
            return ["twitter", "facebook", "instagram", "linkedin", "tiktok", "snapchat", "reddit", "post", "like", "share", "comment", "follow", "feed", "timeline", "story", "reels"]
        case .shopping:
            return ["cart", "checkout", "add to cart", "buy now", "shop", "store", "product", "shipping", "delivery", "amazon", "ebay", "etsy", "shopify", "payment", "purchase"]
        case .form:
            return ["form", "input", "submit", "required", "optional", "select", "dropdown", "checkbox", "radio", "field", "placeholder", "validation", "survey", "questionnaire"]
        case .dashboard:
            return ["dashboard", "analytics", "metrics", "stats", "overview", "summary", "report", "kpi", "performance", "widget", "chart", "graph", "data visualization"]
        case .recording:
            return ["recording", "record", "rec", "capture", "screen recording", "audio recording", "voice memo", "video recording"]
        case .game:
            return ["game", "play", "player", "level", "score", "high score", "achievement", "leaderboard", "multiplayer", "single player", "steam", "epic games", "xbox", "playstation"]
        case .design:
            return ["design", "figma", "sketch", "adobe", "photoshop", "illustrator", "indesign", "canva", "prototype", "mockup", "wireframe", "ui", "ux", "graphic design"]
        case .finance:
            return ["finance", "bank", "banking", "investment", "portfolio", "stock", "crypto", "bitcoin", "wallet", "transaction", "budget", "expense", "income", "savings"]
        case .education:
            return ["education", "learning", "course", "lesson", "tutorial", "student", "teacher", "school", "university", "college", "homework", "assignment", "quiz", "test", "grade"]
        case .health:
            return ["health", "medical", "doctor", "appointment", "medication", "fitness", "workout", "exercise", "diet", "nutrition", "wellness", "symptom", "treatment"]
        case .news:
            return ["news", "article", "breaking news", "headline", "journalist", "reporter", "newspaper", "magazine", "press", "media", "current events", "politics"]
        case .weather:
            return ["weather", "forecast", "temperature", "rain", "snow", "sunny", "cloudy", "humidity", "wind", "storm", "climate", "meteorology", "°f", "°c"]
        case .screen:
            return [] // fallback, no keywords needed
        }
    }
}

struct TextAnalysisResult {
    let appName: String?
    let recognizedText: String
    let semanticHint: SemanticHint
    let language: String?
    let confidence: Double
    let entities: [String]
    let metadata: [String: Any]

    // Backward compatibility initializer
    init(appName: String?, recognizedText: String, semanticHint: SemanticHint) {
        self.appName = appName
        self.recognizedText = recognizedText
        self.semanticHint = semanticHint
        self.language = nil
        self.confidence = 0.0
        self.entities = []
        self.metadata = [:]
    }
    
    // Full initializer
    init(
        appName: String?,
        recognizedText: String,
        semanticHint: SemanticHint,
        language: String?,
        confidence: Double,
        entities: [String],
        metadata: [String: Any]
    ) {
        self.appName = appName
        self.recognizedText = recognizedText
        self.semanticHint = semanticHint
        self.language = language
        self.confidence = confidence
        self.entities = entities
        self.metadata = metadata
    }

    static var empty: TextAnalysisResult {
        TextAnalysisResult(
            appName: nil,
            recognizedText: "",
            semanticHint: .screen,
            language: nil,
            confidence: 0.0,
            entities: [],
            metadata: [:]
        )
    }
    
    // Computed properties for enhanced functionality
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...: return .high
        case 0.5..<0.8: return .medium
        case 0.2..<0.5: return .low
        default: return .veryLow
        }
    }
    
    var hasEntities: Bool {
        !entities.isEmpty
    }
    
    var wordCount: Int {
        recognizedText.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }.count
    }
}

enum ConfidenceLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case veryLow = "Very Low"
    
    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        case .veryLow: return "gray"
        }
    }
    
    var emoji: String {
        switch self {
        case .high: return "🟢"
        case .medium: return "🟡"
        case .low: return "🔴"
        case .veryLow: return "⚫"
        }
    }
}
