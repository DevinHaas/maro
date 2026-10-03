import AppKit
import Darwin
import MaroCore

@main
struct MaroApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MaroController?
    private var searchWindow: SearchWindow?
    private var playerWindow: PlayerWindow?
    private var barNotifier: BarNotifier?
    private var service: Task<Void, Never>?
    private var signals: [DispatchSourceSignal] = []
    private var stopping = false
    private var stopped = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApplication.shared.terminate(nil) }
            source.resume()
            signals.append(source)
        }
        service = Task {
            do {
                let directory = try Self.location("MARO_DATA_DIRECTORY",
                    fallback: CommandClient.defaultSocketURL.deletingLastPathComponent())
                try await CommandService.run(directory: directory,
                    prepare: { try await self.prepareController(directory: directory) },
                    finish: { await self.finishController() },
                    handle: { request in try await self.handle(request) })
            } catch is CancellationError { }
            catch {
                if !stopping {
                    let message = error as? LocalSocketFailure == .alreadyRunning
                        ? "Maro is already running."
                        : "Maro could not start its local service. Check data-folder permissions and configuration."
                    FileHandle.standardError.write(Data((message + "\n").utf8))
                    // Finish this task before termination waits for service.value.
                    DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
                }
            }
        }
    }

    private func prepareController(directory: URL) async throws {
        try Task.checkCancellation()
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let extractor = try Self.location("MARO_EXTRACTOR", fallback: resources.appendingPathComponent("yt-dlp_macos"))
        let node = try Self.location("MARO_NODE", fallback: resources.appendingPathComponent("node"))
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev-1"
        let cacheDirectory = directory.standardizedFileURL != CommandClient.defaultSocketURL.deletingLastPathComponent().standardizedFileURL
            ? directory.appendingPathComponent("Artwork")
            : FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Maro/thumbnails")
        controller = try await MaroController.open(store: StateStore(file: directory.appendingPathComponent("state.json")),
            source: YouTubeClient(executable: extractor, nodeExecutable: node), engine: PlaybackEngine(),
            sourceBuild: "maro-\(build)/yt-dlp-2026.08.19", artworkCache: ArtworkCache(directory: cacheDirectory))
        try Task.checkCancellation()
        if let controller {
            let defaultBar = ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"]
                .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/sketchybar"
            barNotifier = BarNotifier(executable: try Self.location("MARO_SKETCHYBAR", fallback: URL(fileURLWithPath: defaultBar)))
            searchWindow = SearchWindow(controller: controller, cacheDirectory: cacheDirectory)
            playerWindow = PlayerWindow(controller: controller, openSearch: { [weak self] in
                self?.controller?.warmUpSource()
                self?.searchWindow?.present()
            }, addToPlaylist: { [weak self] video in
                self?.searchWindow?.offerAdd(video)
            })
            controller.onChange = { [weak self, weak controller] in
                self?.searchWindow?.render()
                self?.playerWindow?.render()
                if let controller { self?.barNotifier?.update(controller.snapshot) }
            }
            barNotifier?.update(controller.snapshot)
        }
    }

    private func finishController() async {
        controller?.onChange = nil
        await barNotifier?.stop()
        await controller?.shutdown()
    }

    private func handle(_ request: CommandRequest) async throws -> CommandResponse {
        guard let controller, !stopping else {
            return CommandResponse(id: request.id, error: CommandError(code: .serviceUnavailable, message: "Maro is starting or stopping."))
        }
        controller.refreshArtwork()
        return try await controller.execute(request,
            openSearch: { controller.warmUpSource(); self.searchWindow?.present() },
            openPlayer: { controller.warmUpSource(); self.playerWindow?.toggle() })
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if stopped { return .terminateNow }
        guard !stopping else { return .terminateCancel }
        stopping = true
        service?.cancel()
        Task {
            await service?.value
            signals.forEach { $0.cancel() }
            stopped = true
            sender.terminate(nil)
        }
        // Keep the normal run loop active while Swift tasks flush state. AppKit's
        // deferred-termination loop did not service these main-actor tasks.
        return .terminateCancel
    }

    private static func location(_ name: String, fallback: URL) throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[name] else { return fallback }
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { throw LocalSocketFailure.unsafePath }
        return URL(fileURLWithPath: path)
    }
}
