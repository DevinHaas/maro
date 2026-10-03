import Darwin
import Foundation

public enum LocalSocketFailure: Error, Equatable, Sendable {
    case system(Int32)
    case timedOut
    case closed
    case unauthorizedPeer
    case unsafePath
    case alreadyRunning
}

/// Blocking worker-only operations over nonblocking descriptors. The caller owns
/// each descriptor and closes it after the worker finishes, never concurrently.
enum LocalSocketIO {
    static func configure(_ fd: Int32) throws {
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0,
              fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { throw LocalSocketFailure.system(errno) }
        var enabled: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled,
                         socklen_t(MemoryLayout.size(ofValue: enabled))) == 0 else {
            throw LocalSocketFailure.system(errno)
        }
    }

    static func requireCurrentUser(_ fd: Int32) throws {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0 else { throw LocalSocketFailure.system(errno) }
        guard uid == geteuid() else { throw LocalSocketFailure.unauthorizedPeer }
    }

    static func readLine(_ fd: Int32, limit: Int,
                         deadline: ContinuousClock.Instant) throws -> Data {
        guard limit > 0, limit <= CommandWire.maximumResponseBytes else {
            throw CommandProtocolFailure.oversizedFrame
        }
        var frame = Data()
        var buffer = [UInt8](repeating: 0, count: min(4096, limit))
        while true {
            try wait(fd, events: Int16(POLLIN), deadline: deadline)
            let count = recv(fd, &buffer, min(buffer.count, limit - frame.count), 0)
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                throw LocalSocketFailure.system(errno)
            }
            guard count > 0 else { throw LocalSocketFailure.closed }
            frame.append(contentsOf: buffer.prefix(count))
            if let newline = frame.firstIndex(of: 10) {
                guard newline == frame.index(before: frame.endIndex) else {
                    throw CommandProtocolFailure.invalidFrame
                }
                return frame
            }
            guard frame.count < limit else { throw CommandProtocolFailure.oversizedFrame }
        }
    }

    static func write(_ data: Data, to fd: Int32, deadline: ContinuousClock.Instant) throws {
        guard data.count <= CommandWire.maximumResponseBytes else {
            throw CommandProtocolFailure.oversizedFrame
        }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                try wait(fd, events: Int16(POLLOUT), deadline: deadline)
                let count = send(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
                if count < 0 {
                    if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                    throw LocalSocketFailure.system(errno)
                }
                guard count > 0 else { throw LocalSocketFailure.closed }
                offset += count
            }
        }
    }

    static func wait(_ fd: Int32, events: Int16,
                             deadline: ContinuousClock.Instant) throws {
        let clock = ContinuousClock()
        while true {
            try Task.checkCancellation()
            let remaining = clock.now.duration(to: deadline)
            guard remaining > .zero else { throw LocalSocketFailure.timedOut }
            // Short polling bounds cancellation latency; the absolute deadline
            // does not reset when a peer trickles bytes or the kernel interrupts.
            let parts = remaining.components
            let milliseconds = parts.seconds >= 1 ? 50 : max(1, min(50, parts.attoseconds / 1_000_000_000_000_000))
            var descriptor = pollfd(fd: fd, events: events, revents: 0)
            let result = poll(&descriptor, 1, Int32(milliseconds))
            if result < 0 {
                if errno == EINTR { continue }
                throw LocalSocketFailure.system(errno)
            }
            if result == 0 { continue }
            if descriptor.revents & Int16(POLLNVAL) != 0 { throw LocalSocketFailure.system(EBADF) }
            // Let recv drain buffered bytes on HUP, or send return the precise
            // error. SO_NOSIGPIPE prevents a disconnected peer killing the app.
            if descriptor.revents & (events | Int16(POLLHUP | POLLERR)) != 0 { return }
        }
    }
}
