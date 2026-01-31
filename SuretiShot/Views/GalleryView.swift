import SwiftUI

struct GalleryView: View {
    @ObservedObject var viewModel: GalleryViewModel

    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: MediaItem?

    var body: some View {
        NavigationSplitView {
            // Sidebar with grid
            VStack(spacing: 0) {
                // Toolbar
                GalleryToolbar(viewModel: viewModel)

                Divider()

                // Grid
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredItems.isEmpty {
                    EmptyGalleryView(hasFolder: viewModel.hasFolder)
                } else {
                    GalleryGridView(
                        items: viewModel.filteredItems,
                        selectedItem: viewModel.selectedItem,
                        onSelect: { viewModel.selectItem($0) },
                        onDoubleClick: { viewModel.openInDefaultApp($0) },
                        getThumbnail: { await viewModel.getThumbnail(for: $0) }
                    )
                }
            }
            .frame(minWidth: 400)
        } detail: {
            // Detail panel
            if let item = viewModel.selectedItem {
                MediaPreviewView(
                    item: item,
                    onReveal: { viewModel.revealInFinder($0) },
                    onCopy: { _ = viewModel.copyToClipboard($0) },
                    onOpen: { viewModel.openInDefaultApp($0) },
                    onDelete: {
                        itemToDelete = $0
                        showingDeleteConfirmation = true
                    },
                    onRename: { item, newName in
                        return viewModel.renameItem(item, to: newName)
                    }
                )
            } else {
                NoSelectionView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    viewModel.deleteItem(item)
                }
            }
        } message: {
            Text("Are you sure you want to move this item to the Trash?")
        }
        .onAppear {
            Task {
                await viewModel.loadItems()
            }
        }
    }
}

// MARK: - Gallery Toolbar

struct GalleryToolbar: View {
    @ObservedObject var viewModel: GalleryViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 200)

            Spacer()

            // Filter
            Picker("Filter", selection: $viewModel.filter) {
                ForEach(GalleryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Sort
            Menu {
                ForEach(GallerySortOrder.allCases) { order in
                    Button(action: { viewModel.sortOrder = order }) {
                        HStack {
                            Text(order.rawValue)
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)

            // Refresh
            Button(action: {
                Task {
                    await viewModel.loadItems()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")

            // Item count
            Text("\(viewModel.itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty State

struct EmptyGalleryView: View {
    let hasFolder: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasFolder ? "photo.on.rectangle.angled" : "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(hasFolder ? "No captures yet" : "No folder selected")
                .font(.headline)

            Text(hasFolder ?
                 "Captured screenshots and recordings will appear here" :
                 "Select a folder in Settings to start capturing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - No Selection

struct NoSelectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an item to preview")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GalleryView(viewModel: GalleryViewModel(
        galleryService: GalleryService(folderAccessManager: FolderAccessManager()),
        folderAccessManager: FolderAccessManager()
    ))
}
