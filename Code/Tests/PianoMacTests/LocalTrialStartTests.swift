import XCTest
import PianoCore
import PianoAudio
@testable import PianoMac

/// No NSApplication, window, real listener, or device in this test.
final class LocalTrialStartTests: XCTestCase {
    final class Input: InputMonitoring {
        var mode: InputMonitor.Mode = .stopped
        var duration: InputSessionDuration?
        var onEvent: ((NormalizedKeyEvent) -> Void)?
        var onStop: ((String) -> Void)?
        func start(global: Bool, duration: InputSessionDuration) throws {
            if global { throw ProbeError.invalid("permission unavailable") }
            self.duration = duration; mode = .local
        }
        func stop() { mode = .stopped }
    }
    final class Engine: AuditionEngine {
        var prepared = false
        var fail = false
        func prepare(bankURL: URL, offline: Bool) throws { if fail { throw ProbeError.invalid("bank failed") }; prepared = true }
        func shutdown() { prepared = false }
        func setGain(_ gain: Float) {}
        func noteOn(midi: UInt8, velocity: UInt8) {}
        func noteOff(midi: UInt8) {}
        func panic() {}
    }
    func testGlobalFailureDoesNotBlockLocalContinuousExplicitStartAndCleanup() throws {
        let input = Input(), engine = Engine()
        let audio = AuditionSession(engine: engine, source: AudioSource(id: "test", title: "test", url: URL(fileURLWithPath: "/unused.sf2"), coveredMIDI: [60]))
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(audio.enabled); XCTAssertFalse(engine.prepared)
        XCTAssertThrowsError(try ContinuousTrialStart.run(global: true, input: input, audio: audio))
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        try ContinuousTrialStart.run(global: false, input: input, audio: audio)
        XCTAssertEqual(input.mode, .local); XCTAssertEqual(input.duration, .continuous)
        XCTAssertTrue(audio.enabled); XCTAssertTrue(engine.prepared)
        input.stop(); audio.disable()
        engine.fail = true
        XCTAssertThrowsError(try ContinuousTrialStart.run(global: false, input: input, audio: audio))
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(audio.enabled); XCTAssertFalse(engine.prepared)
    }
}
