import AVFoundation
import Foundation
import Testing
@testable import MaroCore

func makeSilentAudio() throws -> URL {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("maro-\(UUID()).wav")
    // One second of silent mono 8 kHz PCM; no encoder or network dependency.
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func number<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
    text("RIFF"); number(UInt32(16036)); text("WAVEfmt "); number(UInt32(16))
    number(UInt16(1)); number(UInt16(1)); number(UInt32(8000)); number(UInt32(16000))
    number(UInt16(2)); number(UInt16(16)); text("data"); number(UInt32(16000))
    data.append(Data(repeating: 0, count: 16000))
    try data.write(to: file)
    return file
}

@Test func localAudioLoadsWithoutPlayingOrDownloading() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = try await AudioAssetLoader.loadAsset(AVURLAsset(url: file), timeout: .seconds(5))
    let duration = try await asset.load(.duration)
    #expect(abs(duration.seconds - 1) < 0.01)
}

@Test func assetLoaderRejectsInvalidTimeoutAndHonorsCancellation() async throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: "/missing-maro-audio.wav"))
    do {
        _ = try await AudioAssetLoader.loadAsset(asset, timeout: .zero)
        Issue.record("Expected invalid timeout")
    } catch { #expect(error as? AudioPreparationFailure == .invalidTimeout) }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await AudioAssetLoader.loadAsset(asset, timeout: .seconds(1))
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch { #expect(error is CancellationError) }
}

@Test func assetLoaderChecksCodecBeforeNetworking() async throws {
    let candidate = AudioCandidate(url: URL(string: "https://invalid.test/audio")!,
                                   audioCodec: "not-a-codec", bitrate: 128, userAgent: nil)
    do {
        _ = try await AudioAssetLoader.prepare(candidate)
        Issue.record("Expected unsupported codec")
    } catch { #expect(error as? AudioPreparationFailure == .unsupportedCodec) }
}
