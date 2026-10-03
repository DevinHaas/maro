import Darwin
import Foundation
import Testing
@testable import MaroCore

private func waitForService(_ directory: URL) async throws {
    let deadline = ContinuousClock().now.advanced(by: .seconds(3))
    while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("maro.sock").path) {
        guard ContinuousClock().now < deadline else { throw LocalSocketFailure.timedOut }
        try await Task.sleep(for: .milliseconds(5))
    }
}

@Test func invalidHandlerResponseLeavesOutcomeUnknown() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = Task {
        try await CommandService.run(directory: directory) { _ in
            CommandResponse(id: "wrong", error: CommandError(code: .superseded, message: "Wrong response"))
        }
    }
    defer { service.cancel() }
    try await waitForService(directory)
    do {
        _ = try await CommandClient.send(CommandRequest(command: .toggle), to: directory.appendingPathComponent("maro.sock"))
        Issue.record("Expected unknown outcome after invalid handler response")
    } catch { #expect(error as? CommandClientFailure == .outcomeUnknown) }
    service.cancel()
    do { try await service.value; Issue.record("Expected cancellation") }
    catch { #expect(error is CancellationError) }
}

@Test @MainActor func serviceDispatchesControllerCommandsAndShutsDownCleanly() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let video = try VideoSummary(id: "abcdefghijk", title: "Saved", creator: "Creator")
    let controller = try MaroController(loaded: StateLoadResult(document:
        StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 5)), preservedFile: nil, warning: nil),
        store: StateStore(file: directory.appendingPathComponent("state.json")), engine: PlaybackEngine(),
        search: { _ in [] }, prepare: { _, _ in throw ExtractorFailure.videoUnavailable })
    let service = Task {
        try await CommandService.run(directory: directory) { request in
            try await controller.execute(request, openSearch: {})
        }
    }
    defer { service.cancel() }
    try await waitForService(directory)
    let socket = directory.appendingPathComponent("maro.sock")
    let added = try await CommandClient.send(CommandRequest(command: .favoriteToggle, videoID: video.id), to: socket)
    #expect(added.snapshot?.favorites == [video])
    let status = try await CommandClient.send(CommandRequest(command: .status), to: socket)
    #expect(status.snapshot?.loadedVideo?.positionSeconds == 5)
    #expect(status.snapshot?.playback == .paused)
    service.cancel()
    do { try await service.value; Issue.record("Expected cancellation") }
    catch { #expect(error is CancellationError) }
    #expect(!FileManager.default.fileExists(atPath: socket.path))
    await controller.shutdown()
    #expect(try await StateStore(file: directory.appendingPathComponent("state.json")).load().document.favorites == [video])
}

@Test func serviceRejectsUnsupportedRequestAndKeepsOtherClientsResponsive() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = Task {
        try await CommandService.run(directory: directory) { request in
            CommandResponse(id: request.id, error: CommandError(code: .noLoadedVideo, message: "Empty"))
        }
    }
    defer { service.cancel() }
    try await waitForService(directory)
    let socket = directory.appendingPathComponent("maro.sock")
    let stalled = try LocalSocketListener.connect(to: socket, deadline: ContinuousClock().now.advanced(by: .seconds(2)))
    defer { Darwin.close(stalled) }
    let invalid = try await Task.detached {
        let deadline = ContinuousClock().now.advanced(by: .seconds(2))
        let fd = try LocalSocketListener.connect(to: socket, deadline: deadline)
        defer { Darwin.close(fd) }
        try LocalSocketIO.write(Data("{\"version\":2,\"id\":\"bad-version\",\"command\":\"status\"}\n".utf8), to: fd, deadline: deadline)
        return try CommandWire.response(LocalSocketIO.readLine(fd, limit: CommandWire.maximumResponseBytes, deadline: deadline),
            expectedID: "bad-version")
    }.value
    #expect(invalid.error?.code == .unsupportedVersion)
    let response = try await CommandClient.send(CommandRequest(command: .status), to: socket, timeout: .seconds(2))
    #expect(response.error?.code == .noLoadedVideo)
    service.cancel()
    do { try await service.value; Issue.record("Expected cancellation") }
    catch { #expect(error is CancellationError) }
    #expect(!FileManager.default.fileExists(atPath: socket.path))
}
