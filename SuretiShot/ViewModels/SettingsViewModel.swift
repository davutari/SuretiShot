import Foundation
import Combine
import ServiceManagement
import AppKit

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
        hasScreenCapturePermission = await PermissionManager.shared.hasScreenCapturePermission()
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
