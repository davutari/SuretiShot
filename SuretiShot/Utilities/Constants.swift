import Foundation
import SwiftUI

enum Constants {

    enum App {
        static let name = "SuretiShot"
        static let version = "1.0.0"
        static let bundleIdentifier = "com.suretishot.app"
    }

    enum Defaults {
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let previewMaxSize = CGSize(width: 800, height: 600)
        static let galleryGridColumns = 4
        static let galleryGridSpacing: CGFloat = 12
    }

    enum CaptureQuality {
        static let scaleFactors: [Double] = [1.0, 1.5, 2.0, 3.0, 4.0]
        static let defaultScaleFactor: Double = 2.0
        static let dpiOptions: [Int] = [72, 144, 216, 288, 300]
        static let defaultDPI: Int = 144
    }

    enum UserDefaultsKeys {
        static let saveFolderBookmark = "SaveFolderBookmark"
        static let shortcutConfiguration = "ShortcutConfiguration"
        static let launchAtLogin = "LaunchAtLogin"
        static let showMenuBarIcon = "ShowMenuBarIcon"
        static let captureSound = "CaptureSound"
        static let gallerySortOrder = "GallerySortOrder"
        static let galleryFilter = "GalleryFilter"
        static let captureScaleFactor = "CaptureScaleFactor"
        static let captureDPI = "CaptureDPI"
    }

    enum Animation {
        static let defaultDuration: Double = 0.2
        static let springResponse: Double = 0.3
        static let springDamping: Double = 0.7
    }

    enum Layout {
        static let settingsWindowWidth: CGFloat = 500
        static let settingsWindowHeight: CGFloat = 400
        static let galleryWindowWidth: CGFloat = 900
        static let galleryWindowHeight: CGFloat = 600
        static let galleryMinWidth: CGFloat = 600
        static let galleryMinHeight: CGFloat = 400
    }
}

// MARK: - Privacy Notes

enum PrivacyNote {
    static let screenCapture = """
    SuretiShot requires screen recording permission to capture screenshots and recordings.

    Your captures are saved locally to your selected folder. No data is sent to any server.

    AI analysis is performed entirely on-device using Apple's Vision framework. No image data leaves your Mac.
    """

    static let folderAccess = """
    SuretiShot needs access to a folder to save your captures.

    A security-scoped bookmark is stored to remember your choice across app launches, even in sandboxed mode.
    """

    static let shortcuts = """
    Global keyboard shortcuts require Accessibility permission to work system-wide.

    You can customize shortcuts in Settings to avoid conflicts with other apps.
    """
}
