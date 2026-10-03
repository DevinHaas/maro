import Darwin
import Foundation
import Testing
@testable import MaroCore

private let workerFixture = #"""
import json,os,subprocess,sys,time
time.sleep(float(sys.argv[1]))
print('{"ready":1}',flush=True)
sequence=0
for line in sys.stdin:
 r=json.loads(line); sequence+=1
 op=r['operation']; value=r['value']
 if op=='crash': os._exit(3)
 if op=='flood': print('x'*(9*1024*1024),flush=True); continue
 if op=='hang': time.sleep(60)
 if op=='search': time.sleep(0.3)
 child=None
 if op=='child': child=subprocess.Popen(['/bin/sleep','60']).pid
 result={'id':'stale' if op=='stale' else r['id'], 'result':{'pid':os.getpid(),'sequence':sequence,'value':value,'child':child}}
 if op=='error': result={'id':r['id'],'error':'network'}
 print(json.dumps(result),flush=True)
"""#

private func fixtureWorker(startup: Double = 0, timeout: Double = 2) -> ExtractorWorker {
    ExtractorWorker(executable: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-I", "-B", "-c", workerFixture, String(startup)], timeout: timeout)
}

private func workerResult(_ data: Data) throws -> [String: Any] {
    let envelope = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(envelope["result"] as? [String: Any])
}

@Test func workerSharesInitializationCorrelatesRequestsAndSurvivesExtractionErrors() async throws {
    let worker = fixtureWorker(startup: 0.1)
    let responses = try await withThrowingTaskGroup(of: Data.self) { group in
        for i in 0..<6 { group.addTask { try await worker.request("ping", value: "\(i)") } }
        var results: [Data] = []
        for try await result in group { results.append(result) }
        return results
    }
    let results = try responses.map(workerResult)
    #expect(Set(results.compactMap { $0["pid"] as? Int }).count == 1)
    #expect(Set(results.compactMap { $0["value"] as? String }).count == 6)
    let oldPID = results.first?["pid"] as? Int
    _ = try await worker.request("error")
    let after = try workerResult(await worker.request("resolve", value: "next"))
    #expect(after["pid"] as? Int == oldPID)
    async let first = worker.request("search", value: "duplicate")
    async let second = worker.request("search", value: "duplicate")
    let pair = try await [first, second].map(workerResult)
    #expect(pair[0]["sequence"] as? Int == pair[1]["sequence"] as? Int)
    let child = try workerResult(await worker.request("child"))
    let childPID = try #require(child["child"] as? Int32)
    await worker.shutdown()
    #expect(kill(Int32(oldPID!), 0) == -1)
    // A terminated child may briefly remain a zombie until launchd reaps it.
    for _ in 0..<100 {
        if kill(childPID, 0) == -1 { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(kill(childPID, 0) == -1)
}

@Test func workerCancellationPriorityAndQueueLimitsStayBounded() async throws {
    let worker = fixtureWorker(startup: 0.2)
    let initializing = Task { try await worker.request("ping") }
    try await Task.sleep(for: .milliseconds(30))
    initializing.cancel()
    do { _ = try await initializing.value; Issue.record("Expected startup cancellation") } catch is CancellationError {} catch { Issue.record("Wrong cancellation") }
    _ = try await worker.request("ping")
    let search = Task { try await worker.request("search", value: "obsolete") }
    try await Task.sleep(for: .milliseconds(40))
    let queued = Task { try await worker.request("ping", value: "queued") }
    try await Task.sleep(for: .milliseconds(20))
    queued.cancel()
    let start = ContinuousClock.now
    let selected = try workerResult(await worker.request("resolve", value: "selected"))
    #expect(selected["value"] as? String == "selected")
    #expect(start.duration(to: .now) < .seconds(1))
    do { _ = try await search.value; Issue.record("Expected preemption") } catch is CancellationError {} catch { Issue.record("Wrong preemption") }
    do { _ = try await queued.value; Issue.record("Expected queued cancellation") } catch is CancellationError {} catch { Issue.record("Wrong queued cancellation") }
    let hanging = Task { try await worker.request("hang") }
    try await Task.sleep(for: .milliseconds(20))
    var pending: [Task<Data, Error>] = []
    for i in 0..<7 { pending.append(Task { try await worker.request("ping", value: "\(i)") }) }
    try await Task.sleep(for: .milliseconds(30))
    do { _ = try await worker.request("ping", value: "overload"); Issue.record("Expected overload") }
    catch { #expect(error as? ExtractorFailure == .failed) }
    await worker.shutdown()
    _ = try? await hanging.value
    for task in pending { _ = try? await task.value }
}

@Test func workerRejectsStaleFloodedCrashedAndHungRepliesWithBoundedRecovery() async throws {
    for operation in ["stale", "flood", "crash", "hang"] {
        let worker = fixtureWorker(timeout: 0.4)
        do { _ = try await worker.request(operation); Issue.record("Expected \(operation) failure") } catch {}
        let recovered = try workerResult(await worker.request("ping"))
        #expect(recovered["sequence"] as? Int == 1)
        await worker.shutdown()
    }
    let worker = fixtureWorker()
    for _ in 0..<3 { _ = try? await worker.request("crash") }
    do { _ = try await worker.request("ping"); Issue.record("Expected restart circuit limit") }
    catch { #expect(error as? ExtractorFailure == .failed) }
    await worker.shutdown()
}
