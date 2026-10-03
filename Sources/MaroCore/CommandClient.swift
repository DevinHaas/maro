import Darwin
import Foundation

public enum CommandClientFailure: Error, Equatable, Sendable {
    /// Only a missing/refused connection is eligible for future launch recovery.
    case unavailable
    /// Bytes may have reached the service. Never automatically replay this action.
    case outcomeUnknown
    case invalidTimeout
}

public enum CommandClient {
    public static func sendRecovering(_ request: CommandRequest, to socketURL: URL = defaultSocketURL,
                                      startupTimeout: Duration = .seconds(4),
                                      launch: @Sendable () async throws -> Void) async throws -> CommandResponse {
        guard startupTimeout > .zero, startupTimeout <= .seconds(10) else { throw CommandClientFailure.invalidTimeout }
        do { return try await send(request, to: socketURL) }
        catch CommandClientFailure.unavailable {
            try Task.checkCancellation()
            try await launch()
            let probe = Task.detached {
                let clock = ContinuousClock()
                let deadline = clock.now.advanced(by: startupTimeout)
                while clock.now < deadline {
                    try Task.checkCancellation()
                    do {
                        let fd = try LocalSocketListener.connect(to: socketURL, deadline: deadline)
                        Darwin.close(fd)
                        return
                    } catch LocalSocketFailure.system(let code) where code == ENOENT || code == ECONNREFUSED {
                        try await Task.sleep(for: .milliseconds(50))
                    }
                }
                throw CommandClientFailure.unavailable
            }
            try await withTaskCancellationHandler { try await probe.value } onCancel: { probe.cancel() }
            // Exactly one post-launch command attempt. Probes above send no bytes.
            return try await send(request, to: socketURL)
        }
    }

    public static var defaultSocketURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Maro/maro.sock")
    }

    public static func send(_ request: CommandRequest, to socketURL: URL = defaultSocketURL,
                            timeout: Duration = .seconds(90)) async throws -> CommandResponse {
        guard timeout > .zero, timeout <= .seconds(120) else { throw CommandClientFailure.invalidTimeout }
        let frame = try CommandWire.encode(request)
        let task = Task.detached {
            try Task.checkCancellation()
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: timeout)
            let fd: Int32
            do {
                fd = try LocalSocketListener.connect(to: socketURL,
                    deadline: min(deadline, clock.now.advanced(by: .seconds(2))))
            } catch LocalSocketFailure.system(let code) where code == ENOENT || code == ECONNREFUSED {
                throw CommandClientFailure.unavailable
            }
            defer { Darwin.close(fd) }
            do {
                try LocalSocketIO.write(frame, to: fd, deadline: deadline)
                let response = try LocalSocketIO.readLine(fd,
                    limit: CommandWire.maximumResponseBytes, deadline: deadline)
                return try CommandWire.response(response, expectedID: request.id)
            } catch {
                // Even cancellation or a malformed reply cannot prove nonexecution.
                throw CommandClientFailure.outcomeUnknown
            }
        }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}
