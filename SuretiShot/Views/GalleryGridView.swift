import SwiftUI

struct GalleryGridView: View {
    let items: [MediaItem]
    let selectedItem: MediaItem?
    let onSelect: (MediaItem) -> Void
    let onDoubleClick: (MediaItem) -> Void
    let getThumbnail: (MediaItem) async -> CGImage?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Constants.Defaults.galleryGridSpacing)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Constants.Defaults.galleryGridSpacing) {
                ForEach(items) { item in
                    MediaItemCell(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        getThumbnail: getThumbnail
                    )
                    .onTapGesture {
                        onSelect(item)
                    }
                    .onTapGesture(count: 2) {
                        onDoubleClick(item)
                    }
                }
            }
            .padding(Constants.Defaults.galleryGridSpacing)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct MediaItemCell: View {
    let item: MediaItem
    let isSelected: Bool
    let getThumbnail: (MediaItem) async -> CGImage?

    @State private var thumbnail: CGImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail
            ZStack {
                if let thumbnail = thumbnail {
                    Image(decorative: thumbnail, scale: 2.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 100)
                        .clipped()
                } else if isLoading {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 150, height: 100)
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                } else {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 150, height: 100)
                        .overlay {
                            Image(systemName: item.mediaType.systemImageName)
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }

                // Video indicator
                if item.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(4)
                        }
                    }
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            // Filename
            Text(item.filename)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .task(id: item.id) {
            isLoading = true
            thumbnail = await getThumbnail(item)
            isLoading = false
        }
    }
}

#Preview {
    GalleryGridView(
        items: [],
        selectedItem: nil,
        onSelect: { _ in },
        onDoubleClick: { _ in },
        getThumbnail: { _ in nil }
    )
}
