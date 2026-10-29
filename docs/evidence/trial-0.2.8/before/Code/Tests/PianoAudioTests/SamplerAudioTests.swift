import Foundation
import XCTest
@testable import PianoAudio

final class SamplerAudioTests: XCTestCase {
    private var bankURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/placeholder-original.sf2")
    }

    private func prepared() throws -> SamplerAudio {
        let audio = SamplerAudio()
        try audio.prepare(bankURL: bankURL, offline: true)
        return audio
    }

    private func peak(_ samples: [Float]) -> Float { samples.map(abs).max() ?? 0 }
    private func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    func testAppGainZeroAndMaximumWithoutChangingVoiceLifecycle() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        audio.setGain(0)
        audio.noteOn(midi: 60, velocity: 64)
        let zeroTransition = try audio.render(seconds: 0.1)
        print("AUDIO_DIAGNOSTIC zero_gain_last_nonzero_seconds=\(Double(zeroTransition.lastIndex { abs($0) > 0.0000001 } ?? 0) / audio.sampleRate) late_peak=\(peak(Array(zeroTransition.suffix(2400))))")
        XCTAssertLessThan(peak(zeroTransition), 0.000001)
        audio.setGain(0.16)
        XCTAssertLessThan(peak(try audio.render(seconds: 0.1)), 0.000001) // raising volume never replays held notes
        audio.noteOn(midi: 60, velocity: 64)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.1)), 0.00001)
        audio.setGain(0)
        XCTAssertLessThan(peak(try audio.render(seconds: 0.1)), 0.000001) // zero also clears an existing tail
        audio.setGain(0.16)
        audio.panic()
        for midi in UInt8(33)...96 { audio.noteOn(midi: midi, velocity: 127) }
        let maximum = peak(try audio.render(seconds: 1))
        XCTAssertLessThan(maximum, 0.9)
        XCTAssertEqual(audio.gain, 0.16)
        print("AUDIO_METRIC max_slider_gain=0.16 chord_peak=\(maximum)")
        audio.setGain(1)
        XCTAssertEqual(audio.gain, 0.16)
        audio.setGain(.nan)
        XCTAssertEqual(audio.gain, 0.16)
    }

    func testAll64PitchesRenderNonzeroFiniteOutput() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        var peaks: [Float] = []
        for midi in UInt8(33)...96 {
            audio.panic()
            audio.noteOn(midi: midi, velocity: 64)
            let samples = try audio.render(seconds: 0.12)
            XCTAssertEqual(samples.count, Int(audio.sampleRate * 0.12))
            XCTAssertTrue(samples.allSatisfy(\.isFinite), "MIDI \(midi)")
            let value = peak(samples)
            XCTAssertGreaterThan(value, 0.00001, "MIDI \(midi)")
            XCTAssertLessThan(value, 1, "MIDI \(midi)")
            peaks.append(value)
            audio.noteOff(midi: midi)
        }
        print("AUDIO_METRIC coverage=64 minimum_peak=\(peaks.min() ?? 0) maximum_peak=\(peaks.max() ?? 0)")
    }

    func test64NoteChordHasHeadroom() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        for midi in UInt8(33)...96 { audio.noteOn(midi: midi, velocity: 127) }
        let samples = try audio.render(seconds: 1)
        XCTAssertTrue(samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(peak(samples), 0.001)
        XCTAssertLessThan(peak(samples), 0.9)
        print("AUDIO_METRIC chord_note_commands=64 velocity=127 gain=0.08 peak=\(peak(samples)) rms=\(rms(samples))")
    }

    func testTenHertzRetriggerRemainsBounded() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        var peaks: [Float] = []
        for _ in 0..<100 {
            audio.noteOn(midi: 60, velocity: 64)
            let strike = try audio.render(seconds: 0.05)
            audio.noteOff(midi: 60)
            let tail = try audio.render(seconds: 0.05)
            peaks.append(peak(strike + tail))
        }
        XCTAssertTrue(peaks.allSatisfy { $0.isFinite && $0 > 0.00001 && $0 < 0.9 })
        XCTAssertLessThan(peaks.suffix(10).max() ?? 1, (peaks.prefix(10).max() ?? 0) * 2)
        print("AUDIO_METRIC retrigger_hz=10 strikes=100 max_peak=\(peaks.max() ?? 0)")
    }

    func testNoteOffHasTailThenSilence() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        audio.noteOn(midi: 60, velocity: 64)
        _ = try audio.render(seconds: 0.1)
        audio.noteOff(midi: 60)
        let early = try audio.render(seconds: 0.1)
        let middle = try audio.render(seconds: 0.7)
        let late = try audio.render(seconds: 0.2)
        XCTAssertGreaterThan(peak(early), 0.00001)
        XCTAssertLessThan(peak(late), 0.000001)
        let tail = early + middle + late
        let lastActive = tail.lastIndex { abs($0) > 0.0000001 } ?? 0
        print("AUDIO_METRIC release_early_peak=\(peak(early)) release_after_800ms_peak=\(peak(late)) last_frame_above_1e-7_seconds=\(Double(lastActive) / audio.sampleRate)")
    }

    func testTenSecondHoldNaturallyDecaysWithoutTimeout() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        audio.noteOn(midi: 60, velocity: 64)
        let early = try audio.render(seconds: 0.2)
        _ = try audio.render(seconds: 9.6)
        let late = try audio.render(seconds: 0.2)
        XCTAssertGreaterThan(peak(early), 0.00001)
        XCTAssertLessThan(peak(late), 0.000001)
        audio.noteOff(midi: 60)
        print("AUDIO_METRIC hold_seconds=10 early_peak=\(peak(early)) final_peak=\(peak(late))")
    }

    func testPanicClearsTailsAndAllowsNextStrike() throws {
        let audio = try prepared()
        defer { audio.shutdown() }
        audio.noteOn(midi: 36, velocity: 127)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.1)), 0.00001)
        audio.noteOff(midi: 36)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.05)), 0.00001)
        audio.noteOn(midi: 96, velocity: 127)
        audio.panic()
        XCTAssertLessThan(peak(try audio.render(seconds: 0.5)), 0.000001)
        audio.noteOn(midi: 72, velocity: 64)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.1)), 0.00001)
        print("AUDIO_METRIC panic_post_render_silent=true next_strike_nonzero=true")
    }

    func testRejectsMissingMisnamedAndInvalidBanks() throws {
        let audio = SamplerAudio()
        defer { audio.shutdown() }
        XCTAssertThrowsError(try audio.prepare(bankURL: bankURL.deletingLastPathComponent().appendingPathComponent("missing.sf2"), offline: true))
        XCTAssertThrowsError(try audio.prepare(bankURL: bankURL.deletingLastPathComponent().appendingPathComponent("renamed.sfz"), offline: true)) {
            XCTAssertEqual($0 as? SamplerAudioError, .unsupportedBankExtension)
        }
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sf2")
        try Data("not a RIFF sfbk sound bank".utf8).write(to: bad)
        defer { try? FileManager.default.removeItem(at: bad) }
        XCTAssertThrowsError(try audio.prepare(bankURL: bad, offline: true)) {
            XCTAssertEqual($0 as? SamplerAudioError, .invalidBankContent)
        }
        // A correctly named file with a real RIFF/WAVE header is not an SF2.
        try Data([0x52, 0x49, 0x46, 0x46, 4, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]).write(to: bad)
        XCTAssertThrowsError(try audio.prepare(bankURL: bad, offline: true)) {
            XCTAssertEqual($0 as? SamplerAudioError, .invalidBankContent)
        }
        var truncated = try Data(contentsOf: bankURL)
        truncated.removeLast()
        try truncated.write(to: bad)
        XCTAssertThrowsError(try audio.prepare(bankURL: bad, offline: true)) {
            XCTAssertEqual($0 as? SamplerAudioError, .invalidBankContent)
        }
        XCTAssertThrowsError(try audio.render(seconds: 0.1)) {
            XCTAssertEqual($0 as? SamplerAudioError, .notPrepared)
        }
    }

    func testShutdownAndReprepare() throws {
        let audio = try prepared()
        audio.noteOn(midi: 60, velocity: 64)
        audio.shutdown()
        XCTAssertThrowsError(try audio.render(seconds: 0.1))
        try audio.prepare(bankURL: bankURL, offline: true)
        defer { audio.shutdown() }
        XCTAssertLessThan(peak(try audio.render(seconds: 0.1)), 0.000001)
        audio.noteOn(midi: 60, velocity: 64)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.1)), 0.00001)
    }
}
