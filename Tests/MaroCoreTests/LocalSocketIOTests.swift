import Darwin
import Foundation
import Testing
@testable import MaroCore

private func connectedSockets() throws -> (Int32, Int32) {
    var sockets: [Int32] = [-1, -1]
    guard socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0 else { throw LocalSocketFailure.system(errno) }
    do {
        try sockets.forEach { try LocalSocketIO.configure($0); try LocalSocketIO.requireCurrentUser($0) }
        return (sockets[0], sockets[1])
    } catch {
        sockets.forEach { Darwin.close($0) }
        throw error
    }
}

@Test func localSocketsRoundTripFragmentedRequestAndLargeResponse() async throws {
    let (client, server) = try connectedSockets()
    defer { Darwin.close(client); Darwin.close(server) }
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    let request = try CommandWire.encode(CommandRequest(id: "42", command: .status))
    let response = Data((String(repeating: "x", count: 300_000) + "\n").utf8)
    let worker = Task.detached {
        let received = try LocalSocketIO.readLine(server, limit: CommandWire.maximumRequestBytes, deadline: deadline)
        #expect(try CommandWire.request(received).id == "42")
        try LocalSocketIO.write(response, to: server, deadline: deadline)
    }
    let received = try await Task.detached {
        for byte in request { try LocalSocketIO.write(Data([byte]), to: client, deadline: deadline) }
        return try LocalSocketIO.readLine(client, limit: CommandWire.maximumResponseBytes, deadline: deadline)
    }.value
    try await worker.value
    #expect(received == response)
    #expect(fcntl(client, F_GETFL) & O_NONBLOCK != 0)
    #expect(fcntl(client, F_GETFD) & FD_CLOEXEC != 0)
}

@Test func localSocketsBoundOversizedAndStalledPeers() async throws {
    try await Task.detached {
        let (client, server) = try connectedSockets()
        defer { Darwin.close(client); Darwin.close(server) }
        let deadline = ContinuousClock().now.advanced(by: .seconds(2))
        try LocalSocketIO.write(Data(repeating: 32, count: CommandWire.maximumRequestBytes), to: client, deadline: deadline)
        #expect(throws: CommandProtocolFailure.oversizedFrame) {
            try LocalSocketIO.readLine(server, limit: CommandWire.maximumRequestBytes, deadline: deadline)
        }
        #expect(throws: LocalSocketFailure.timedOut) {
            try LocalSocketIO.readLine(server, limit: 20, deadline: ContinuousClock().now.advanced(by: .milliseconds(50)))
        }
        #expect(throws: LocalSocketFailure.timedOut) {
            try LocalSocketIO.write(Data(repeating: 32, count: 1_000_000), to: client,
                deadline: ContinuousClock().now.advanced(by: .milliseconds(50)))
        }
    }.value
}

@Test func localSocketsRejectExtraFramesAndClosedPeersWithoutSignal() async throws {
    try await Task.detached {
        let (client, server) = try connectedSockets()
        defer { Darwin.close(server) }
        let deadline = ContinuousClock().now.advanced(by: .seconds(2))
        try LocalSocketIO.write(Data("{}\n{}\n".utf8), to: client, deadline: deadline)
        Darwin.close(client)
        #expect(throws: CommandProtocolFailure.invalidFrame) {
            try LocalSocketIO.readLine(server, limit: 100, deadline: deadline)
        }
        #expect(throws: LocalSocketFailure.closed) {
            try LocalSocketIO.readLine(server, limit: 100, deadline: deadline)
        }
        #expect(throws: (any Error).self) {
            try LocalSocketIO.write(Data("response\n".utf8), to: server, deadline: deadline)
        }
    }.value
}

@Test func localSocketWaitHonorsCancellation() async throws {
    let (client, server) = try connectedSockets()
    defer { Darwin.close(client); Darwin.close(server) }
    let worker = Task.detached {
        try LocalSocketIO.readLine(server, limit: 100, deadline: ContinuousClock().now.advanced(by: .seconds(10)))
    }
    worker.cancel()
    do { _ = try await worker.value; Issue.record("Expected cancellation") }
    catch { #expect(error is CancellationError) }
}
