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
    case screen // fallback

    var displayName: String {
        rawValue.capitalized
    }

    // Keywords that trigger each hint (deterministic matching)
    var keywords: [String] {
        switch self {
        case .login:
            return ["login", "sign in", "sign-in", "signin", "log in", "password", "username", "email address", "forgot password", "authentication", "authenticate", "credentials"]
        case .error:
            return ["error", "failed", "failure", "exception", "crash", "warning", "alert", "denied", "invalid", "not found", "404", "500", "403", "timeout", "cannot", "unable"]
        case .code:
            return ["func ", "function", "class ", "struct ", "enum ", "import ", "var ", "let ", "const ", "def ", "return", "if (", "if(", "for (", "for(", "while", "switch", "case:", "=>", "->", "#!/", "git ", "npm ", "yarn", "pod ", "swift", "python", "javascript", "typescript", "react", "vue"]
        case .invoice:
            return ["invoice", "receipt", "total", "subtotal", "tax", "amount due", "payment", "bill", "price", "cost", "$", "€", "£", "usd", "eur", "gbp", "order #", "order number", "transaction"]
        case .settings:
            return ["settings", "preferences", "configuration", "options", "general", "advanced", "privacy", "security", "notifications", "account", "profile", "permissions"]
        case .email:
            return ["inbox", "compose", "draft", "sent", "reply", "forward", "to:", "from:", "subject:", "cc:", "bcc:", "attachment", "unread", "spam", "trash"]
        case .chat:
            return ["message", "send", "typing", "online", "offline", "chat", "conversation", "direct message", "dm", "slack", "teams", "discord", "whatsapp", "telegram"]
        case .terminal:
            return ["terminal", "command", "shell", "bash", "zsh", "prompt", "sudo", "cd ", "ls ", "pwd", "mkdir", "rm ", "cp ", "mv ", "echo", "cat ", "grep"]
        case .browser:
            return ["safari", "chrome", "firefox", "edge", "brave", "http://", "https://", "www.", ".com", ".org", ".net", "bookmark", "history", "tab", "new tab"]
        case .document:
            return ["document", "word", "pages", "writing", "paragraph", "text", "edit", "format", "font", "heading", "title", "chapter"]
        case .spreadsheet:
            return ["spreadsheet", "excel", "numbers", "cell", "row", "column", "formula", "sum", "average", "chart", "graph", "pivot"]
        case .presentation:
            return ["presentation", "slide", "keynote", "powerpoint", "speaker notes", "transition", "animation", "slideshow"]
        case .calendar:
            return ["calendar", "event", "meeting", "appointment", "schedule", "reminder", "date", "time", "month", "week", "day", "agenda"]
        case .music:
            return ["music", "spotify", "apple music", "playlist", "song", "album", "artist", "play", "pause", "shuffle", "repeat", "volume"]
        case .video:
            return ["video", "youtube", "netflix", "movie", "watch", "stream", "player", "fullscreen", "subtitles", "captions"]
        case .photo:
            return ["photo", "image", "picture", "gallery", "album", "edit", "filter", "crop", "adjust", "photos app", "lightroom"]
        case .map:
            return ["map", "maps", "location", "directions", "navigate", "route", "gps", "latitude", "longitude", "search nearby"]
        case .social:
            return ["twitter", "facebook", "instagram", "linkedin", "tiktok", "post", "like", "share", "comment", "follow", "feed", "timeline"]
        case .shopping:
            return ["cart", "checkout", "add to cart", "buy now", "shop", "store", "product", "shipping", "delivery", "amazon", "ebay"]
        case .form:
            return ["form", "input", "submit", "required", "optional", "select", "dropdown", "checkbox", "radio", "field", "placeholder"]
        case .dashboard:
            return ["dashboard", "analytics", "metrics", "stats", "overview", "summary", "report", "kpi", "performance", "widget"]
        case .recording:
            return ["recording", "record", "rec", "capture", "screen recording"]
        case .screen:
            return [] // fallback, no keywords needed
        }
    }
}

struct TextAnalysisResult {
    let appName: String?
    let recognizedText: String
    let semanticHint: SemanticHint

    static var empty: TextAnalysisResult {
        TextAnalysisResult(appName: nil, recognizedText: "", semanticHint: .screen)
    }
}
