import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

final class PermissionManager {

    static let shared = PermissionManager()
    
    // Cache permission status to avoid repeated system calls
    private var cachedScreenCapturePermission: Bool?
    private var lastPermissionCheck: Date?
    private let cacheValidityDuration: TimeInterval = 1.0 // Reduced to 1 second for better responsiveness

    private init() {}

    // MARK: - Screen Capture Permission

    /// Check if screen capture permission is already granted (without prompting)
    func hasScreenCapturePermission() async -> Bool {
        // Check cache first
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
        
        // Try multiple methods to get accurate permission status
        let cgCheck = CGPreflightScreenCaptureAccess()
        
        // Also try ScreenCaptureKit check
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // If this succeeds, we definitely have permission
            cachedScreenCapturePermission = true
            lastPermissionCheck = Date()
            return true
        } catch {
            // If this fails, rely on CGPreflightScreenCaptureAccess
            cachedScreenCapturePermission = cgCheck
            lastPermissionCheck = Date()
            return cgCheck
        }
    }

    /// Request screen capture permission (will prompt if not granted)
    func requestScreenCapturePermission() async -> Bool {
        // First check if already granted
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        // CGRequestScreenCaptureAccess prompts the user ONLY ONCE per session
        // If already prompted and denied, don't prompt again automatically
        let hasBeenPrompted = UserDefaults.standard.bool(forKey: "ScreenCapturePermissionPrompted")
        
        if hasBeenPrompted {
            // If we've already prompted and still don't have permission,
            // direct user to System Preferences instead of prompting again
            return false
        }
        
        // Mark that we've prompted
        UserDefaults.standard.set(true, forKey: "ScreenCapturePermissionPrompted")
        
        // CGRequestScreenCaptureAccess prompts the user
        let granted = CGRequestScreenCaptureAccess()
        
        // If granted, reset the prompted flag for future sessions
        if granted {
            UserDefaults.standard.removeObject(forKey: "ScreenCapturePermissionPrompted")
        }
        
        return granted
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
