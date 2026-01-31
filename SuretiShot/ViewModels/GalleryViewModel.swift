import Foundation
import Combine
import AppKit

@MainActor
final class GalleryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var filteredItems: [MediaItem] = []
    @Published private(set) var isLoading = false

    @Published var selectedItem: MediaItem?
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var filter: GalleryFilter = .all {
        didSet {
            savePreferences()
            applyFilters()
        }
    }
    @Published var sortOrder: GallerySortOrder = .newestFirst {
        didSet {
            savePreferences()
            applyFilters()
        }
    }

    // MARK: - Services

    private let galleryService: GalleryService
    private let folderAccessManager: FolderAccessManager

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var hasFolder: Bool {
        folderAccessManager.getCurrentURL() != nil
    }

    var folderName: String {
        folderAccessManager.getCurrentURL()?.lastPathComponent ?? "No folder"
    }

    var itemCount: Int {
        filteredItems.count
    }

    var screenshotCount: Int {
        items.filter { $0.mediaType == .image }.count
    }

    var recordingCount: Int {
        items.filter { $0.mediaType == .video }.count
    }

    // MARK: - Initialization

    init(galleryService: GalleryService, folderAccessManager: FolderAccessManager) {
        self.galleryService = galleryService
        self.folderAccessManager = folderAccessManager

        loadPreferences()
    }

    // MARK: - Public Methods

    func loadItems() async {
        isLoading = true
        await galleryService.refresh()
        isLoading = false
    }

    func updateItems(_ newItems: [MediaItem]) {
        items = newItems
        applyFilters()
    }

    func getThumbnail(for item: MediaItem) async -> CGImage? {
        await galleryService.getThumbnail(for: item, size: Constants.Defaults.thumbnailSize)
    }

    func deleteItem(_ item: MediaItem) {
        do {
            try galleryService.deleteItem(item)
            if selectedItem?.id == item.id {
                selectedItem = nil
            }
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    func renameItem(_ item: MediaItem, to newName: String) -> Bool {
        do {
            let newURL = try galleryService.renameItem(item, to: newName)
            // Update selected item if it was renamed
            if selectedItem?.id == item.id {
                selectedItem = MediaItem(url: newURL)
            }
            return true
        } catch {
            print("Failed to rename item: \(error)")
            return false
        }
    }

    func revealInFinder(_ item: MediaItem) {
        galleryService.revealInFinder(item)
    }

    func openInDefaultApp(_ item: MediaItem) {
        galleryService.openInDefaultApp(item)
    }

    func copyToClipboard(_ item: MediaItem) -> Bool {
        galleryService.copyToClipboard(item)
    }

    func selectItem(_ item: MediaItem?) {
        selectedItem = item
    }

    func selectNext() {
        guard let current = selectedItem,
              let index = filteredItems.firstIndex(of: current),
              index + 1 < filteredItems.count else {
            return
        }
        selectedItem = filteredItems[index + 1]
    }

    func selectPrevious() {
        guard let current = selectedItem,
              let index = filteredItems.firstIndex(of: current),
              index > 0 else {
            return
        }
        selectedItem = filteredItems[index - 1]
    }

    // MARK: - Private Methods

    private func applyFilters() {
        var result = items

        // Apply type filter
        switch filter {
        case .all:
            break
        case .screenshots:
            result = result.filter { $0.mediaType == .image }
        case .recordings:
            result = result.filter { $0.mediaType == .video }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                item.filename.lowercased().contains(query) ||
                item.appName?.lowercased().contains(query) == true ||
                item.semanticHint?.lowercased().contains(query) == true
            }
        }

        // Apply sort
        switch sortOrder {
        case .newestFirst:
            result.sort { $0.createdDate > $1.createdDate }
        case .oldestFirst:
            result.sort { $0.createdDate < $1.createdDate }
        case .nameAscending:
            result.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
        case .nameDescending:
            result.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedDescending }
        case .typeGrouped:
            result.sort { item1, item2 in
                if item1.mediaType == item2.mediaType {
                    return item1.createdDate > item2.createdDate
                }
                return item1.mediaType == .image
            }
        }

        filteredItems = result
    }

    private func loadPreferences() {
        if let filterRaw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.galleryFilter),
           let savedFilter = GalleryFilter(rawValue: filterRaw) {
            filter = savedFilter
        }

        if let sortRaw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.gallerySortOrder),
           let savedSort = GallerySortOrder(rawValue: sortRaw) {
            sortOrder = savedSort
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(filter.rawValue, forKey: Constants.UserDefaultsKeys.galleryFilter)
        UserDefaults.standard.set(sortOrder.rawValue, forKey: Constants.UserDefaultsKeys.gallerySortOrder)
    }
}
