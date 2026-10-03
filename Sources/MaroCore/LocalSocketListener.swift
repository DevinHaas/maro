import Darwin
import Foundation

/// Immutable descriptor ownership. Workers retain the listener until they finish;
/// releasing the last reference removes only the socket inode this instance bound.
final class LocalSocketListener: @unchecked Sendable {
    let descriptor: Int32
    private let directory: Int32
    private let lock: Int32
    private let inode: ino_t
    private let device: dev_t
    private static let name = "maro.sock"

    init(directory url: URL) throws {
        guard url.isFileURL else { throw LocalSocketFailure.unsafePath }
        let socketURL = url.appendingPathComponent(Self.name)
        _ = try Self.address(socketURL)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let dir = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard dir >= 0 else { throw LocalSocketFailure.system(errno) }
        var lockFD: Int32 = -1
        var socketFD: Int32 = -1
        var bound: stat?
        var committed = false
        defer {
            if !committed {
                if let bound { Self.removeOwnedSocket(directory: dir, inode: bound.st_ino, device: bound.st_dev) }
                if socketFD >= 0 { Darwin.close(socketFD) }
                if lockFD >= 0 { Darwin.close(lockFD) }
                Darwin.close(dir)
            }
        }
        var info = stat()
        guard fstat(dir, &info) == 0 else { throw LocalSocketFailure.system(errno) }
        guard info.st_uid == geteuid(), info.st_mode & 0o777 == 0o700 else { throw LocalSocketFailure.unsafePath }
        lockFD = openat(dir, "maro.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0 else { throw LocalSocketFailure.system(errno) }
        guard fstat(lockFD, &info) == 0 else { throw LocalSocketFailure.system(errno) }
        guard info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o777 == 0o600, info.st_nlink == 1 else { throw LocalSocketFailure.unsafePath }
        guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { throw LocalSocketFailure.alreadyRunning }
            throw LocalSocketFailure.system(errno)
        }
        // The persistent lock serializes startup and cleanup, including crashes.
        // Never unlink the lock file: doing so would allow two independent locks.
        if fstatat(dir, Self.name, &info, AT_SYMLINK_NOFOLLOW) == 0 {
            try Self.validateSocket(info)
            do {
                let peer = try Self.connect(to: socketURL, deadline: ContinuousClock().now.advanced(by: .milliseconds(250)))
                Darwin.close(peer)
                throw LocalSocketFailure.alreadyRunning
            } catch LocalSocketFailure.system(let code) where code == ECONNREFUSED {
                Self.removeOwnedSocket(directory: dir, inode: info.st_ino, device: info.st_dev)
            }
        } else if errno != ENOENT { throw LocalSocketFailure.system(errno) }
        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { throw LocalSocketFailure.system(errno) }
        try LocalSocketIO.configure(socketFD)
        var address = try Self.address(socketURL)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw LocalSocketFailure.system(errno) }
        guard fstatat(dir, Self.name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw LocalSocketFailure.system(errno) }
        bound = info
        guard fchmodat(dir, Self.name, 0o600, AT_SYMLINK_NOFOLLOW) == 0,
              listen(socketFD, 8) == 0 else { throw LocalSocketFailure.system(errno) }
        descriptor = socketFD; directory = dir; lock = lockFD
        inode = info.st_ino; device = info.st_dev
        committed = true
    }

    deinit {
        Self.removeOwnedSocket(directory: directory, inode: inode, device: device)
        Darwin.close(descriptor)
        Darwin.close(lock)
        Darwin.close(directory)
    }

    func accept(deadline: ContinuousClock.Instant) throws -> Int32 {
        while true {
            try LocalSocketIO.wait(descriptor, events: Int16(POLLIN), deadline: deadline)
            let peer = Darwin.accept(descriptor, nil, nil)
            if peer < 0 {
                if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                throw LocalSocketFailure.system(errno)
            }
            do {
                try LocalSocketIO.configure(peer)
                try LocalSocketIO.requireCurrentUser(peer)
                return peer
            } catch {
                // A readiness probe may disconnect before peer credentials are
                // available. A rejected/closed peer must not stop the listener.
                Darwin.close(peer)
                continue
            }
        }
    }

    static func connect(to url: URL, deadline: ContinuousClock.Instant) throws -> Int32 {
        var address = try address(url)
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw LocalSocketFailure.system(errno) }
        try validateSocket(info)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw LocalSocketFailure.system(errno) }
        do {
            try LocalSocketIO.configure(fd)
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result != 0 {
                guard errno == EINPROGRESS else { throw LocalSocketFailure.system(errno) }
                try LocalSocketIO.wait(fd, events: Int16(POLLOUT), deadline: deadline)
                var error: Int32 = 0
                var size = socklen_t(MemoryLayout.size(ofValue: error))
                guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) == 0 else { throw LocalSocketFailure.system(errno) }
                guard error == 0 else { throw LocalSocketFailure.system(error) }
            }
            try Task.checkCancellation()
            guard ContinuousClock().now < deadline else { throw LocalSocketFailure.timedOut }
            try LocalSocketIO.requireCurrentUser(fd)
            return fd
        } catch { Darwin.close(fd); throw error }
    }

    private static func address(_ url: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        let bytes = Array(url.path.utf8)
        guard url.isFileURL, !bytes.contains(0), bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw LocalSocketFailure.unsafePath
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: bytes)
        }
        return address
    }

    private static func validateSocket(_ info: stat) throws {
        guard info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFSOCK,
              info.st_mode & 0o777 == 0o600 else { throw LocalSocketFailure.unsafePath }
    }

    private static func removeOwnedSocket(directory: Int32, inode: ino_t, device: dev_t) {
        var current = stat()
        if fstatat(directory, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
           current.st_ino == inode, current.st_dev == device,
           current.st_mode & S_IFMT == S_IFSOCK, current.st_uid == geteuid() {
            unlinkat(directory, name, 0)
        }
    }
}
