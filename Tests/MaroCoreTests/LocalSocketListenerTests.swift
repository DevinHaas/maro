import Darwin
import Foundation
import Testing
@testable import MaroCore

private func socketDirectory() -> URL {
    URL(fileURLWithPath: "/private/tmp/maro-\(UUID().uuidString)")
}

@Test func filesystemSocketRoundTripAndDuplicateInstanceProtection() async throws {
    let directory = socketDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let socket = directory.appendingPathComponent("maro.sock")
    do {
        let listener = try LocalSocketListener(directory: directory)
        #expect(throws: LocalSocketFailure.alreadyRunning) { try LocalSocketListener(directory: directory) }
        let deadline = ContinuousClock().now.advanced(by: .seconds(3))
        let worker = Task.detached {
            let peer = try listener.accept(deadline: deadline)
            defer { Darwin.close(peer) }
            let request = try CommandWire.request(LocalSocketIO.readLine(peer,
                limit: CommandWire.maximumRequestBytes, deadline: deadline))
            let response = CommandResponse(id: request.id,
                error: CommandError(code: .noLoadedVideo, message: "No video loaded"))
            try LocalSocketIO.write(CommandWire.encode(response), to: peer, deadline: deadline)
        }
        let response = try await Task.detached {
            let client = try LocalSocketListener.connect(to: socket, deadline: deadline)
            defer { Darwin.close(client) }
            try LocalSocketIO.write(CommandWire.encode(CommandRequest(id: "42", command: .toggle)),
                to: client, deadline: deadline)
            return try CommandWire.response(LocalSocketIO.readLine(client,
                limit: CommandWire.maximumResponseBytes, deadline: deadline), expectedID: "42")
        }.value
        try await worker.value
        #expect(response.error?.code == .noLoadedVideo)
        let mode = try FileManager.default.attributesOfItem(atPath: socket.path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
    }
    #expect(!FileManager.default.fileExists(atPath: socket.path))
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("maro.lock").path))
    #expect(throws: LocalSocketFailure.system(ENOENT)) {
        try LocalSocketListener.connect(to: socket, deadline: ContinuousClock().now.advanced(by: .seconds(1)))
    }
}

@Test func socketCleanupPreservesReplacementAndRejectsUnsafeFiles() throws {
    let directory = socketDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("maro.sock")
    do {
        let listener = try LocalSocketListener(directory: directory)
        try FileManager.default.removeItem(at: path)
        try Data("preserve".utf8).write(to: path)
        withExtendedLifetime(listener) {}
    }
    #expect(try Data(contentsOf: path) == Data("preserve".utf8))
    #expect(throws: LocalSocketFailure.unsafePath) { try LocalSocketListener(directory: directory) }
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createSymbolicLink(at: path, withDestinationURL: directory.appendingPathComponent("maro.lock"))
    #expect(throws: LocalSocketFailure.unsafePath) { try LocalSocketListener(directory: directory) }
    try FileManager.default.removeItem(at: path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
    #expect(throws: LocalSocketFailure.unsafePath) { try LocalSocketListener(directory: directory) }
}

@Test func staleSocketIsRecoveredButUncoordinatedLiveSocketIsPreserved() throws {
    let directory = socketDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700])
    let path = directory.appendingPathComponent("maro.sock")
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.path.utf8)) }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    try #require(fd >= 0)
    try LocalSocketIO.configure(fd)
    let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard result == 0 else { Darwin.close(fd); throw LocalSocketFailure.system(errno) }
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    #expect(listen(fd, 2) == 0)
    #expect(throws: LocalSocketFailure.alreadyRunning) { try LocalSocketListener(directory: directory) }
    // Drain the probe connection before simulating a fully closed stale server.
    // Keep the stale fixture independent of the earlier live-probe connection.
    let probe = Darwin.accept(fd, nil, nil)
    if probe >= 0 { Darwin.close(probe) }
    Darwin.close(fd)
    do {
        let recovered = try LocalSocketListener(directory: directory)
        #expect(FileManager.default.fileExists(atPath: path.path))
        withExtendedLifetime(recovered) {}
    }
    #expect(!FileManager.default.fileExists(atPath: path.path))
}
