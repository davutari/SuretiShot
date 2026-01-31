import Foundation
import AppKit

final class FolderAccessManager: ObservableObject {

    private let bookmarkKey = "SaveFolderBookmark"
    private var currentAccessedURL: URL?

    @Published private(set) var hasAccess: Bool = false

    // MARK: - Public Methods

    /// Prompts user to select a folder and saves a security-scoped bookmark
    func selectFolder() async -> URL? {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.title = "Select Save Folder"
            panel.message = "Choose a folder where SuretiShot will save your captures"
            panel.prompt = "Select"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false

            guard panel.runModal() == .OK, let url = panel.url else {
                return nil
            }

            // Stop accessing previous URL
            stopAccessing()

            // Save bookmark
            if saveBookmark(for: url) {
                currentAccessedURL = url
                hasAccess = true
                return url
            }

            return nil
        }
    }

    /// Restores access to previously selected folder using saved bookmark
    func restoreAccess() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Re-save the bookmark
                _ = saveBookmark(for: url)
            }

            if url.startAccessingSecurityScopedResource() {
                currentAccessedURL = url
                hasAccess = true
                return url
            }
        } catch {
            print("Failed to restore bookmark: \(error)")
        }

        return nil
    }

    /// Stops accessing the current security-scoped resource
    func stopAccessing() {
        currentAccessedURL?.stopAccessingSecurityScopedResource()
        currentAccessedURL = nil
        hasAccess = false
    }

    /// Returns the currently accessed URL
    func getCurrentURL() -> URL? {
        currentAccessedURL
    }

    /// Checks if a specific URL can be accessed
    func canAccess(url: URL) -> Bool {
        guard let currentURL = currentAccessedURL else { return false }
        return url.path.hasPrefix(currentURL.path)
    }

    // MARK: - Private Methods

    private func saveBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)

            // Start accessing the resource
            if url.startAccessingSecurityScopedResource() {
                return true
            }
        } catch {
            print("Failed to create bookmark: \(error)")
        }
        return false
    }
}
