import Foundation

public enum PlaybackState: String, Codable, Sendable { case idle, paused, buffering, playing, ended }
public enum ControllerFailure: Error, Equatable, Sendable { case shutDown }

public struct PlayerSnapshot: Codable, Sendable {
    public let loadedVideo: LoadedVideo?
    public let favorites: [VideoSummary]
    public let playback: PlaybackState
    public let isSelecting: Bool
    public let sourceNeedsUpdate: Bool
    public let error: String?
    public let persistenceError: String?
    public var localThumbnailPaths: [String: String]? = nil
    public var canGoPrevious: Bool? = nil
    public var canGoNext: Bool? = nil
    public var volume: Double? = nil
    public var timeline: PlaybackTimeline? = nil
    public var playbackID: UUID? = nil
    public var timelineID: UUID? = nil
    public var seekTarget: Double? = nil
    public var activePlaylistItemID: String? = nil
    public var originPlaylistID: String? = nil

    func commandResponseSnapshot() -> PlayerSnapshot {
        var response = self
        let allowedArtworkIDs = Set(favorites.map(\.id) + (loadedVideo.map { [$0.video.id] } ?? []))
        response.localThumbnailPaths = localThumbnailPaths?.filter { allowedArtworkIDs.contains($0.key) }
        return response
    }
}

public struct SearchViewState: Sendable {
    public let query: String
    public let results: [VideoSummary]
    public let isSearching: Bool
    public let hasMore: Bool
    public let error: String?
    public var isLoadingMore: Bool = false
    public var loadMoreError: String? = nil
}

@MainActor
public final class MaroController {
    private let engine: PlaybackEngine
    private let store: StateStore
    private let sourceBuild: String
    private var sourceLifetime: YouTubeClient?
    private var sourceWarmup: Task<Void, Never>?
    private let prepareVideo: @MainActor (VideoSummary, Double) async throws -> PreparedPlayback
    private var state: StateDocument
    private var playback: PlaybackState
    private var wantsPlayback = false
    private var transportIntent = 0
    private var seekTask: Task<Void, Never>?
    private var pendingSeek: Double?
    private var seekTarget: Double?
    private var seekID = UUID()
    private var endedPlaybackID: UUID?
    private var selecting = false
    private var recoveryAttempted = false
    private var needsUpdate = false
    private var isShutDown = false
    private var errorMessage: String?
    private var persistenceError: String?
    private var query = ""
    private var searching = false
    private var searchError: String?
    private var loadingMore = false
    private var loadMoreError: String?
    private var pageTask: Task<Void, Never>?
    private var session: SearchSession?
    private var playlistQueue: [YouTubePlaylistItem] = []
    private var playlistIndex: Int?
    private var originPlaylistID: String?
    private var queueID = UUID()
    private var queueTask: Task<Void, Error>?
    private var queueAutoplay = false
    private var selectionID = UUID()
    private var searchID = UUID()
    private var selectionTask: Task<Void, Error>?
    private var selectionVideoID: String?
    private var selectionPosition: Double = 0
    private var searchTask: Task<Void, Never>?
    private let metadataRequests: MetadataSearchRequests
    private var pendingSave: Task<Void, Never>?
    private var saveRevision = 0
    private var lastCheckpoint = ProcessInfo.processInfo.systemUptime
    private let artworkCache: ArtworkCache?
    private var artworkTask: Task<Void, Never>?
    private var artworkVideos: [VideoSummary] = []
    private var metadataArtworkVideos: [VideoSummary] = []
    private var artworkPaths: [String: String] = [:]
    public var onChange: (@MainActor () -> Void)?

