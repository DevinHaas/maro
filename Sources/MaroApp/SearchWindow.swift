import AppKit
import MaroCore
import SwiftUI

@MainActor
final class SearchWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSTabViewDelegate {
    private let controller: MaroController
    private let artwork: ArtworkCache
    private let library: PlaylistLibrary
    private let tabs = NSTabView()
    private let addToPlaylist = NSButton(title: "Add to playlist…", target: nil, action: nil)
    private var images: [String: NSImage] = [:]
    private var artworkTasks: [String: Task<Void, Never>] = [:]
    private let query = NSSearchField()
    private let table = SearchTable()
    private let feedback = NSTextField(wrappingLabelWithString: "Search YouTube for a song, artist, or video.")
    private let more = NSButton(title: "Load 5 more", target: nil, action: nil)
    private let play = NSButton(title: "Play selection", target: nil, action: nil)
    private let submit = NSButton(title: "Search", target: nil, action: nil)
    private var results: [VideoSummary] = []
    private var unavailable: [String: String] = [:]
    private var selectionTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var selectionID = UUID()
    private var pendingVideoID: String?
    private var closeAfterPlaying: String?

    init(controller: MaroController, cacheDirectory: URL, playlistLibrary: PlaylistLibrary? = nil) {
        self.controller = controller
        library = playlistLibrary ?? PlaylistLibrary(controller: controller)
        artwork = ArtworkCache(directory: cacheDirectory)
        let panel = SearchPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 550),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "Maro · YouTube"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = MaroAppearance.background
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 560, height: 450)
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        query.placeholderString = "Song, artist, or video"
        query.setAccessibilityLabel("Search YouTube")
        query.sendsSearchStringImmediately = false
        query.sendsWholeSearchString = true
        query.target = self; query.action = #selector(search)
        query.delegate = self
        submit.target = self; submit.action = #selector(search)
        more.target = self; more.action = #selector(reveal)
        play.target = self; play.action = #selector(selectResult)
        addToPlaylist.target = self; addToPlaylist.action = #selector(addSelection)
        for button in [submit, more, play, addToPlaylist] {
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 12, weight: .medium)
        }
        MaroAppearance.primary(submit)
        MaroAppearance.primary(play)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("video"))
        table.addTableColumn(column)
        table.headerView = nil
        table.backgroundColor = MaroAppearance.background
        table.rowHeight = 68
        table.intercellSpacing = NSSize(width: 0, height: 4)
        table.dataSource = self; table.delegate = self
        table.target = self; table.doubleAction = #selector(selectResult)
        table.choose = { [weak self] in self?.selectResult() }
        table.setAccessibilityLabel("YouTube search results")
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        feedback.font = .systemFont(ofSize: 12)
        feedback.textColor = .secondaryLabelColor
        feedback.setAccessibilityLabel("Search status")
        let searchRow = NSStackView(views: [query, submit])
        searchRow.orientation = .horizontal; searchRow.spacing = 8
        let actions = NSStackView(views: [more, NSView(), addToPlaylist, play])
        actions.orientation = .horizontal
        let content = NSStackView(views: [searchRow, feedback, scroll, actions])
        content.orientation = .vertical; content.alignment = .leading; content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        let searchPage = NSTabViewItem(identifier: "search")
        searchPage.label = "Search"
        let searchContainer = NSView()
        searchPage.view = searchContainer
        searchContainer.addSubview(content)
        let libraryPage = NSTabViewItem(identifier: "playlists")
        libraryPage.label = "Playlists"
        libraryPage.view = NSHostingView(rootView: PlaylistLibraryView(library: library))
        tabs.addTabViewItem(searchPage); tabs.addTabViewItem(libraryPage)
        tabs.delegate = self
        tabs.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(tabs)
        if let root = panel.contentView {
            NSLayoutConstraint.activate([
                tabs.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
                tabs.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
                tabs.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
                tabs.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8)
            ])
            let parent = searchContainer
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
                content.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
                content.topAnchor.constraint(equalTo: parent.topAnchor, constant: 16),
                content.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -16),
                searchRow.widthAnchor.constraint(equalTo: content.widthAnchor),
                feedback.widthAnchor.constraint(equalTo: content.widthAnchor),
                scroll.widthAnchor.constraint(equalTo: content.widthAnchor),
                scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
                actions.widthAnchor.constraint(equalTo: content.widthAnchor)
            ])
        }
        panel.center()
        render()
    }

    func offerAdd(_ video: VideoSummary) {
        closeAfterPlaying = nil
        library.pendingVideo = video
        tabs.selectTabViewItem(at: 1)
        present()
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        closeAfterPlaying = nil
        if tabViewItem?.identifier as? String == "playlists" { library.refresh() }
    }

    @objc private func addSelection() { if let video = selectedVideo { offerAdd(video) } }

    required init?(coder: NSCoder) { nil }

    func present() {
        closeAfterPlaying = nil
        if let window, !window.isVisible {
            let mouse = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
                window.setFrame(Self.presentationFrame(size: window.frame.size,
                    visible: screen.visibleFrame, anchorX: mouse.x), display: false)
            }
        }
        showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if tabs.selectedTabViewItem?.identifier as? String == "playlists" { library.refresh() }
        else { window?.makeFirstResponder(query) }
        render()
    }

    /// Keep text-entry windows near the invocation point, below the bar and on-screen.
    /// Preserve the user's chosen size when it fits the destination display.
    static func presentationFrame(size: NSSize, visible: NSRect, anchorX: CGFloat) -> NSRect {
        let inset = visible.insetBy(dx: min(8, visible.width / 4), dy: min(8, visible.height / 4))
        let width = min(size.width, inset.width)
        let height = min(size.height, inset.height)
        return NSRect(x: max(inset.minX, min(anchorX - width / 2, inset.maxX - width)),
            y: inset.maxY - height, width: width, height: height)
    }

    func render() {
        let search = controller.searchState
        let player = controller.snapshot
        if results != search.results {
            results = search.results
            let visibleIDs = Set(results.map(\.id))
            for id in Array(artworkTasks.keys) where !visibleIDs.contains(id) {
                artworkTasks.removeValue(forKey: id)?.cancel()
                images[id] = nil
            }
            table.reloadData()
            if !results.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
            for video in results where video.thumbnailURL != nil && artworkTasks[video.id] == nil {
                artworkTasks[video.id] = Task { [weak self, artwork] in
                    guard let file = await artwork.image(for: video), !Task.isCancelled,
                          let self, let row = self.results.firstIndex(where: { $0.id == video.id }),
                          let image = NSImage(contentsOf: file) else { return }
                    self.images[video.id] = image
                    self.table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
                }
            }
        }
        submit.isEnabled = !player.sourceNeedsUpdate
        more.isHidden = !search.hasMore
        more.isEnabled = !search.isSearching
        play.isEnabled = results.indices.contains(table.selectedRow) && !player.sourceNeedsUpdate
        addToPlaylist.isEnabled = selectedVideo != nil
        if player.sourceNeedsUpdate { feedback.stringValue = "YouTube source needs an update." }
        else if player.isSelecting { feedback.stringValue = "Preparing audio…" }
        else if search.isSearching { feedback.stringValue = "Searching YouTube…" }
        else if let error = search.error { feedback.stringValue = error }
        else if let id = selectedVideo?.id, let error = unavailable[id] { feedback.stringValue = error }
        else if closeAfterPlaying != nil, let error = player.error { feedback.stringValue = error }
        else if closeAfterPlaying != nil, player.playback == .paused { feedback.stringValue = "Ready. Playback is paused." }
        else if search.query.isEmpty { feedback.stringValue = "Search YouTube for a song, artist, or video." }
        else if results.isEmpty { feedback.stringValue = "No videos found. Try another search." }
        else { feedback.stringValue = "\(results.count) results · Select a video and press Return to play." }
        if let id = closeAfterPlaying, player.loadedVideo?.video.id == id, player.playback == .playing {
            closeAfterPlaying = nil
            window?.orderOut(nil)
        }
    }

    @objc private func search() {
        let text = query.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { feedback.stringValue = "Enter a song, artist, or video."; return }
        guard !controller.searchState.isSearching || controller.searchState.query != text else { return }
        closeAfterPlaying = nil
        unavailable.removeAll()
        searchTask?.cancel()
        searchTask = Task { await controller.search(text) }
    }

    @objc private func reveal() { controller.revealMoreResults() }

    private var selectedVideo: VideoSummary? {
        results.indices.contains(table.selectedRow) ? results[table.selectedRow] : nil
    }

    @objc private func selectResult() {
        guard let video = selectedVideo else { return }
        guard pendingVideoID != video.id else { return }
        selectionTask?.cancel()
        selectionID = UUID()
        let id = selectionID
        pendingVideoID = video.id
        closeAfterPlaying = nil
        unavailable[video.id] = nil
        selectionTask = Task {
            defer { if selectionID == id { pendingVideoID = nil } }
            do {
                try await controller.select(video)
                guard selectionID == id else { return }
                closeAfterPlaying = video.id
            } catch {
                guard selectionID == id else { return }
                unavailable[video.id] = controller.snapshot.error ?? "This video is unavailable. Try another result."
                let selectedID = selectedVideo?.id
                table.reloadData()
                if let row = results.firstIndex(where: { $0.id == selectedID }) {
                    table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                }
            }
            render()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }
    func tableViewSelectionDidChange(_ notification: Notification) { render() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard results.indices.contains(row) else { return nil }
        let video = results[row]
        let icon = NSImageView(image: images[video.id] ?? NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: nil) ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 6
        icon.layer?.masksToBounds = true
        icon.contentTintColor = .secondaryLabelColor
        let title = NSTextField(labelWithString: video.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: unavailable[video.id] == nil ? video.creator : "Unavailable · choose another video")
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        let labels = NSStackView(views: [title, detail])
        labels.orientation = .vertical; labels.alignment = .leading; labels.spacing = 4
        let seconds = video.durationSeconds.map { Int(min($0, 359_999)) }
        let duration = NSTextField(labelWithString: seconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) } ?? "—")
        duration.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        duration.textColor = .secondaryLabelColor
        let cell = NSStackView(views: [icon, labels, duration])
        cell.orientation = .horizontal; cell.spacing = 12
        icon.widthAnchor.constraint(equalToConstant: 58).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cell.setAccessibilityLabel("\(video.title), \(video.creator), \(duration.stringValue)")
        return cell
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)), !results.isEmpty {
            window?.makeFirstResponder(table)
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { window?.orderOut(nil); return true }
        return false
    }
}

private final class SearchPanel: NSPanel {
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}

private final class SearchTable: NSTableView {
    var choose: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { choose?() }
        else if event.keyCode == 53 { window?.orderOut(nil) }
        else { super.keyDown(with: event) }
    }
}
