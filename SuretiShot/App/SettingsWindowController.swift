import SwiftUI
import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private static var shared: SettingsWindowController?

    static func show(settingsViewModel: SettingsViewModel, galleryViewModel: GalleryViewModel) {
        // Always create a new window if needed
        if shared?.window == nil {
            shared = SettingsWindowController(
                settingsViewModel: settingsViewModel,
                galleryViewModel: galleryViewModel
            )
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    convenience init(settingsViewModel: SettingsViewModel, galleryViewModel: GalleryViewModel) {
        let settingsView = SettingsView()
            .environmentObject(settingsViewModel)
            .environmentObject(galleryViewModel)

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "SuretiShot Settings"
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        // Reset shared so a new window can be created next time
        SettingsWindowController.shared = nil
    }
}
