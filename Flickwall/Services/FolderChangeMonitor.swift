import CoreServices
import Foundation

@MainActor
final class FolderChangeMonitor {
    var onFolderChanged: ((WallpaperFolderSource) -> Void)?

    private var streams: [WallpaperFolderSource.ID: StreamBox] = [:]

    func update(sources: [WallpaperFolderSource]) {
        let sourceIDs = Set(sources.map(\.id))

        for id in Array(streams.keys) where !sourceIDs.contains(id) {
            stopStream(for: id)
        }

        for source in sources {
            if let existing = streams[source.id] {
                guard existing.source.path != source.path || existing.source.bookmarkData != source.bookmarkData else {
                    continue
                }

                stopStream(for: source.id)
            }

            startStream(for: source)
        }
    }

    func stopAll() {
        for id in Array(streams.keys) {
            stopStream(for: id)
        }
    }

    private func startStream(for source: WallpaperFolderSource) {
        guard streams[source.id] == nil else {
            return
        }

        guard let url = try? source.resolvedURL() else {
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        let box = StreamBox(owner: self, source: source, accessedURL: url, didStartAccessing: didStartAccessing)
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil,
            folderChangeCallback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }

        box.stream = stream
        streams[source.id] = box
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func stopStream(for id: WallpaperFolderSource.ID) {
        guard let box = streams.removeValue(forKey: id) else {
            return
        }

        box.debounceWorkItem?.cancel()

        if let stream = box.stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }

        if box.didStartAccessing {
            box.accessedURL.stopAccessingSecurityScopedResource()
        }
    }

    fileprivate func scheduleChange(for sourceID: WallpaperFolderSource.ID) {
        guard let box = streams[sourceID] else {
            return
        }

        box.debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self, source = box.source] in
            Task { @MainActor in
                self?.onFolderChanged?(source)
            }
        }

        box.debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }
}

private final class StreamBox {
    weak var owner: FolderChangeMonitor?
    let source: WallpaperFolderSource
    let accessedURL: URL
    let didStartAccessing: Bool
    var stream: FSEventStreamRef?
    var debounceWorkItem: DispatchWorkItem?

    init(
        owner: FolderChangeMonitor,
        source: WallpaperFolderSource,
        accessedURL: URL,
        didStartAccessing: Bool
    ) {
        self.owner = owner
        self.source = source
        self.accessedURL = accessedURL
        self.didStartAccessing = didStartAccessing
    }
}

private let folderChangeCallback: FSEventStreamCallback = { _, info, _, _, _, _ in
    guard let info else {
        return
    }

    let box = Unmanaged<StreamBox>.fromOpaque(info).takeUnretainedValue()
    Task { @MainActor in
        box.owner?.scheduleChange(for: box.source.id)
    }
}
