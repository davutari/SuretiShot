import Foundation
import Combine
import AppKit
import CoreGraphics

final class GalleryService: ObservableObject {

    private let folderAccessManager: FolderAccessManager
    private let thumbnailProvider: ThumbnailProvider
    private var folderWatcher: FolderWatcher?

    private var monitoredFolder: URL?
    private let itemsSubject = CurrentValueSubject<[MediaItem], Never>([])

    var itemsPublisher: AnyPublisher<[MediaItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    private let supportedExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "mov", "mp4", "m4v"]

    init(folderAccessManager: FolderAccessManager) {
        self.folderAccessManager = folderAccessManager
        self.thumbnailProvider = ThumbnailProvider()
    }

    // MARK: - Public Methods

    func startMonitoring(folder: URL) {
        monitoredFolder = folder

        // Stop previous watcher
        folderWatcher?.stopWatching()

        // Create new watcher
        folderWatcher = FolderWatcher(url: folder) { [weak self] in
            Task {
                await self?.scanFolder()
            }
        }
        folderWatcher?.startWatching()

        // Initial scan
        Task {
            await scanFolder()
        }
    }

    func stopMonitoring() {
        folderWatcher?.stopWatching()
        folderWatcher = nil
        monitoredFolder = nil
        itemsSubject.send([])
    }

    func refresh() async {
        await scanFolder()
    }

    func getThumbnail(for item: MediaItem, size: CGSize) async -> CGImage? {
        await thumbnailProvider.thumbnail(for: item.url, size: size)
    }

    func deleteItem(_ item: MediaItem) throws {
        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
    }

    func renameItem(_ item: MediaItem, to newName: String) throws -> URL {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: item.url, to: newURL)
        return newURL
    }

    func revealInFinder(_ item: MediaItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func openInDefaultApp(_ item: MediaItem) {
        NSWorkspace.shared.open(item.url)
    }

    func copyToClipboard(_ item: MediaItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.mediaType == .image {
            // For images, copy both the file URL and image data
            if let image = NSImage(contentsOf: item.url) {
                pasteboard.writeObjects([image])
                return true
            }
        }

        // For videos or fallback, copy file URL
        pasteboard.writeObjects([item.url as NSURL])
        return true
    }

    // MARK: - Private Methods

    private func scanFolder() async {
        guard let folder = monitoredFolder else { return }

        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .contentTypeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )

            let items = contents
                .filter { url in
                    supportedExtensions.contains(url.pathExtension.lowercased())
                }
                .map { MediaItem(url: $0) }
                .sorted { $0.createdDate > $1.createdDate }

            itemsSubject.send(items)
        } catch {
            print("Failed to scan folder: \(error)")
            itemsSubject.send([])
        }
    }
}
