import Darwin
import Foundation
import Testing
@testable import MaroCore

private let shell = URL(fileURLWithPath: "/bin/sh")

@Test func processCapturesBothPipesAndNonzeroExit() async throws {
    let result = try await ExtractorProcess.run(executable: shell,
        arguments: ["-c", "printf result; printf diagnostic >&2; exit 7"])
    #expect(result.stdout == Data("result".utf8))
    #expect(result.stderr == Data("diagnostic".utf8))
    #expect(result.exitCode == 7)
}

@Test func processDrainsBothPipesWithoutDeadlock() async throws {
    let result = try await ExtractorProcess.run(executable: shell,
        arguments: ["-c", "i=0; while [ $i -lt 2000 ]; do printf abcdefghijklmnop; printf abcdefghijklmnop >&2; i=$((i+1)); done"])
    #expect(result.stdout.count == 32_000)
    #expect(result.stderr.count == 32_000)
    #expect(result.exitCode == 0)
}

@Test func processLimitsOutputAndRuntime() async throws {
    do {
        _ = try await ExtractorProcess.run(executable: shell,
            arguments: ["-c", "while :; do printf 1234567890 >&2; done"], stderrLimit: 100)
        Issue.record("Expected an output limit")
    } catch { #expect(error as? ProcessFailure == .outputLimit) }
    do {
        _ = try await ExtractorProcess.run(executable: shell, arguments: ["-c", "sleep 20"], timeout: 0.1)
        Issue.record("Expected a timeout")
    } catch { #expect(error as? ProcessFailure == .timedOut) }
}

@Test func processCancellationTerminatesInvocation() async throws {
    let task = Task { try await ExtractorProcess.run(executable: shell, arguments: ["-c", "sleep 20"]) }
    try await Task.sleep(for: .milliseconds(50))
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch { #expect(error is CancellationError) }
}

@Test func processCleansUpDescendantAfterParentExits() async throws {
    let result = try await ExtractorProcess.run(executable: shell,
        arguments: ["-c", "sleep 20 & printf '%s' $!"])
    let child = try #require(Int32(String(decoding: result.stdout, as: UTF8.self)))
    defer { kill(child, SIGKILL) }
    for _ in 0..<100 {
        if kill(child, 0) == -1 && errno == ESRCH { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Extractor descendant survived process completion")
}

@Test func processRejectsInvalidInvocationAndMissingExecutable() async throws {
    do {
        _ = try await ExtractorProcess.run(executable: shell, arguments: ["bad\0arg"])
        Issue.record("Expected argument rejection")
    } catch { #expect(error as? ProcessFailure == .invalidInvocation) }
    do {
        _ = try await ExtractorProcess.run(executable: URL(fileURLWithPath: "/nonexistent-maro-extractor"), arguments: [])
        Issue.record("Expected missing executable")
    } catch { #expect(error as? ProcessFailure == .system(ENOENT)) }
}
