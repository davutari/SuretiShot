import SwiftUI
import AppKit

final class GalleryWindowController: NSWindowController {

    convenience init(viewModel: GalleryViewModel) {
        let galleryView = GalleryView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: galleryView)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Constants.Layout.galleryWindowWidth,
                height: Constants.Layout.galleryWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "SuretiShot Gallery"
        window.center()
        window.setFrameAutosaveName("GalleryWindow")
        window.minSize = NSSize(
            width: Constants.Layout.galleryMinWidth,
            height: Constants.Layout.galleryMinHeight
        )

        // Toolbar
        let toolbar = NSToolbar(identifier: "GalleryToolbar")
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}
