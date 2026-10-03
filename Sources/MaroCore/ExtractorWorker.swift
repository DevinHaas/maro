import Darwin
import Foundation

/// One interpreter per client/app lifetime. Only the active detached task touches its pipes.
actor ExtractorWorker {
    private struct Job {
        let id: UUID
        let operation: String
        let value: String
        var waiters: [UUID: CheckedContinuation<Data, Error>]
    }
    private let executable: URL
    private let arguments: [String]
    private let timeout: TimeInterval
    private var connection: WorkerConnection?
    private var jobs: [UUID: Job] = [:]
    private var queue: [UUID] = []
    private var active: UUID?
    private var task: Task<Void, Never>?
    private var stopped = false
    private var failures: [TimeInterval] = []

    init(executable: URL, arguments: [String], timeout: TimeInterval = 45) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
    }

    func request(_ operation: String, value: String = "") async throws -> Data {
        let waiter = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard !stopped else { continuation.resume(throwing: CancellationError()); return }
                if let id = jobs.first(where: { $0.value.operation == operation && $0.value.value == value })?.key {
                    jobs[id]?.waiters[waiter] = continuation
                    return
                }
                guard jobs.count < 8 else { continuation.resume(throwing: ExtractorFailure.failed); return }
                let id = UUID()
                jobs[id] = Job(id: id, operation: operation, value: value, waiters: [waiter: continuation])
                if operation == "resolve" {
                    queue.insert(id, at: 0)
                    // A discarded search must not hold an explicit selection behind its network deadline.
                    if let active, jobs[active]?.operation == "search" {
                        cancelJob(active)
                    }
                } else { queue.append(id) }
                startNext()
            }
        } onCancel: { Task { await self.cancel(waiter) } }
    }

    func shutdown() async {
        stopped = true
        for id in Array(jobs.keys) { cancelJob(id) }
        await task?.value
        connection?.close()
        connection = nil
    }

    private func cancel(_ waiter: UUID) {
        guard let id = jobs.first(where: { $0.value.waiters[waiter] != nil })?.key else { return }
        jobs[id]?.waiters.removeValue(forKey: waiter)?.resume(throwing: CancellationError())
        if jobs[id]?.waiters.isEmpty == true { cancelJob(id) }
    }

    private func cancelJob(_ id: UUID) {
        jobs.removeValue(forKey: id)?.waiters.values.forEach { $0.resume(throwing: CancellationError()) }
        queue.removeAll { $0 == id }
        if active == id { task?.cancel() }
    }

    private func startNext() {
        guard !stopped, active == nil, !queue.isEmpty else { return }
        let id = queue.removeFirst()
        guard let job = jobs[id] else { startNext(); return }
        active = id
        failures.removeAll { ProcessInfo.processInfo.systemUptime - $0 > 60 }
        let blocked = failures.count >= 3
        let existing = connection
        let executable = executable, arguments = arguments, timeout = timeout
        task = Task.detached { [self] in
            var current = existing
            let result: Result<Data, Error>
            var broken = false
            do {
                try Task.checkCancellation()
                guard !blocked else { throw ExtractorFailure.failed }
                if current == nil { current = try WorkerConnection(executable: executable, arguments: arguments) }
                result = .success(try current!.exchange(id: id.uuidString, operation: job.operation,
                                                       value: job.value, timeout: timeout))
            } catch {
                // Extraction errors are protocol replies, so the healthy interpreter survives them.
                broken = !(error is CancellationError) && !blocked
                current?.close()
                current = nil
                result = .failure(error)
            }
            await finish(id, result: result, connection: current, broken: broken)
        }
    }

    private func finish(_ id: UUID, result: Result<Data, Error>, connection: WorkerConnection?, broken: Bool) {
        self.connection = connection
        if broken { failures.append(ProcessInfo.processInfo.systemUptime) }
        jobs.removeValue(forKey: id)?.waiters.values.forEach { $0.resume(with: result) }
        active = nil
        task = nil
        startNext()
    }
}

/// Private process group and nonblocking pipes; accessed by one detached request at a time.
private final class WorkerConnection: @unchecked Sendable {
    private var pid: pid_t = 0
    private var input: Int32 = -1
    private var output: Int32 = -1
    private var buffered = Data()
    private var ready = false