    public var snapshot: PlayerSnapshot {
        PlayerSnapshot(loadedVideo: state.loadedVideo, favorites: state.favorites,
            playback: playback, isSelecting: selecting, sourceNeedsUpdate: needsUpdate,
            error: errorMessage, persistenceError: persistenceError,
            localThumbnailPaths: artworkPaths.filter { FileManager.default.fileExists(atPath: $0.value) },
            canGoPrevious: !selecting && !needsUpdate && canNavigate(-1),
            canGoNext: !selecting && !needsUpdate && canNavigate(1),
            volume: engine.volume,
            timeline: selecting || needsUpdate || isShutDown ? nil : engine.timeline,
            playbackID: engine.playbackID, timelineID: selectionID, seekTarget: seekTarget,
            activePlaylistItemID: playlistIndex.flatMap { playlistQueue.indices.contains($0) ? playlistQueue[$0].id : nil },
            originPlaylistID: playlistIndex == nil ? nil : originPlaylistID)
    }
    public var searchState: SearchViewState {
        SearchViewState(query: query, results: session?.visibleResults ?? [], isSearching: searching,
                        hasMore: session?.hasMore ?? false, error: searchError,
                        isLoadingMore: loadingMore, loadMoreError: loadMoreError)
    }

    public static func open(store: StateStore, source: YouTubeClient,
                            engine: PlaybackEngine,
                            sourceBuild: String = "maro-dev-1/yt-dlp-2026.08.19",
                            artworkCache: ArtworkCache? = nil) async throws -> MaroController {
        let loaded = try await store.load()
        let controller = try MaroController(loaded: loaded, store: store, engine: engine, sourceBuild: sourceBuild, artworkCache: artworkCache,
            search: { try await source.search($0) },
            searchPage: { try await source.searchPage($0, continuation: $1) },
            prepare: { video, position in
                try await engine.prepare(source.resolve(videoID: video.id), positionSeconds: position)
            })
        controller.sourceLifetime = source
        return controller
    }

    init(loaded: StateLoadResult, store: StateStore, engine: PlaybackEngine,
         sourceBuild: String = "maro-dev-1/yt-dlp-2026.08.19",
         artworkCache: ArtworkCache? = nil,
         searchNow: @escaping () -> ContinuousClock.Instant = { ContinuousClock().now },
         search: @escaping @Sendable (String) async throws -> [VideoSummary],
         searchPage: (@Sendable (String, String?) async throws -> SearchPage)? = nil,
         prepare: @escaping @MainActor (VideoSummary, Double) async throws -> PreparedPlayback) throws {
        try loaded.document.validate()
        guard !sourceBuild.isEmpty, sourceBuild.utf8.count <= 128 else { throw StateError.invalidSourceBuild }
        self.sourceBuild = sourceBuild
        self.artworkCache = artworkCache
        metadataRequests = MetadataSearchRequests(source: searchPage ?? { query, _ in SearchPage(videos: try await search(query)) }, now: searchNow)
        state = loaded.document
        needsUpdate = state.sourceDisabledBuild == sourceBuild
        if !needsUpdate { state.sourceDisabledBuild = nil }
        if needsUpdate {
            errorMessage = ExtractorFailure.sourceNeedsUpdate.message
            searchError = errorMessage
        }
        playback = state.loadedVideo == nil ? .idle : .paused
        persistenceError = loaded.warning
        self.store = store
        self.engine = engine
        prepareVideo = prepare
        engine.onEvent = { [weak self] event in self?.handle(event) }
        metadataRequests.onChange = { [weak self] in self?.publish() }
        refreshArtwork()
    }

    deinit {
        sourceWarmup?.cancel()
        artworkTask?.cancel()
        selectionTask?.cancel()
        searchTask?.cancel()
        pageTask?.cancel()
        queueTask?.cancel()
    }

