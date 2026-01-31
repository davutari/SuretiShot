import SwiftUI

@main
struct SuretiShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsViewModel)
                .environmentObject(appDelegate.galleryViewModel)
        }
    }
}
