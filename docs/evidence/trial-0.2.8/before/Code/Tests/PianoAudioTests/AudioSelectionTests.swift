import XCTest
@testable import PianoAudio

final class AudioSelectionTests: XCTestCase {
    final class Engine: AuditionEngine {
        var calls: [String] = []
        var fail = false
        func prepare(bankURL: URL, offline: Bool) throws { calls.append("prepare:\(bankURL.lastPathComponent)"); if fail { throw NSError(domain: "test", code: 1) } }
        func shutdown() { calls.append("shutdown") }
        func setGain(_ gain: Float) { calls.append("gain") }
        func noteOn(midi: UInt8, velocity: UInt8) { calls.append("on:\(midi)") }
        func noteOff(midi: UInt8) { calls.append("off:\(midi)") }
        func panic() { calls.append("panic") }
    }
    func testDefaultSilentExplicitEnableSwitchStopsAndNoFallback() throws {
        let engine = Engine()
        let source = AudioSource(id: "a", title: "a", url: URL(fileURLWithPath: "/a.sf2"), coveredMIDI: [60])
        let other = AudioSource(id: "b", title: "b", url: URL(fileURLWithPath: "/b.sf2"), coveredMIDI: [61])
        let session = AuditionSession(engine: engine, source: source)
        XCTAssertFalse(session.enabled); XCTAssertTrue(engine.calls.isEmpty)
        session.noteOn(midi: 60, velocity: 80); XCTAssertTrue(engine.calls.isEmpty)
        try session.enable(); XCTAssertTrue(session.enabled)
        session.noteOn(midi: 33, velocity: 80); XCTAssertFalse(engine.calls.contains("on:33"))
        session.noteOn(midi: 60, velocity: 80); XCTAssertTrue(engine.calls.contains("on:60"))
        var cleared = false
        session.select(other) { cleared = true }
        XCTAssertTrue(cleared); XCTAssertFalse(session.enabled)
        XCTAssertEqual(engine.calls.last, "shutdown")
        XCTAssertFalse(engine.calls.contains("prepare:b.sf2"))
        engine.fail = true
        XCTAssertThrowsError(try session.enable()); XCTAssertFalse(session.enabled)
        XCTAssertEqual(session.source.id, "b")
    }
    func testCandidateCoverageExactAndBundlePaths() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = try AudioSource.available(root: root, bundled: false)
        XCTAssertEqual(sources.map { $0.coveredMIDI.count }, [64, 64, 10, 11])
        XCTAssertEqual(sources.first?.id, "steinway-trial-64")
        guard sources.count == 4 else { return }
        XCTAssertEqual(sources[2].url.path, root.appendingPathComponent("Design/Audio/probes/A-001B/vcsl-kawai/trial.sf2").path)
        XCTAssertEqual(sources[3].url.path, root.appendingPathComponent("Design/Audio/probes/A-001B/vcsl-steinway-b/trial.sf2").path)
    }
    func testMissingOrChangedFullBankCannotSilentlyFallBack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let candidate = root.appendingPathComponent("AudioCandidates")
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceRoot.appendingPathComponent("Design/Audio/probes/A-001B/trial-index.json"), to: candidate.appendingPathComponent("trial-index.json"))
        XCTAssertThrowsError(try AudioSource.available(root: root, bundled: true))
        let trial = root.appendingPathComponent("AudioTrial/vcsl-steinway-b")
        try FileManager.default.createDirectory(at: trial, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceRoot.appendingPathComponent("Design/Audio/trial/A-002T/trial-index.json"), to: trial.deletingLastPathComponent().appendingPathComponent("trial-index.json"))
        try Data("corrupt bank".utf8).write(to: trial.appendingPathComponent("trial.sf2"))
        XCTAssertThrowsError(try AudioSource.available(root: root, bundled: true))
    }

}
