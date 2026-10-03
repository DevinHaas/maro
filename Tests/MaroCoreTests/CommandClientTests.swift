import Darwin
import Foundation
import Testing
@testable import MaroCore

@Test func commandClientReceivesTypedResponseOverRealSocket() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let listener = try LocalSocketListener(directory: directory)
    let server = Task.detached {
        let deadline = ContinuousClock().now.advanced(by: .seconds(3))
        let peer = try listener.accept(deadline: deadline)
        defer { Darwin.close(peer) }
        let request = try CommandWire.request(LocalSocketIO.readLine(peer,
            limit: CommandWire.maximumRequestBytes, deadline: deadline))
        #expect(request.command == .toggle)
        try LocalSocketIO.write(CommandWire.encode(CommandResponse(id: request.id,
            error: CommandError(code: .noLoadedVideo, message: "No video loaded"))), to: peer, deadline: deadline)
    }
    let response = try await CommandClient.send(CommandRequest(id: "client-42", command: .toggle),
        to: directory.appendingPathComponent("maro.sock"), timeout: .seconds(3))
    try await server.value
    #expect(response.id == "client-42")
    #expect(response.error?.code == .noLoadedVideo)
}

@Test(arguments: ["mismatch", "close", "stall"])
func commandClientNeverRetriesAnAmbiguousAction(_ mode: String) async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let listener = try LocalSocketListener(directory: directory)
    let server = Task.detached {
        let deadline = ContinuousClock().now.advanced(by: .seconds(3))
        let peer = try listener.accept(deadline: deadline)
        defer { Darwin.close(peer) }
        _ = try CommandWire.request(LocalSocketIO.readLine(peer,
            limit: CommandWire.maximumRequestBytes, deadline: deadline))
        if mode == "mismatch" {
            try LocalSocketIO.write(CommandWire.encode(CommandResponse(id: "wrong-id",
                error: CommandError(code: .superseded, message: "Wrong request"))), to: peer, deadline: deadline)
        } else if mode == "stall" { try await Task.sleep(for: .milliseconds(250)) }
    }
    do {
        _ = try await CommandClient.send(CommandRequest(command: .toggle),
            to: directory.appendingPathComponent("maro.sock"), timeout: .milliseconds(150))
        Issue.record("Expected unknown outcome")
    } catch { #expect(error as? CommandClientFailure == .outcomeUnknown) }
    try await server.value
    // A retry would leave another connection queued, even after its client closed.
    #expect(throws: LocalSocketFailure.timedOut) {
        try listener.accept(deadline: ContinuousClock().now.advanced(by: .milliseconds(30)))
    }
}

@Test func commandClientDistinguishesMissingServerAndRejectsInvalidBudget() async throws {
    let absent = URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)/maro.sock")
    let request = try CommandRequest(command: .status)
    do { _ = try await CommandClient.send(request, to: absent); Issue.record("Expected unavailable") }
    catch { #expect(error as? CommandClientFailure == .unavailable) }
    do { _ = try await CommandClient.send(request, to: absent, timeout: .zero); Issue.record("Expected invalid timeout") }
    catch { #expect(error as? CommandClientFailure == .invalidTimeout) }
}
