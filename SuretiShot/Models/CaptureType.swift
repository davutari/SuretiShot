import Foundation

enum CaptureType: String, CaseIterable, Identifiable, Codable {
    case fullScreen = "Full Screen"
    case selectedArea = "Selected Area"
    case activeWindow = "Active Window"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .fullScreen:
            return "rectangle.dashed"
        case .selectedArea:
            return "crop"
        case .activeWindow:
            return "macwindow"
        }
    }
}

enum MediaType: String, CaseIterable, Identifiable, Codable {
    case screenshot
    case recording

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .screenshot:
            return "png"
        case .recording:
            return "mov"
        }
    }
}

enum CaptureError: Error, LocalizedError {
    case noPermission
    case captureFailed
    case saveFailed
    case cancelled
    case noDisplay
    case noWindow

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "Screen capture permission not granted"
        case .captureFailed:
            return "Failed to capture screen"
        case .saveFailed:
            return "Failed to save capture"
        case .cancelled:
            return "Capture was cancelled"
        case .noDisplay:
            return "No display available"
        case .noWindow:
            return "No active window found"
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case noPermission
    case alreadyRecording
    case notRecording
    case setupFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "Screen recording permission not granted"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording in progress"
        case .setupFailed:
            return "Failed to setup recording"
        case .writeFailed:
            return "Failed to write recording"
        }
    }
}
