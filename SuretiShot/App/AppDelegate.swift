import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services
    let folderAccessManager = FolderAccessManager()
    let captureService = CaptureService()
    let screenRecordingService = ScreenRecordingService()
    let shortcutManager = ShortcutManager()
    let textAnalyzer = TextAnalyzer()
    let fileNamingEngine = FileNamingEngine()
    lazy var galleryService = GalleryService(folderAccessManager: folderAccessManager)

    // MARK: - ViewModels (initialized synchronously)
    lazy var settingsViewModel = SettingsViewModel(
        folderAccessManager: folderAccessManager,
        shortcutManager: shortcutManager
    )
    lazy var galleryViewModel = GalleryViewModel(
        galleryService: galleryService,
        folderAccessManager: folderAccessManager
    )

    // MARK: - UI
    private var menuBarController: MenuBarController?
    private var galleryWindowController: GalleryWindowController?

    private var cancellables = Set<AnyCancellable>()

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await setupApplication()
        }
    }

    private func setupApplication() async {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        menuBarController = MenuBarController(
            settingsViewModel: settingsViewModel,
            galleryViewModel: galleryViewModel,
            onCapture: { [weak self] type in
                Task { @MainActor in
                    await self?.performCapture(type: type)
                }
            },
            onToggleRecording: { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            },
            onOpenGallery: { [weak self] in
                self?.openGallery()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        // Setup bindings
        setupBindings()

        // Don't automatically request permission on startup - let user trigger it
        // This prevents the aggressive permission dialog

        // Restore folder access
        if let url = folderAccessManager.restoreAccess() {
            galleryService.startMonitoring(folder: url)
            await galleryViewModel.loadItems()
        }

        // Setup shortcuts
        setupShortcuts()
        
        // Listen for app becoming active (user might have changed permissions)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.settingsViewModel.forceRefreshPermissions()
            }
        }
    }

    private func setupBindings() {
        // Observe folder changes
        settingsViewModel.$selectedFolderURL
            .compactMap { $0 }
            .sink { [weak self] url in
                self?.galleryService.startMonitoring(folder: url)
                Task { @MainActor [weak self] in
                    await self?.galleryViewModel.loadItems()
                }
            }
            .store(in: &cancellables)

        // Observe gallery service updates
        galleryService.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.galleryViewModel.updateItems(items)
            }
            .store(in: &cancellables)
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        // Cleanup handled by deinit
    }

    // MARK: - Shortcuts

    private func setupShortcuts() {
        shortcutManager.onShortcutTriggered = { [weak self] action in
            Task { @MainActor in
                switch action {
                case .captureFullScreen:
                    await self?.performCapture(type: .fullScreen)
                case .captureArea:
                    await self?.performCapture(type: .selectedArea)
                case .captureWindow:
                    await self?.performCapture(type: .activeWindow)
                case .startRecording:
                    await self?.startRecording()
                case .stopRecording:
                    await self?.stopRecording()
                }
            }
        }

        shortcutManager.registerShortcuts()
    }

    // MARK: - Capture

    private func performCapture(type: CaptureType) async {
        guard let saveURL = settingsViewModel.selectedFolderURL else {
            showNoFolderAlert()
            return
        }

        menuBarController?.flashIcon()

        do {
            // Try capture directly - don't pre-check permission as CGPreflightScreenCaptureAccess is unreliable
            let captureResult = try await captureService.capture(type: type)
            let imageData = captureResult.data

            // Analyze with AI
            let analysis = await textAnalyzer.analyze(imageData: imageData)

            // Generate filename
            let filename = fileNamingEngine.generateFilename(
                appName: analysis.appName,
                hint: analysis.semanticHint,
                type: FileMediaType.image
            )

            let fileURL = saveURL.appendingPathComponent(filename)

            // Save file
            try imageData.write(to: fileURL)

            // Refresh gallery
            await galleryViewModel.loadItems()

        } catch CaptureError.cancelled {
            // User cancelled, do nothing
        } catch CaptureError.noPermission {
            showPermissionAlert()
        } catch let error as NSError where error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && error.code == -3801 {
            // ScreenCaptureKit permission error
            showPermissionAlert()
        } catch {
            // Check if it's a permission-related error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("permission") || errorString.contains("denied") || errorString.contains("tcc") {
                showPermissionAlert()
            } else {
                showErrorAlert(message: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Recording

    private func toggleRecording() async {
        if screenRecordingService.isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        guard let saveURL = settingsViewModel.selectedFolderURL else {
            showNoFolderAlert()
            return
        }

        let filename = fileNamingEngine.generateFilename(
            appName: nil,
            hint: .recording,
            type: FileMediaType.video
        )

        let fileURL = saveURL.appendingPathComponent(filename)

        do {
            try await screenRecordingService.startRecording(to: fileURL)
            menuBarController?.setRecordingState(true)
        } catch RecordingError.noPermission {
            showPermissionAlert()
        } catch let error as NSError where error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && error.code == -3801 {
            showPermissionAlert()
        } catch {
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("permission") || errorString.contains("denied") || errorString.contains("tcc") {
                showPermissionAlert()
            } else {
                showErrorAlert(message: "Recording failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopRecording() async {
        do {
            try await screenRecordingService.stopRecording()
            menuBarController?.setRecordingState(false)
            await galleryViewModel.loadItems()
        } catch {
            showErrorAlert(message: "Failed to stop recording: \(error.localizedDescription)")
        }
    }

    // MARK: - UI Actions

    private func openGallery() {
        if galleryWindowController == nil {
            galleryWindowController = GalleryWindowController(viewModel: galleryViewModel)
        }
        galleryWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettings() {
        SettingsWindowController.show(
            settingsViewModel: settingsViewModel,
            galleryViewModel: galleryViewModel
        )
    }

    private func showNoFolderAlert() {
        let alert = NSAlert()
        alert.messageText = "No Save Folder Selected"
        alert.informativeText = "Please select a folder in Settings to save your captures."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "SuretiShot needs screen recording permission to capture screenshots and recordings. Please grant permission in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Open app settings
            openSettings()
        case .alertSecondButtonReturn:
            // Open system preferences
            PermissionManager.shared.openScreenRecordingSettings()
        default:
            // Cancel - do nothing
            break
        }
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
