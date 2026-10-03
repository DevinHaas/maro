import Darwin
import Foundation

public enum CommandService {
    /// Runs until cancelled. The app's handler must propagate cancellation into
    /// long operations. Await this function before releasing controller state.
    public static func run(directory: URL,
                           prepare: @escaping @Sendable () async throws -> Void = {},
                           finish: @escaping @Sendable () async -> Void = {},
                           handle: @escaping @Sendable (CommandRequest) async throws -> CommandResponse) async throws {
        let worker = Task.detached {
            let listener = try LocalSocketListener(directory: directory)
            defer { withExtendedLifetime(listener) {} }
            do {
            try await prepare()
            try await withThrowingTaskGroup(of: Void.self) { group in
                var pending = 0
                while true {
                    try Task.checkCancellation()
                    // Bound both open descriptors and retained completed tasks.
                    if pending == 8 { try await group.next(); pending -= 1 }
                    let peer: Int32
                    do {
                        peer = try listener.accept(deadline: ContinuousClock().now.advanced(by: .seconds(1)))
                    } catch LocalSocketFailure.timedOut { continue }
                    catch LocalSocketFailure.unauthorizedPeer { continue }
                    pending += 1
                    group.addTask {
                        defer { Darwin.close(peer) }
                        do {
                            let frame = try LocalSocketIO.readLine(peer, limit: CommandWire.maximumRequestBytes,
                                deadline: ContinuousClock().now.advanced(by: .seconds(3)))
                            try Task.checkCancellation()
                            let response: CommandResponse
                            switch Result(catching: { try CommandWire.request(frame) }) {
                            case .success(let request):
                                response = try await handle(request)
                                try response.validate(expectedID: request.id)
                            case .failure(let failure):
                                response = invalidResponse(frame,
                                    failure: failure as? CommandProtocolFailure ?? .malformedJSON)
                            }
                            try Task.checkCancellation()
                            try LocalSocketIO.write(CommandWire.encode(response), to: peer,
                                deadline: ContinuousClock().now.advanced(by: .seconds(3)))
                        } catch {
                            // Per-connection failure closes that connection. Never
                            // replay an action or leak raw source errors to clients.
                        }
                    }
                }
            }
            } catch {
                // Keep the exclusive listener lock until durable state is flushed.
                await finish()
                throw error
            }
        }
        try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private static func invalidResponse(_ frame: Data, failure: CommandProtocolFailure) -> CommandResponse {
        struct Correlation: Decodable { let id: String }
        let candidate = (try? JSONDecoder().decode(Correlation.self, from: frame))?.id
        let id = candidate.flatMap { CommandRequest.validID($0) ? $0 : nil } ?? "invalid"
        let error = CommandError(code: failure == .unsupportedVersion ? .unsupportedVersion : .invalidRequest,
            message: failure == .unsupportedVersion ? "Unsupported command protocol version." : "Invalid command request.")
        return CommandResponse(id: id, error: error)
    }
}
