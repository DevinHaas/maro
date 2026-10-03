import Darwin
import Foundation

public enum ProcessFailure: Error, Equatable, Sendable {
    case invalidInvocation
    case system(Int32)
    case timedOut
    case outputLimit
}

public struct ProcessOutput: Sendable {
    public let stdout: Data
    public let stderr: Data
    public let exitCode: Int32
}

/// One process group per invocation also contains yt-dlp's JavaScript children.
/// A detached worker drains both nonblocking pipes; the UI actor never waits on I/O.
public enum ExtractorProcess {
    public static func run(executable: URL, arguments: [String], timeout: TimeInterval = 45,
                           stdoutLimit: Int = YouTubeSource.maximumOutputBytes,
                           stderrLimit: Int = 65_536) async throws -> ProcessOutput {
        let worker = Task.detached {
            try execute(executable: executable, arguments: arguments, timeout: timeout,
                        stdoutLimit: stdoutLimit, stderrLimit: stderrLimit)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func execute(executable: URL, arguments: [String], timeout: TimeInterval,
                                stdoutLimit: Int, stderrLimit: Int) throws -> ProcessOutput {
        guard executable.isFileURL, executable.path.hasPrefix("/"),
              !([executable.path] + arguments).contains(where: { $0.utf8.contains(0) }),
              timeout.isFinite, timeout > 0, timeout <= 300,
              stdoutLimit > 0, stderrLimit > 0 else { throw ProcessFailure.invalidInvocation }
        try Task.checkCancellation()
        var outputPipe: [Int32] = [-1, -1]
        var errorPipe: [Int32] = [-1, -1]
        defer {
            for fd in outputPipe + errorPipe where fd >= 0 { close(fd) }
        }
        guard pipe(&outputPipe) == 0, pipe(&errorPipe) == 0 else { throw ProcessFailure.system(errno) }
        for fd in outputPipe + errorPipe {
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { throw ProcessFailure.system(errno) }
        }
        for fd in [outputPipe[0], errorPipe[0]] {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { throw ProcessFailure.system(errno) }
        }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        try check(posix_spawn_file_actions_init(&actions))
        defer { posix_spawn_file_actions_destroy(&actions) }
        try check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }
        try check(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)))
        try check(posix_spawnattr_setpgroup(&attributes, 0))
        try check(posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0))
        try check(posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDOUT_FILENO))
        try check(posix_spawn_file_actions_adddup2(&actions, errorPipe[1], STDERR_FILENO))
        for fd in outputPipe + errorPipe {
            try check(posix_spawn_file_actions_addclose(&actions, fd))
        }
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        // Do not pass caller secrets, proxy configuration or runtime injection flags.
        let environmentStrings: [String] = ["PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LANG=en_US.UTF-8",
            "USER=\(NSUserName())",
            "HOME=\(FileManager.default.homeDirectoryForCurrentUser.path)",
            "TMPDIR=\(FileManager.default.temporaryDirectory.path)"]
        let environment = environmentStrings.map { strdup($0) } + [nil]
        defer {
            argv.forEach { free($0) }
            environment.forEach { free($0) }
        }
        guard argv.dropLast().allSatisfy({ $0 != nil }), environment.dropLast().allSatisfy({ $0 != nil }) else {
            throw ProcessFailure.system(ENOMEM)
        }
        var pid: pid_t = 0
        try check(posix_spawn(&pid, executable.path, &actions, &attributes, argv, environment))
        var reaped = false
        defer {
            // Kill descendants too, including on success if a child retained a pipe.
            kill(-pid, SIGKILL)
            if !reaped {
                while waitpid(pid, nil, 0) == -1 && errno == EINTR {}
            }
        }
        close(outputPipe[1]); outputPipe[1] = -1
        close(errorPipe[1]); errorPipe[1] = -1
        let started = ProcessInfo.processInfo.systemUptime
        var stdout = Data()
        var stderr = Data()
        var status: Int32 = 0
        while true {
            try Task.checkCancellation()
            if ProcessInfo.processInfo.systemUptime - started >= timeout { throw ProcessFailure.timedOut }
            try drain(outputPipe[0], into: &stdout, limit: stdoutLimit)
            try drain(errorPipe[0], into: &stderr, limit: stderrLimit)
            let result = waitpid(pid, &status, WNOHANG)
            if result == pid {
                reaped = true
                kill(-pid, SIGKILL)
                try drain(outputPipe[0], into: &stdout, limit: stdoutLimit)
                try drain(errorPipe[0], into: &stderr, limit: stderrLimit)
                let signal = status & 0x7f
                return ProcessOutput(stdout: stdout, stderr: stderr,
                                     exitCode: signal == 0 ? (status >> 8) & 0xff : 128 + signal)
            }
            if result == -1 && errno != EINTR { throw ProcessFailure.system(errno) }
            // ponytail: one worker polls at 100 Hz; switch to DispatchSource for sustained concurrency.
            usleep(10_000)
        }
    }

    private static func drain(_ fd: Int32, into data: inout Data, limit: Int) throws {
        var buffer = [UInt8](repeating: 0, count: 8192)
        // Finite per-pipe work preserves timeout/cancellation fairness under a flood.
        for _ in 0..<16 {
            let count = read(fd, &buffer, buffer.count)
            if count > 0 {
                guard count <= limit - data.count else { throw ProcessFailure.outputLimit }
                data.append(contentsOf: buffer.prefix(count))
            } else if count == 0 || errno == EAGAIN { return }
            else if errno != EINTR { throw ProcessFailure.system(errno) }
        }
    }

    private static func check(_ result: Int32) throws {
        guard result == 0 else { throw ProcessFailure.system(result) }
    }
}
