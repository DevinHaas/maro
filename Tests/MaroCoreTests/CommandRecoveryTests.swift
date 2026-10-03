import Foundation
import Testing
@testable import MaroCore

private actor RecoveryHarness {
    let directory: URL
    var launches = 0
    var requests = 0
    var service: Task<Void, Error>?
    init(_ directory: URL) { self.directory = directory }
    func launch(start: Bool, wrongID: Bool = false) {
        launches += 1
        guard start else { return }
        service = Task {
            try await CommandService.run(directory: directory) { request in
                await self.reply(request, wrongID: wrongID)
            }
        }
    }
    func reply(_ request: CommandRequest, wrongID: Bool) -> CommandResponse {
        requests += 1
        return CommandResponse(id: wrongID ? "wrong" : request.id,
            error: CommandError(code: .noLoadedVideo, message: "Empty"))
    }
    func stop() async { service?.cancel(); _ = try? await service?.value; service = nil }
}

@Test func recoveryLaunchesOnceAndSendsOnlyOneCommand() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let harness = RecoveryHarness(directory)
    let response = try await CommandClient.sendRecovering(CommandRequest(command: .toggle),
        to: directory.appendingPathComponent("maro.sock")) { await harness.launch(start: true) }
    #expect(response.error?.code == .noLoadedVideo)
    #expect(await harness.launches == 1)
    #expect(await harness.requests == 1)
    await harness.stop()
}

@Test func recoveryStopsAtStartupDeadline() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    let harness = RecoveryHarness(directory)
    do {
        _ = try await CommandClient.sendRecovering(CommandRequest(command: .status),
            to: directory.appendingPathComponent("maro.sock"), startupTimeout: .milliseconds(100)) {
                await harness.launch(start: false)
            }
        Issue.record("Expected unavailable service")
    } catch { #expect(error as? CommandClientFailure == .unavailable) }
    #expect(await harness.launches == 1)
    #expect(await harness.requests == 0)
}

@Test func recoveryDoesNotLaunchAgainAfterAmbiguousReply() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let harness = RecoveryHarness(directory)
    do {
        _ = try await CommandClient.sendRecovering(CommandRequest(command: .toggle),
            to: directory.appendingPathComponent("maro.sock")) {
                await harness.launch(start: true, wrongID: true)
            }
        Issue.record("Expected unknown outcome")
    } catch { #expect(error as? CommandClientFailure == .outcomeUnknown) }
    #expect(await harness.launches == 1)
    #expect(await harness.requests == 1)
    await harness.stop()
}