    public func search(_ query: String) async {
        guard !isShutDown else { return }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if searching, self.query == query, let searchTask {
            await searchTask.value
            return
        }
        searchTask?.cancel()
        pageTask?.cancel(); pageTask = nil; loadingMore = false; loadMoreError = nil
        searchID = UUID()
        let id = searchID
        self.query = query
        session = nil
        searchError = nil
        guard !needsUpdate else { searchError = ExtractorFailure.sourceNeedsUpdate.message; publish(); return }
        searching = true
        publish()
        let task = Task { @MainActor in
            do {
                let page = try await metadataSearchPage(query, intent: .foreground)
                try Task.checkCancellation()
                guard searchID == id else { return }
                let fresh = try SearchSession(query: query, results: page.videos, continuation: page.continuation)
                session = fresh
            } catch {
                guard searchID == id else { return }
                searchError = error is CancellationError ? "Search was interrupted. Try again." : message(error)
                if error as? ExtractorFailure == .sourceNeedsUpdate { disableSource() }
            }
            guard searchID == id else { return }
            searching = false
            searchTask = nil
            publish()
        }
        searchTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    public var hasForegroundMetadataRequest: Bool { metadataRequests.foregroundActive }
    public var metadataProviderVersion: String { sourceBuild }
    public func cancelForegroundMetadataSearch() { metadataRequests.cancelForeground() }
    public func metadataSearch(_ query: String, intent: MetadataSearchIntent = .foreground) async throws -> [VideoSummary] {
        try await metadataSearchPage(query, intent: intent).videos
    }
    private func metadataSearchPage(_ query: String, continuation: String? = nil, intent: MetadataSearchIntent) async throws -> SearchPage {
        guard !isShutDown else { throw ControllerFailure.shutDown }
        guard !needsUpdate else { throw ExtractorFailure.sourceNeedsUpdate }
        if intent == .discovery, selecting || metadataRequests.foregroundActive { throw CancellationError() }
        do {
            let page = try await metadataRequests.request(query, continuation: continuation, intent: intent)
            let videos = page.videos
            var seen = Set<String>()
            metadataArtworkVideos = Array((videos + metadataArtworkVideos).filter { seen.insert($0.id).inserted }.prefix(60))
            refreshArtwork()
            return page
        }
        catch {
            if error as? ExtractorFailure == .sourceNeedsUpdate { disableSource() }
            throw error
        }
    }

    public func loadMoreResults(retry: Bool = false) async {
        guard !isShutDown, !needsUpdate, !searching, !loadingMore,
              retry || loadMoreError == nil, let cursor = session?.continuation else { return }
        let id = searchID, query = self.query
        loadingMore = true; loadMoreError = nil; publish()
        let task = Task { @MainActor in
            do {
                let page = try await metadataSearchPage(query, continuation: cursor, intent: .foreground)
                try Task.checkCancellation()
                guard searchID == id, session?.continuation == cursor else { return }
                _ = try session?.append(page)
            } catch {
                guard searchID == id else { return }
                loadMoreError = error is CancellationError ? "Loading was interrupted. Try again." : message(error)
                if error as? ExtractorFailure == .sourceNeedsUpdate { disableSource() }
            }
            guard searchID == id else { return }
            loadingMore = false; pageTask = nil; publish()
        }
        pageTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    public func setVolume(_ volume: Double) {
        guard !isShutDown else { return }
        engine.volume = volume
        publish()
    }

    public func select(_ video: VideoSummary) async throws {
        metadataRequests.cancelActive()
        queueID = UUID()
        if queueTask != nil {
            selectionTask?.cancel(); selectionID = UUID(); selecting = false
        }
        queueTask?.cancel(); queueTask = nil
        playlistQueue = []; playlistIndex = nil; originPlaylistID = nil
        try await load(video, position: 0)
    }

    /// Snapshot the saved order. Browsing or editing a playlist does not rewrite active playback.
    public func playPlaylist(_ items: [YouTubePlaylistItem], startingAt index: Int = 0, playlistID: String? = nil) async throws {
        guard !isShutDown else { throw ControllerFailure.shutDown }
        guard items.indices.contains(index) else { throw CommandProtocolFailure.invalidArguments }
        queueTask?.cancel()
        selectionTask?.cancel(); selectionID = UUID(); selecting = false
        queueID = UUID()
        playlistQueue = items; playlistIndex = nil; originPlaylistID = playlistID
        try await runQueue(from: index, step: 1, autoplay: true)
    }

    private func canNavigate(_ offset: Int) -> Bool {
        if !playlistQueue.isEmpty {
            return playlistIndex.map { playlistQueue.indices.contains($0 + offset) } ?? false
        }
        return neighbor(offset) != nil
    }

    private func runQueue(from index: Int, step: Int, autoplay: Bool) async throws {
        queueTask?.cancel()
        queueID = UUID()
        let id = queueID
        queueAutoplay = autoplay
        let task = Task { @MainActor in
            var index = index
            var skipped = 0
            while self.playlistQueue.indices.contains(index) {
                try Task.checkCancellation()
                guard self.queueID == id, !self.isShutDown else { throw PlaybackFailure.superseded }
                let item = self.playlistQueue[index]
                if let video = item.video {
                    do {
                        try await self.load(video, position: 0, autoplay: self.queueAutoplay)
                        try Task.checkCancellation()
                        guard self.queueID == id else { throw PlaybackFailure.superseded }
                        self.playlistIndex = index
                        if skipped > 0 { self.errorMessage = "Skipped \(skipped) unplayable playlist \(skipped == 1 ? "video" : "videos")." }
                        self.publish()
                        return
                    } catch is CancellationError { throw CancellationError() }
                    catch PlaybackFailure.superseded { throw PlaybackFailure.superseded }
                    catch {
                        guard !self.needsUpdate else { throw error }
                        self.errorMessage = "Skipping \(item.title): \(self.message(error))"
                        self.publish()
                    }
                }
                skipped += 1
                index += step
            }
            guard self.queueID == id else { throw PlaybackFailure.superseded }
            self.engine.pause()
            self.wantsPlayback = false
            self.playback = self.state.loadedVideo == nil ? .idle : .ended
            self.errorMessage = "No playable videos remain in this direction."
            self.capturePosition(); self.enqueueSave(); self.publish()
        }
        queueTask = task
        defer { if queueID == id { queueTask = nil } }
        try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    @discardableResult
    private func advancePlaylist() -> Bool {
        guard !selecting, wantsPlayback, let index = playlistIndex,
              playlistQueue.indices.contains(index + 1) else { return false }
        let id = queueID
        Task { [weak self] in
            guard let self, self.queueID == id, self.wantsPlayback, !self.isShutDown else { return }
            try? await self.runQueue(from: index + 1, step: 1, autoplay: true)
        }
        return true
    }

    private func neighbor(_ offset: Int) -> VideoSummary? {
        guard let id = state.loadedVideo?.video.id else { return nil }
        return session?.neighbor(of: id, offset: offset)
    }

    private func load(_ video: VideoSummary, position: Double, recovering: Bool = false, autoplay: Bool = true) async throws {
        metadataRequests.cancelActive()
        cancelTimelineSeek()
        endedPlaybackID = nil
        guard !isShutDown else { throw ControllerFailure.shutDown }
        try video.validate()
        guard !needsUpdate else { throw ExtractorFailure.sourceNeedsUpdate }
        try Task.checkCancellation()
        if !recovering, selecting, selectionVideoID == video.id, selectionPosition == position,
           let selectionTask {
            // Duplicate requests share the existing operation and its outcome.
            try await selectionTask.value
            try Task.checkCancellation()
            return
        }
        selectionTask?.cancel()
        selectionID = UUID()
        let id = selectionID
        let previousIntent = wantsPlayback
        transportIntent += 1
        let intent = transportIntent
        if !recovering { wantsPlayback = autoplay; recoveryAttempted = false }
        selecting = true
        selectionVideoID = video.id
        selectionPosition = position
        errorMessage = nil
        publish()
        let task = Task { @MainActor in
          do {
            let prepared: PreparedPlayback?
            if !recovering, engine.loadedVideo?.id == video.id, engine.hasReadyItem {
                do {
                    try await engine.seekLoaded(to: position)
                    prepared = nil
                } catch is CancellationError { throw CancellationError() }
                catch PlaybackFailure.superseded { throw PlaybackFailure.superseded }
                catch { prepared = try await prepareVideo(video, position) }
            } else {
                prepared = try await prepareVideo(video, position)
            }
            guard selectionID == id else { throw PlaybackFailure.superseded }
            try Task.checkCancellation()
            capturePosition()
            enqueueSave()
            if let prepared { try engine.commit(prepared, autoplay: wantsPlayback) }
            else if wantsPlayback { try engine.resume() }
            else { engine.pause() }
            state.loadedVideo = try LoadedVideo(video: prepared?.video ?? video, positionSeconds: engine.positionSeconds)
            playback = wantsPlayback ? .buffering : .paused
            selecting = false
            selectionTask = nil
            enqueueSave()
            publish()
          } catch {
            guard selectionID == id else { throw PlaybackFailure.superseded }
            selecting = false
            selectionTask = nil
            if transportIntent == intent { wantsPlayback = previousIntent }
            let shouldSkip = recovering && wantsPlayback && transportIntent == intent
            if recovering { wantsPlayback = false; playback = .paused }
            errorMessage = message(error)
            if error as? ExtractorFailure == .sourceNeedsUpdate { disableSource() }
            if shouldSkip, !needsUpdate {
                wantsPlayback = true
                if advancePlaylist() { playback = .buffering } else { wantsPlayback = false }
            }
            publish()
            throw error
          }
        }
        selectionTask = task
        try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    /// Coalesces commits while preserving the latest explicit transport intent.
    public func seek(to seconds: Double, timelineID: UUID) {
        guard !isShutDown, !selecting, !needsUpdate,
              selectionID == timelineID, let playbackID = engine.playbackID,
              let target = engine.timeline?.target(for: seconds) else { return }
        pendingSeek = target
        seekTarget = target
        endedPlaybackID = nil
        guard seekTask == nil else { publish(); return }
        let id = UUID()
        seekID = id
        let selection = selectionID
        errorMessage = nil
        seekTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var confirmedTarget: Double?
            while let requested = pendingSeek {
                pendingSeek = nil
                guard seekID == id, selectionID == selection,
                      engine.playbackID == playbackID, !Task.isCancelled else { return }
                do {
                    guard let target = engine.timeline?.target(for: requested) else {
                        throw PlaybackFailure.invalidPosition
                    }
                    try await engine.seekLoaded(to: target, invalidateOnFailure: false)
                    confirmedTarget = target
                } catch {
                    confirmedTarget = nil
                    guard seekID == id, selectionID == selection,
                          engine.playbackID == playbackID, !Task.isCancelled else { return }
                    if !(error is CancellationError), error as? PlaybackFailure != .superseded {
                        errorMessage = "Could not seek to that position. Try again."
                    }
                }
                guard seekID == id, selectionID == selection,
                      engine.playbackID == playbackID, !Task.isCancelled else { return }
            }
            seekTask = nil
            seekTarget = nil
            capturePosition()
            if wantsPlayback {
                do { try engine.resume(); playback = .buffering }
                catch { wantsPlayback = false; playback = .paused }
            } else { engine.pause(); playback = .paused }
            enqueueSave()
            publish()
            if wantsPlayback, let target = confirmedTarget, let timeline = engine.timeline,
               target >= timeline.duration, engine.positionSeconds + 0.05 >= timeline.duration {
                handle(.ended)
            }
        }
        publish()
    }

    private func cancelTimelineSeek() {
        seekID = UUID()
        pendingSeek = nil
        seekTarget = nil
        seekTask?.cancel()
        seekTask = nil
    }

    public func pause() {
        guard !isShutDown else { return }
        transportIntent += 1
        wantsPlayback = false
        queueAutoplay = false
        engine.pause()
        if state.loadedVideo != nil { playback = .paused }
        capturePosition()
        enqueueSave()
        publish()
    }

    public func resume() async throws {
        guard !isShutDown else { throw ControllerFailure.shutDown }
        guard !needsUpdate else { throw ExtractorFailure.sourceNeedsUpdate }
        guard let loaded = state.loadedVideo else { throw PlaybackFailure.noLoadedVideo }
        queueAutoplay = true
        if selecting || seekTask != nil {
            transportIntent += 1
            wantsPlayback = true
            publish()
            return
        }
        if !engine.hasReadyItem { try await load(loaded.video, position: loaded.positionSeconds); return }
        let previous = playback
        transportIntent += 1
        let intent = transportIntent
        wantsPlayback = true
        playback = .buffering
        publish()
        do {
            if previous == .ended {
                endedPlaybackID = nil
                try await engine.replay()
            } else { try engine.resume() }
        } catch {
            if transportIntent == intent {
                playback = previous
                wantsPlayback = false
                errorMessage = message(error)
                publish()
            }
            throw error
        }
    }

    public func toggleFavorite(_ video: VideoSummary) throws {
        guard !isShutDown else { throw ControllerFailure.shutDown }
        try state.toggleFavorite(video)
        enqueueSave()
        publish()
    }

    /// Dispatches only validated commands on the same actor that owns playback.
    /// The app supplies its real panel action; a missing UI must not report success.
    public func execute(_ request: CommandRequest,
                        openSearch: @MainActor () throws -> Void,
                        openPlayer: @MainActor () throws -> Void = { throw CommandProtocolFailure.invalidArguments }) async throws -> CommandResponse {
        try request.validate()
        do {
            guard !isShutDown else { throw ControllerFailure.shutDown }
            switch request.command {
            case .status: break
            case .search: try openSearch()
            case .player: try openPlayer()
            case .previous, .next:
                let offset = request.command == .previous ? -1 : 1
                guard !selecting, canNavigate(offset) else {
                    throw CommandProtocolFailure.invalidPayload
                }
                if let index = playlistIndex, !playlistQueue.isEmpty {
                    try await runQueue(from: index + offset, step: offset, autoplay: wantsPlayback)
                } else if let video = neighbor(offset) {
                    try await load(video, position: 0, autoplay: wantsPlayback)
                }
            case .toggle:
                if wantsPlayback { pause() } else { try await resume() }
            case .replay:
                guard state.loadedVideo != nil else { throw PlaybackFailure.noLoadedVideo }
                guard playback == .ended else { throw CommandProtocolFailure.invalidPayload }
                try await resume()
            case .select, .favoriteToggle:
                // Commands carry identity only; use metadata already owned by Maro.
                let video = state.favorites.first { $0.id == request.videoID }
                    ?? session?.visibleResults.first { $0.id == request.videoID }
                    ?? (state.loadedVideo?.video.id == request.videoID ? state.loadedVideo?.video : nil)
                guard let video else { throw ExtractorFailure.videoUnavailable }
                if request.command == .select { try await select(video) }
                else { try toggleFavorite(video) }
            case .favoriteRemove:
                if let id = request.videoID { removeFavorite(id: id) }
            }
            return CommandResponse(id: request.id, snapshot: snapshot.commandResponseSnapshot())
        } catch {
            let code: CommandError.Code
            switch error {
            case ControllerFailure.shutDown: code = .serviceUnavailable
            case PlaybackFailure.noLoadedVideo: code = .noLoadedVideo
            case StateError.favoritesFull: code = .favoritesFull
            case ExtractorFailure.sourceNeedsUpdate: code = .sourceNeedsUpdate
            case PlaybackFailure.superseded, is CancellationError: code = .superseded
            case is CommandProtocolFailure: code = .invalidRequest
            case ExtractorFailure.dependencyMissing, ExtractorFailure.runtimeUnavailable: code = .serviceUnavailable
            default: code = .videoUnavailable
            }
            let explanation: String
            switch code {
            case .noLoadedVideo: explanation = "No video is loaded. Open search to choose one."
            case .favoritesFull: explanation = "Favorites are full. Remove one before adding another."
            case .serviceUnavailable: explanation = "Maro is unavailable or a required component is missing."
            case .superseded: explanation = "A newer action replaced this request."
            case .invalidRequest: explanation = "This action is not available in the current player state."
            default: explanation = message(error)
            }
            return CommandResponse(id: request.id, error: CommandError(code: code, message: explanation))
        }
    }

    public func removeFavorite(id: String) {
        guard !isShutDown else { return }
        state.removeFavorite(id: id)
        enqueueSave()
        publish()
    }

    public func flush() async {
        capturePosition()
        enqueueSave()
        await pendingSave?.value
    }

    public func shutdown() async {
        cancelTimelineSeek()
        if isShutDown { await pendingSave?.value; return }
        isShutDown = true
        queueID = UUID()
        queueTask?.cancel(); queueTask = nil
        sourceWarmup?.cancel()
        await sourceLifetime?.shutdown()
        metadataRequests.clear()
        artworkTask?.cancel()
        transportIntent += 1
        selectionID = UUID()
        searchID = UUID()
        selectionTask?.cancel()
        searchTask?.cancel()
        pageTask?.cancel(); pageTask = nil; loadingMore = false; loadMoreError = nil
        selectionTask = nil
        searchTask = nil
        selecting = false
        searching = false
        wantsPlayback = false
        engine.pause()
        capturePosition()
        engine.onEvent = nil
        engine.stop()
        if state.loadedVideo != nil { playback = .paused }
        enqueueSave()
        await pendingSave?.value
        publish()
    }

    public func warmUpSource() {
        guard !isShutDown, sourceWarmup == nil, let sourceLifetime else { return }
        sourceWarmup = Task { await sourceLifetime.warmUp() }
    }

    private func capturePosition() {
        guard seekTask == nil else { return }
        guard let loaded = state.loadedVideo, engine.loadedVideo?.id == loaded.video.id else { return }
        if let updated = try? LoadedVideo(video: loaded.video, positionSeconds: engine.positionSeconds) {
            state.loadedVideo = updated
        }
    }

    private func handle(_ event: PlaybackEvent) {
        guard !isShutDown, state.loadedVideo != nil else { return }
        switch event {
        case .timelineChanged: break
        case .rateChanged: break // Consumed by PlaybackEngine before delivery.
        case .started:
            if selecting && (playback == .paused || playback == .ended) {
                engine.pause()
            } else if wantsPlayback { playback = .playing } else { engine.pause() }
        case .ended:
            guard seekTask == nil else { return }
            if let id = engine.playbackID, endedPlaybackID == id { return }
            endedPlaybackID = engine.playbackID
            if !selecting, wantsPlayback, let index = playlistIndex, playlistQueue.indices.contains(index + 1) {
                advancePlaylist()
                playback = .buffering
                break
            }
            if !selecting { wantsPlayback = false }
            playback = .ended
            capturePosition()
            enqueueSave()
        case .position:
            guard seekTask == nil else { return }
            capturePosition()
            if ProcessInfo.processInfo.systemUptime - lastCheckpoint >= 5 { enqueueSave() }
        case .stalled:
            if wantsPlayback && playback != .paused && playback != .ended { playback = .buffering }
        case .accessRejected:
            if seekTask != nil { failTimelineSeek(); return }
            capturePosition()
            engine.stop()
            if !selecting, !needsUpdate, !recoveryAttempted, let loaded = state.loadedVideo {
                recoveryAttempted = true
                playback = wantsPlayback ? .buffering : .paused
                selecting = true
                let id = selectionID
                Task { [weak self] in
                    guard let self, self.selectionID == id, !self.isShutDown else { return }
                    // load owns error reporting and operation cancellation.
                    try? await self.load(loaded.video, position: loaded.positionSeconds, recovering: true)
                }
            } else {
                if advancePlaylist() {
                    playback = .buffering
                    errorMessage = "Skipping a playlist video after media access failed."
                    break
                }
                if !selecting { wantsPlayback = false }
                playback = .paused
                errorMessage = "Media access failed. Try again or choose another video."
            }
            enqueueSave()
        case .failed:
            if seekTask != nil { failTimelineSeek(); return }
            capturePosition()
            engine.stop()
            if !selecting, wantsPlayback, let index = playlistIndex, playlistQueue.indices.contains(index + 1) {
                errorMessage = "Skipping an unplayable playlist video."
                advancePlaylist()
                playback = .buffering
                break
            }
            if !selecting { wantsPlayback = false }
            playback = .paused
            errorMessage = "Playback failed. Try again or choose another video."
            enqueueSave()
        }
        publish()
    }

    private func disableSource() {
        cancelTimelineSeek()
        metadataRequests.clear()
        needsUpdate = true
        state.sourceDisabledBuild = sourceBuild
        searchID = UUID()
        searchTask?.cancel()
        pageTask?.cancel(); pageTask = nil; loadingMore = false; loadMoreError = nil
        searching = false
        searchError = ExtractorFailure.sourceNeedsUpdate.message
        selectionID = UUID()
        selectionTask?.cancel()
        selecting = false
        wantsPlayback = false
        engine.pause()
        if state.loadedVideo != nil { playback = .paused }
        errorMessage = ExtractorFailure.sourceNeedsUpdate.message
        capturePosition()
        enqueueSave()
        publish()
    }

    private func failTimelineSeek() {
        cancelTimelineSeek()
        wantsPlayback = false
        engine.pause()
        playback = .paused
        capturePosition()
        errorMessage = "Could not seek to that position. Try again."
        enqueueSave()
        publish()
    }

    private func enqueueSave() {
        saveRevision += 1
        let revision = saveRevision
        let document = state
        let previous = pendingSave
        lastCheckpoint = ProcessInfo.processInfo.systemUptime
        pendingSave = Task { [weak self, store] in
            await previous?.value
            do {
                try await store.save(document)
                if self?.saveRevision == revision { self?.persistenceError = nil }
            } catch {
                if self?.saveRevision == revision { self?.persistenceError = "Local changes could not be saved. Check available storage and permissions." }
            }
            self?.publish()
        }
    }

    private func message(_ error: any Error) -> String {
        if let error = error as? ExtractorFailure { return error.message }
        if let error = error as? AudioPreparationFailure {
            switch error {
            case .unsupportedCodec: return "This audio format is not supported by the player. Choose another video."
            case .incompatible: return "This audio could not pass the native playback check. Choose another video."
            case .timedOut: return "Audio preparation timed out. Try again or choose another video."
            case .mediaLoad: return "The audio stream could not be opened. Try again or choose another video."
            case .invalidTimeout: return "Audio preparation could not start."
            }
        }
        if error as? SourceFailure == .noCompatibleAudio {
            return "This video has no supported audio-only stream. Choose another video."
        }
        if error as? PlaybackFailure == .preparationTimedOut {
            return "Audio preparation timed out. Try again or choose another video."
        }
        if error is CancellationError { return "Operation cancelled." }
        return "This video or request could not be completed. Try another selection."
    }

    /// Derived files never enter StateDocument. Retry lost files on the next refresh.
    public func refreshArtwork() {
        guard !isShutDown, let artworkCache else { return }
        var videos = state.loadedVideo.map { [$0.video] } ?? []
        videos += state.favorites.filter { favorite in !videos.contains { $0.id == favorite.id } }
        videos += metadataArtworkVideos.filter { candidate in !videos.contains { $0.id == candidate.id } }
        let lostFile = artworkPaths.values.contains { !FileManager.default.fileExists(atPath: $0) }
        guard videos != artworkVideos || lostFile else { return }
        artworkVideos = videos
        artworkPaths = artworkPaths.filter { entry in videos.contains { $0.id == entry.key }
            && FileManager.default.fileExists(atPath: entry.value) }
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            for video in videos {
                guard !Task.isCancelled else { return }
                let file = await artworkCache.image(for: video)
                guard !Task.isCancelled, let self, !self.isShutDown else { return }
                if let file { self.artworkPaths[video.id] = file.path }
                self.onChange?()
            }
        }
    }

    private func publish() { refreshArtwork(); onChange?() }
}
