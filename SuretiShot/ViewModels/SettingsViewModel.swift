import Foundation
import Foundation
import Combine
import ServiceManagement
import AppKit
import ScreenCaptureKit

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedFolderURL: URL?
    @Published var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }
    @Published var hasScreenCapturePermission: Bool = false

    // Capture Quality
    @Published var captureScaleFactor: Double = Constants.CaptureQuality.defaultScaleFactor {
        didSet {
            UserDefaults.standard.set(captureScaleFactor, forKey: Constants.UserDefaultsKeys.captureScaleFactor)
        }
    }
    @Published var captureDPI: Int = Constants.CaptureQuality.defaultDPI {
        didSet {
            UserDefaults.standard.set(captureDPI, forKey: Constants.UserDefaultsKeys.captureDPI)
        }
    }

    // Shortcuts
    @Published var captureFullScreenShortcut: KeyboardShortcut?
    @Published var captureAreaShortcut: KeyboardShortcut?
    @Published var captureWindowShortcut: KeyboardShortcut?
    @Published var startRecordingShortcut: KeyboardShortcut?
    @Published var stopRecordingShortcut: KeyboardShortcut?

    // MARK: - Services

    private let folderAccessManager: FolderAccessManager
    private let shortcutManager: ShortcutManager

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var selectedFolderName: String {
        selectedFolderURL?.lastPathComponent ?? "No folder selected"
    }

    var selectedFolderPath: String {
        selectedFolderURL?.path ?? ""
    }

    // MARK: - Initialization

    init(folderAccessManager: FolderAccessManager, shortcutManager: ShortcutManager) {
        self.folderAccessManager = folderAccessManager
        self.shortcutManager = shortcutManager

        loadSettings()
        setupBindings()
    }

    // MARK: - Public Methods

    func selectFolder() async {
        if let url = await folderAccessManager.selectFolder() {
            selectedFolderURL = url
        }
    }

    func revealFolderInFinder() {
        guard let url = selectedFolderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func checkPermissions() async {
        // Force a fresh check instead of using cache
        let permission = await PermissionManager.shared.refreshPermissionStatus()
        await MainActor.run {
            hasScreenCapturePermission = permission
        }
    }
    
    func forceRefreshPermissions() async {
        // Multiple checks to ensure we get the real status
        await MainActor.run {
            // Method 1: Direct CGPreflightScreenCaptureAccess
            let directCheck = CGPreflightScreenCaptureAccess()
            print("🔍 Direct CGPreflightScreenCaptureAccess: \(directCheck)")
            NSLog("🔍 SuretiShot: Direct CGPreflightScreenCaptureAccess: \(directCheck)")
            
            // Method 2: Try to get shareable content (more reliable)
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    print("✅ SCShareableContent success - displays: \(content.displays.count)")
                    NSLog("✅ SuretiShot: SCShareableContent success - displays: \(content.displays.count)")
                    // If we can get content, we have permission
                    hasScreenCapturePermission = true
                } catch {
                    print("❌ SCShareableContent failed: \(error)")
                    NSLog("❌ SuretiShot: SCShareableContent failed: \(error)")
                    // If we can't get content, we don't have permission
                    hasScreenCapturePermission = false
                }
            }
            
            // For immediate UI update, use the direct check
            hasScreenCapturePermission = directCheck
            print("📱 UI Updated - hasScreenCapturePermission: \(directCheck)")
            NSLog("📱 SuretiShot: UI Updated - hasScreenCapturePermission: \(directCheck)")
        }
        
        // Also clear the PermissionManager cache
        let managerResult = await PermissionManager.shared.refreshPermissionStatus()
        print("🔄 PermissionManager refresh result: \(managerResult)")
        NSLog("🔄 SuretiShot: PermissionManager refresh result: \(managerResult)")
    }
    
    func requestScreenCapturePermission() async -> Bool {
        let granted = await PermissionManager.shared.requestScreenCapturePermission()
        await MainActor.run {
            hasScreenCapturePermission = granted
        }
        return granted
    }

    func openScreenRecordingSettings() {
        PermissionManager.shared.openScreenRecordingSettings()
    }

    func updateShortcut(_ shortcut: KeyboardShortcut?, for action: ShortcutAction) {
        shortcutManager.updateShortcut(shortcut, for: action)

        switch action {
        case .captureFullScreen:
            captureFullScreenShortcut = shortcut
        case .captureArea:
            captureAreaShortcut = shortcut
        case .captureWindow:
            captureWindowShortcut = shortcut
        case .startRecording:
            startRecordingShortcut = shortcut
        case .stopRecording:
            stopRecordingShortcut = shortcut
        }
    }

    func resetShortcutsToDefault() {
        shortcutManager.configuration = .defaultConfiguration
        loadShortcuts()
    }

    func isShortcutReserved(_ shortcut: KeyboardShortcut) -> Bool {
        shortcutManager.isShortcutReserved(shortcut)
    }

    func hasConflict(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction) -> ShortcutAction? {
        shortcutManager.hasConflict(shortcut, excluding: action)
    }

    // MARK: - Private Methods

    private func loadSettings() {
        // Load folder
        selectedFolderURL = folderAccessManager.getCurrentURL()

        // Load shortcuts
        loadShortcuts()

        // Load launch at login
        launchAtLogin = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.launchAtLogin)

        // Load capture quality settings
        let savedScaleFactor = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.captureScaleFactor)
        captureScaleFactor = savedScaleFactor > 0 ? savedScaleFactor : Constants.CaptureQuality.defaultScaleFactor

        let savedDPI = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.captureDPI)
        captureDPI = savedDPI > 0 ? savedDPI : Constants.CaptureQuality.defaultDPI

        // Check permissions
        Task {
            await checkPermissions()
        }
    }

    private func loadShortcuts() {
        captureFullScreenShortcut = shortcutManager.shortcut(for: .captureFullScreen)
        captureAreaShortcut = shortcutManager.shortcut(for: .captureArea)
        captureWindowShortcut = shortcutManager.shortcut(for: .captureWindow)
        startRecordingShortcut = shortcutManager.shortcut(for: .startRecording)
        stopRecordingShortcut = shortcutManager.shortcut(for: .stopRecording)
    }

    private func setupBindings() {
        folderAccessManager.$hasAccess
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAccess in
                if hasAccess {
                    self?.selectedFolderURL = self?.folderAccessManager.getCurrentURL()
                }
            }
            .store(in: &cancellables)
    }

    private func updateLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserDefaultsKeys.launchAtLogin)

        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
