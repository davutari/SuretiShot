import Foundation

final class FolderWatcher {

    private let url: URL
    private let onChange: () -> Void

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stopWatching()
    }

    func startWatching() {
        guard source == nil else { return }

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open folder for watching: \(url.path)")
            return
        }

        let queue = DispatchQueue.global(qos: .utility)
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            // Debounce rapid changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.onChange()
            }
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source?.resume()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }
}
