import XCTest
import CryptoKit
@testable import PianoAudio

/// Deterministic synthesis commands only: no captured typing or hardware output.
final class TrialBankTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func peak(_ x: [Float]) -> Float { x.reduce(0) { max($0, abs($1)) } }
    private func rms(_ x: [Float]) -> Double { sqrt(x.reduce(0) { $0 + Double($1) * Double($1) } / Double(max(1, x.count))) }
    private func sha(_ url: URL) throws -> String { SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined() }
    private func floatWAV(_ samples: [Float]) -> Data {
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + samples.count * 4)); text("WAVEfmt "); u32(16); u16(3); u16(1)
        u32(48_000); u32(192_000); u16(4); u16(32); text("data"); u32(UInt32(samples.count * 4))
        for sample in samples { u32(sample.bitPattern) }
        return data
    }
    func testTrialBankCalibrationCoverageAndLifecycle() throws {
        let source = try XCTUnwrap(AudioSource.available(root: root, bundled: false).first)
        XCTAssertEqual(source.id, "steinway-trial-64")
        let audio = SamplerAudio()
        defer { audio.shutdown() }
        try audio.prepare(bankURL: source.url, offline: true)
        var rows: [[String: Any]] = [], clips: [Float] = [], segments: [[String: Any]] = []
        func record(_ name: String, _ samples: [Float], save: Bool = false, gain: Float? = nil, velocity: Int = 64) {
            let p = peak(samples)
            XCTAssertTrue(samples.allSatisfy(\.isFinite), name)
            XCTAssertLessThan(p, 0.9, name)
            rows.append(["name": name, "peak": p, "rms": rms(samples), "gain": gain ?? audio.gain, "samplerDB": audio.samplerGainDB, "velocity": velocity, "frames": samples.count])
            if save {
                segments.append(["name": name, "startFrame": clips.count, "frames": samples.count, "gain": gain ?? audio.gain, "samplerDB": audio.samplerGainDB, "velocity": velocity])
                clips += samples; clips += Array(repeating: 0, count: 12_000)
            }
        }
        for velocity in [32, 64, 100, 127] {
            audio.panic(); audio.noteOn(midi: 60, velocity: UInt8(velocity))
            record("legacy-chain-C4-v\(velocity)", try audio.render(seconds: 0.5), velocity: velocity)
        }
        audio.configureGain(maximum: source.maximumMixerGain, samplerDB: source.samplerGainDB)
        audio.setGain(source.maximumMixerGain * 0.5)
        for midi in UInt8(33)...96 {
            audio.panic(); audio.noteOn(midi: midi, velocity: 64)
            let samples = try audio.render(seconds: 0.5)
            XCTAssertGreaterThan(peak(samples), 0.0001, "MIDI \(midi)")
            record("default-MIDI\(midi)", samples)
        }
        for midi: UInt8 in [33, 48, 60, 72, 84, 96] {
            audio.panic(); audio.noteOn(midi: midi, velocity: 64)
            var s = try audio.render(seconds: 0.35); audio.noteOff(midi: midi)
            s += try audio.render(seconds: 0.8)
            record("representative-MIDI\(midi)", s, save: true)
        }
        for hold in [0.01, 0.1, 1, 8] {
            audio.panic(); audio.noteOn(midi: 60, velocity: 64)
            var s = try audio.render(seconds: hold); audio.noteOff(midi: 60)
            let tail = try audio.render(seconds: 1)
            XCTAssertLessThan(peak(Array(tail.suffix(4800))), 0.000001)
            s += tail; record("hold-\(hold)s-release", s, save: hold == 0.01 || hold == 1)
        }
        for volume: Float in [0.5, 1] {
            audio.setGain(source.maximumMixerGain * volume); audio.panic()
            var typing: [Float] = []
            for i in 0..<120 {
                let midi = UInt8(33 + ((i * 13) % 64))
                audio.noteOn(midi: midi, velocity: 64)
                typing += try audio.render(seconds: 0.035); audio.noteOff(midi: midi)
                typing += try audio.render(seconds: 0.025)
            }
            typing += try audio.render(seconds: 1)
            record("typing-overlapping-tails-volume\(volume)", typing, save: true)
            audio.panic(); var retrigger: [Float] = []
            for _ in 0..<100 {
                audio.noteOn(midi: 60, velocity: 64); retrigger += try audio.render(seconds: 0.025)
                audio.noteOff(midi: 60); retrigger += try audio.render(seconds: 0.025)
            }
            record("20Hz-retrigger-volume\(volume)", retrigger)
            for velocity in [64, 127] {
                audio.panic()
                for midi in UInt8(33)...96 { audio.noteOn(midi: midi, velocity: UInt8(velocity)) }
                var chord = try audio.render(seconds: 1)
                for midi in UInt8(33)...96 { audio.noteOff(midi: midi) }
                chord += try audio.render(seconds: 1)
                record("64-note-chord-volume\(volume)-v\(velocity)", chord, save: volume == 1 && velocity == 64, velocity: velocity)
            }
        }
        audio.noteOn(midi: 60, velocity: 127); _ = try audio.render(seconds: 0.1)
        audio.setGain(0); audio.noteOn(midi: 48, velocity: 127)
        let zero = try audio.render(seconds: 0.2); XCTAssertLessThan(peak(zero), 0.000001); record("zero-clears-and-suppresses", zero)
        audio.setGain(source.maximumMixerGain)
        let noReplay = try audio.render(seconds: 0.2); XCTAssertLessThan(peak(noReplay), 0.000001); record("raising-volume-no-replay", noReplay)
        audio.noteOn(midi: 60, velocity: 64); _ = try audio.render(seconds: 0.1); audio.panic()
        let panic = try audio.render(seconds: 0.3); XCTAssertLessThan(peak(panic), 0.000001); record("panic-clears", panic)
        audio.shutdown()
        XCTAssertThrowsError(try audio.render(seconds: 0.1))
        let session = AuditionSession(engine: audio, source: source)
        try session.enable(offline: true); session.noteOn(midi: 60, velocity: 64)
        XCTAssertGreaterThan(peak(try audio.render(seconds: 0.1)), 0.0001)
        session.disable(); XCTAssertFalse(audio.isPrepared)
        try session.enable(offline: true)
        XCTAssertLessThan(peak(try audio.render(seconds: 0.1)), 0.000001)
        session.disable()
        let stereo = SamplerAudio(renderChannelCount: 2)
        defer { stereo.shutdown() }
        stereo.configureGain(maximum: source.maximumMixerGain, samplerDB: source.samplerGainDB)
        stereo.setGain(source.maximumMixerGain)
        try stereo.prepare(bankURL: source.url, offline: true)
        for midi in UInt8(33)...96 { stereo.noteOn(midi: midi, velocity: 127) }
        let stereoChord = try stereo.render(seconds: 1)
        XCTAssertEqual(stereoChord.count, 96_000)
        record("stereo-64-note-max-v127", stereoChord, gain: stereo.gain, velocity: 127)
        // Regression runs must not replace frozen C-002T acceptance evidence.
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("typing-piano-calibration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: output) }
        let wav = output.appendingPathComponent("steinway-trial-float32.wav")
        try floatWAV(clips).write(to: wav)
        let report: [String: Any] = ["task": "C-002T", "date": ISO8601DateFormatter().string(from: Date()), "environment": ProcessInfo.processInfo.operatingSystemVersionString, "hardwareOutput": false, "realInput": false,
            "bankSHA256": try sha(source.url), "samplerSourceSHA256": try sha(root.appendingPathComponent("Code/Sources/PianoAudio/SamplerAudio.swift")), "selectionSourceSHA256": try sha(root.appendingPathComponent("Code/Sources/PianoAudio/AuditionSession.swift")), "testSourceSHA256": try sha(URL(fileURLWithPath: #filePath)),
            "sampleRate": 48000, "renderFormat": "mono IEEE float32, no offline post-gain or normalization", "defaultVolume": 0.5, "maximumMixerGain": source.maximumMixerGain, "samplerGainDB": source.samplerGainDB,
            "measurements": rows, "representativeWAV": ["file": wav.lastPathComponent, "sha256": try sha(wav), "segments": segments], "muteShutdownAndReenableSilent": true,
            "limits": "Deterministic sequences only; no hardware listening, acoustic latency, exhaustive arbitrary-polyphony or device-change acceptance."]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("calibration.json"))
        print("TRIAL_CALIBRATION rows=\(rows.count) largest_peak=\(rows.compactMap { $0["peak"] as? Float }.max() ?? 0) temporary_output=\(output.path)")
    }
}
