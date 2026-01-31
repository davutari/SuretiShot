import SwiftUI
import AppKit

final class MenuBarController: NSObject {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var isRecording = false

    private let settingsViewModel: SettingsViewModel
    private let galleryViewModel: GalleryViewModel
    private let onCapture: (CaptureType) -> Void
    private let onToggleRecording: () -> Void
    private let onOpenGallery: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private var recordingMenuItem: NSMenuItem?
    private var flashTimer: Timer?

    init(
        settingsViewModel: SettingsViewModel,
        galleryViewModel: GalleryViewModel,
        onCapture: @escaping (CaptureType) -> Void,
        onToggleRecording: @escaping () -> Void,
        onOpenGallery: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settingsViewModel = settingsViewModel
        self.galleryViewModel = galleryViewModel
        self.onCapture = onCapture
        self.onToggleRecording = onToggleRecording
        self.onOpenGallery = onOpenGallery
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        super.init()
        setupStatusItem()
        setupMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SuretiShot")
            button.image?.isTemplate = true
        }
    }

    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self

        // Screenshot section
        let screenshotHeader = NSMenuItem(title: "Screenshot", action: nil, keyEquivalent: "")
        screenshotHeader.isEnabled = false
        menu.addItem(screenshotHeader)

        let fullScreenItem = NSMenuItem(
            title: "Capture Full Screen",
            action: #selector(captureFullScreen),
            keyEquivalent: ""
        )
        fullScreenItem.target = self
        menu.addItem(fullScreenItem)

        let areaItem = NSMenuItem(
            title: "Capture Selected Area",
            action: #selector(captureArea),
            keyEquivalent: ""
        )
        areaItem.target = self
        menu.addItem(areaItem)

        let windowItem = NSMenuItem(
            title: "Capture Active Window",
            action: #selector(captureWindow),
            keyEquivalent: ""
        )
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(NSMenuItem.separator())

        // Recording section
        let recordingHeader = NSMenuItem(title: "Recording", action: nil, keyEquivalent: "")
        recordingHeader.isEnabled = false
        menu.addItem(recordingHeader)

        recordingMenuItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordingMenuItem?.target = self
        menu.addItem(recordingMenuItem!)

        menu.addItem(NSMenuItem.separator())

        // Gallery
        let galleryItem = NSMenuItem(
            title: "Open Gallery",
            action: #selector(openGallery),
            keyEquivalent: "g"
        )
        galleryItem.keyEquivalentModifierMask = [.command, .shift]
        galleryItem.target = self
        menu.addItem(galleryItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit SuretiShot",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func captureFullScreen() {
        onCapture(.fullScreen)
    }

    @objc private func captureArea() {
        onCapture(.selectedArea)
    }

    @objc private func captureWindow() {
        onCapture(.activeWindow)
    }

    @objc private func toggleRecording() {
        onToggleRecording()
    }

    @objc private func openGallery() {
        onOpenGallery()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quitApp() {
        onQuit()
    }

    // MARK: - Public Methods

    func setRecordingState(_ recording: Bool) {
        isRecording = recording

        if recording {
            recordingMenuItem?.title = "Stop Recording"
            statusItem.button?.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            statusItem.button?.contentTintColor = .systemRed
        } else {
            recordingMenuItem?.title = "Start Recording"
            statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SuretiShot")
            statusItem.button?.contentTintColor = nil
        }
    }

    func flashIcon() {
        guard let button = statusItem.button else { return }

        let originalImage = button.image
        var flashCount = 0
        let maxFlashes = 4

        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            flashCount += 1

            if flashCount % 2 == 0 {
                button.image = originalImage
            } else {
                button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Captured")
            }

            if flashCount >= maxFlashes {
                timer.invalidate()
                button.image = originalImage
                self?.flashTimer = nil
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update menu items if needed
    }
}
