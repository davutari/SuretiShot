import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

final class PermissionManager {

    static let shared = PermissionManager()

    // Cache permission status to avoid repeated system calls
    private var cachedScreenCapturePermission: Bool?
    private var lastPermissionCheck: Date?
    private let cacheValidityDuration: TimeInterval = 60.0 // Cache for 60 seconds

    // Track if we've already prompted this session
    private var hasPromptedThisSession = false

    private init() {}

    // MARK: - Screen Capture Permission

    /// Check if screen capture permission is already granted (without prompting)
    func hasScreenCapturePermission() async -> Bool {
        // Check cache first - use longer cache to avoid repeated checks
        if let cached = cachedScreenCapturePermission,
           let lastCheck = lastPermissionCheck,
           Date().timeIntervalSince(lastCheck) < cacheValidityDuration {
            return cached
        }

        // CGPreflightScreenCaptureAccess checks without prompting
        let hasPermission = CGPreflightScreenCaptureAccess()

        // Update cache
        cachedScreenCapturePermission = hasPermission
        lastPermissionCheck = Date()

        return hasPermission
    }

    /// Force refresh the permission status
    func refreshPermissionStatus() async -> Bool {
        cachedScreenCapturePermission = nil
        lastPermissionCheck = nil

        // Only use CGPreflightScreenCaptureAccess - don't trigger SCShareableContent
        // as it can cause permission dialogs
        let cgCheck = CGPreflightScreenCaptureAccess()

        cachedScreenCapturePermission = cgCheck
        lastPermissionCheck = Date()
        return cgCheck
    }

    /// Request screen capture permission (will prompt if not granted)
    /// This should only be called once per app session
    func requestScreenCapturePermission() async -> Bool {
        // First check if already granted
        if CGPreflightScreenCaptureAccess() {
            cachedScreenCapturePermission = true
            lastPermissionCheck = Date()
            return true
        }

        // Don't prompt more than once per session
        if hasPromptedThisSession {
            return false
        }

        // Check if we've prompted before and user denied
        let hasBeenPromptedBefore = UserDefaults.standard.bool(forKey: "ScreenCapturePermissionPrompted")

        if hasBeenPromptedBefore {
            // Don't prompt again - user needs to grant manually in System Settings
            return false
        }

        // Mark that we're prompting
        hasPromptedThisSession = true
        UserDefaults.standard.set(true, forKey: "ScreenCapturePermissionPrompted")

        // CGRequestScreenCaptureAccess prompts the user
        let granted = CGRequestScreenCaptureAccess()

        // Update cache
        cachedScreenCapturePermission = granted
        lastPermissionCheck = Date()

        return granted
    }

    /// Reset permission prompt flag (call when user manually grants permission)
    func resetPromptFlag() {
        hasPromptedThisSession = false
        UserDefaults.standard.removeObject(forKey: "ScreenCapturePermissionPrompted")
        cachedScreenCapturePermission = nil
        lastPermissionCheck = nil
    }

    // MARK: - Microphone Permission (for future audio recording)

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // MARK: - Open System Settings

    @MainActor
    func openScreenRecordingSettings() {
        // Try newer macOS Ventura+ URL first
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
        
        // Fallback to older URL format
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.Extensions") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
