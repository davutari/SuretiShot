import SwiftUI
import AVKit
import QuickLook

struct MediaPreviewView: View {
    let item: MediaItem
    let onReveal: (MediaItem) -> Void
    let onCopy: (MediaItem) -> Void
    let onOpen: (MediaItem) -> Void
    let onDelete: (MediaItem) -> Void
    let onRename: (MediaItem, String) -> Bool

    @State private var isEditing = false
    @State private var editedName = ""
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            PreviewContent(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Info panel
            VStack(alignment: .leading, spacing: 12) {
                // Filename
                HStack {
                    if isEditing {
                        TextField("Filename", text: $editedName, onCommit: {
                            if !editedName.isEmpty && editedName != item.filename {
                                if onRename(item, editedName) {
                                    isEditing = false
                                }
                            } else {
                                isEditing = false
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .onExitCommand {
                            isEditing = false
                        }
                    } else {
                        Text(item.filename)
                            .font(.headline)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button(action: {
                        editedName = item.filename
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                    }
                    .buttonStyle(.plain)
                    .help(isEditing ? "Cancel" : "Rename")
                }

                // Metadata
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Type:")
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: item.mediaType.systemImageName)
                            Text(item.mediaType.displayName)
                        }
                    }

                    GridRow {
                        Text("Date:")
                            .foregroundColor(.secondary)
                        Text(item.formattedDate)
                    }

                    GridRow {
                        Text("Size:")
                            .foregroundColor(.secondary)
                        Text(item.formattedFileSize)
                    }

                    if let dimensions = item.dimensionsString {
                        GridRow {
                            Text("Dimensions:")
                                .foregroundColor(.secondary)
                            Text(dimensions)
                        }
                    }

                    if let appName = item.appName {
                        GridRow {
                            Text("App:")
                                .foregroundColor(.secondary)
                            Text(appName)
                        }
                    }

                    if let hint = item.semanticHint {
                        GridRow {
                            Text("Label:")
                                .foregroundColor(.secondary)
                            Text(hint.capitalized)
                        }
                    }
                }
                .font(.caption)

                Divider()

                // Actions
                HStack(spacing: 12) {
                    Button(action: { onReveal(item) }) {
                        Label("Reveal", systemImage: "folder")
                    }
                    .help("Reveal in Finder")

                    Button(action: {
                        onCopy(item)
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedFeedback = false
                        }
                    }) {
                        if showCopiedFeedback {
                            Label("Copied!", systemImage: "checkmark")
                        } else {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    .help("Copy to clipboard")

                    Button(action: { onOpen(item) }) {
                        Label("Open", systemImage: "arrow.up.forward.app")
                    }
                    .help("Open in default app")

                    Spacer()

                    Button(role: .destructive, action: { onDelete(item) }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Move to Trash")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(height: 200)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Preview Content

struct PreviewContent: View {
    let item: MediaItem

    var body: some View {
        switch item.mediaType {
        case .image:
            ImagePreview(url: item.url)
        case .video:
            VideoPreview(url: item.url)
        case .unknown:
            UnknownPreview()
        }
    }
}

struct ImagePreview: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct VideoPreview: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

struct UnknownPreview: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.questionmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Cannot preview this file")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MediaPreviewView(
        item: MediaItem(url: URL(fileURLWithPath: "/tmp/test.png")),
        onReveal: { _ in },
        onCopy: { _ in },
        onOpen: { _ in },
        onDelete: { _ in },
        onRename: { _, _ in true }
    )
    .frame(width: 400, height: 600)
}