    init(executable: URL, arguments: [String]) throws {
        guard executable.isFileURL, executable.path.hasPrefix("/"),
              !([executable.path] + arguments).contains(where: { $0.utf8.contains(0) }),
              FileManager.default.isExecutableFile(atPath: executable.path)
        else { throw ExtractorFailure.dependencyMissing }
        var incoming: [Int32] = [-1, -1], outgoing: [Int32] = [-1, -1]
        defer { for fd in incoming + outgoing where fd >= 0 { Darwin.close(fd) } }
        guard pipe(&incoming) == 0, pipe(&outgoing) == 0 else { throw ProcessFailure.system(errno) }
        for fd in incoming + outgoing {
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { throw ProcessFailure.system(errno) }
        }
        for fd in [incoming[1], outgoing[0]] {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { throw ProcessFailure.system(errno) }
        }
        guard fcntl(incoming[1], F_SETNOSIGPIPE, 1) == 0 else { throw ProcessFailure.system(errno) }
        var actions: posix_spawn_file_actions_t?, attributes: posix_spawnattr_t?
        func check(_ code: Int32) throws { if code != 0 { throw ProcessFailure.system(code) } }
        try check(posix_spawn_file_actions_init(&actions))
        defer { posix_spawn_file_actions_destroy(&actions) }
        try check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }
        try check(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)))
        try check(posix_spawnattr_setpgroup(&attributes, 0))
        try check(posix_spawn_file_actions_adddup2(&actions, incoming[0], STDIN_FILENO))
        try check(posix_spawn_file_actions_adddup2(&actions, outgoing[1], STDOUT_FILENO))
        try check(posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0))
        for fd in incoming + outgoing { try check(posix_spawn_file_actions_addclose(&actions, fd)) }
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let environment: [String] = ["PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LANG=en_US.UTF-8",
                   "USER=\(NSUserName())", "HOME=\(FileManager.default.homeDirectoryForCurrentUser.path)",
                   "TMPDIR=\(FileManager.default.temporaryDirectory.path)"]
        let env = environment.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) }; env.forEach { free($0) } }
        guard argv.dropLast().allSatisfy({ $0 != nil }), env.dropLast().allSatisfy({ $0 != nil }) else {
            throw ProcessFailure.system(ENOMEM)
        }
        try check(posix_spawn(&pid, executable.path, &actions, &attributes, argv, env))
        input = incoming[1]; incoming[1] = -1
        output = outgoing[0]; outgoing[0] = -1
    }

    deinit { close() }

    func close() {
        guard pid > 0 else { return }
        kill(-pid, SIGKILL)
        while waitpid(pid, nil, 0) == -1 && errno == EINTR {}
        pid = 0
        if input >= 0 { Darwin.close(input); input = -1 }
        if output >= 0 { Darwin.close(output); output = -1 }
        buffered.removeAll()
    }

    func exchange(id: String, operation: String, value: String, timeout: TimeInterval) throws -> Data {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        if !ready {
            let greeting = try JSONSerialization.jsonObject(with: line(deadline: min(deadline, ProcessInfo.processInfo.systemUptime + 15))) as? [String: Int]
            guard greeting == ["ready": 1] else { throw SourceFailure.malformedResponse }
            ready = true
        }
        var request = try JSONSerialization.data(withJSONObject: ["id": id, "operation": operation, "value": value])
        request.append(10)
        guard request.count <= 4096 else { throw ProcessFailure.invalidInvocation }
        var sent = 0
        while sent < request.count {
            try check(deadline)
            let count = request.withUnsafeBytes { Darwin.write(input, $0.baseAddress!.advanced(by: sent), request.count - sent) }
            if count > 0 { sent += count }
            else if errno != EAGAIN && errno != EINTR { throw ProcessFailure.system(errno) }
            else { usleep(10_000) }
        }
        let response = try line(deadline: deadline)
        guard let envelope = try JSONSerialization.jsonObject(with: response) as? [String: Any],
              envelope["id"] as? String == id else { throw SourceFailure.malformedResponse }
        // Keep the bounded envelope intact; the client handles safe errors outside process recovery.
        return response
    }

    private func check(_ deadline: TimeInterval) throws {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.systemUptime >= deadline { throw ProcessFailure.timedOut }
    }

    private func line(deadline: TimeInterval) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            try check(deadline)
            if let end = buffered.firstIndex(of: 10) {
                let result = Data(buffered[..<end])
                buffered.removeSubrange(...end)
                return result
            }
            let count = read(output, &bytes, bytes.count)
            if count > 0 {
                guard buffered.count + count <= YouTubeSource.maximumOutputBytes + 1 else { throw ProcessFailure.outputLimit }
                buffered.append(contentsOf: bytes.prefix(count))
            } else if count == 0 { throw ExtractorFailure.failed }
            else if errno != EAGAIN && errno != EINTR { throw ProcessFailure.system(errno) }
            else { usleep(10_000) }
        }
    }
}
