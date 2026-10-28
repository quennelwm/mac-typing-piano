import CryptoKit
import Foundation
import XCTest
@testable import PianoAudio

/// C-001B: read-only candidate inputs, manual/offline rendering only.
/// Writes numerical evidence and at most one PCM16 WAV per candidate.
final class CandidateBankTests: XCTestCase {
    private let rate = 48_000.0
    private let threshold: Float = 0.0000001
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    private var output: URL { root.appendingPathComponent("docs/evidence/C-001B") }
    private var input: URL { root.appendingPathComponent("Design/Audio/probes/A-001B") }
    private enum EvidenceError: Error { case invalidInput(String) }

    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func object(_ url: URL) throws -> [String: Any] {
        guard let result = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw EvidenceError.invalidInput(url.lastPathComponent)
        }
        return result
    }
    private func write(_ value: [String: Any], name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent(name), options: .atomic)
    }
    private func verifyInputSnapshot() throws -> [String: Any] {
        let snapshotData = try Data(contentsOf: output.appendingPathComponent("input-verification.json"))
        guard var verified = try JSONSerialization.jsonObject(with: snapshotData) as? [String: Any] else {
            throw EvidenceError.invalidInput("Snapshot JSON")
        }
        guard verified["status"] as? String == "passed", let files = verified["inputFiles"] as? [[String: Any]] else {
            throw EvidenceError.invalidInput("Run preflight before empirical tests")
        }
        let expectedSources: Set<String> = ["Code/Tests/PianoAudioTests/CandidateBankTests.swift",
                                            "Code/Scripts/verify_candidate_banks.py"]
        guard expectedSources.isSubset(of: Set(files.compactMap { $0["path"] as? String })) else {
            throw EvidenceError.invalidInput("Preflight must bind the current verification sources")
        }
        for file in files {
            guard let path = file["path"] as? String else { throw EvidenceError.invalidInput("Missing path") }
            let url = root.appendingPathComponent(path).resolvingSymlinksInPath()
            guard url.path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else {
                throw EvidenceError.invalidInput("Path escape")
            }
            let bytes = try Data(contentsOf: url)
            guard bytes.count == file["byteSize"] as? Int, digest(bytes) == file["sha256"] as? String else {
                throw EvidenceError.invalidInput("Input changed: \(path)")
            }
        }
        verified["_snapshotSHA256"] = digest(snapshotData)
        return verified
    }
    private func peak(_ values: [Float]) -> Float { values.reduce(0) { max($0, abs($1)) } }
    private func rms(_ values: [Float]) -> Double {
        sqrt(values.reduce(0) { $0 + Double($1) * Double($1) } / Double(max(1, values.count)))
    }
    private func nullable(_ value: Int?) -> Any { value.map { $0 as Any } ?? NSNull() }
    private func nullable(_ value: Double?) -> Any { value.map { $0 as Any } ?? NSNull() }
    private func nominal(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    private struct Pitch {
        let frequency: Double
        let correlation: Double
        let stride: Int
    }

    /// Prior-constrained normalized autocorrelation. This tests relative sample
    /// transposition; it deliberately does not certify absolute concert tuning.
    private func estimatePitch(_ samples: [Float], midi: Int) -> Pitch? {
        let expected = nominal(midi)
        let stride = max(1, min(8, Int(rate / (expected * 48))))
        let first = Int(rate * 0.08)
        let end = min(samples.count, Int(rate * 0.65))
        guard end > first + 1000 else { return nil }
        var signal: [Double] = []
        var offset = first
        while offset + stride <= end {
            var sum = 0.0
            for i in 0..<stride { sum += Double(samples[offset + i]) }
            signal.append(sum / Double(stride))
            offset += stride
        }
        let mean = signal.reduce(0, +) / Double(signal.count)
        signal = signal.map { $0 - mean }
        let effectiveRate = rate / Double(stride)
        let expectedLag = effectiveRate / expected
        let low = max(2, Int(floor(expectedLag * 0.85)))
        let high = Int(ceil(expectedLag * 1.18))
        guard high < signal.count - 16 else { return nil }
        var scores: [Double] = []
        for lag in low...high {
            var cross = 0.0, left = 0.0, right = 0.0
            for i in 0..<(signal.count - lag) {
                let a = signal[i], b = signal[i + lag]
                cross += a * b
                left += a * a
                right += b * b
            }
            scores.append(left > 0 && right > 0 ? cross / sqrt(left * right) : 0)
        }
        guard let best = scores.indices.max(by: { scores[$0] < scores[$1] }), best > 0, best + 1 < scores.count else { return nil }
        let a = scores[best - 1], b = scores[best], c = scores[best + 1]
        let divisor = a - 2 * b + c
        let correction = divisor == 0 ? 0 : 0.5 * (a - c) / divisor
        let lag = Double(low + best) + (abs(correction) <= 1 ? correction : 0)
        return Pitch(frequency: effectiveRate / lag, correlation: b, stride: stride)
    }

    func test00PitchEstimatorAgainstKnownSyntheticFrequencies() throws {
        let verified = try verifyInputSnapshot()
        var rows: [[String: Any]] = []
        for midi in 33...96 {
            let frequency = nominal(midi)
            let samples = (0..<36_000).map { Float(sin(2 * .pi * frequency * Double($0) / rate)) }
            let pitch = try XCTUnwrap(estimatePitch(samples, midi: midi))
            let errorCents = 1200 * log2(pitch.frequency / frequency)
            XCTAssertLessThan(abs(errorCents), 5, "Synthetic MIDI \(midi)")
            rows.append(["midi": midi, "knownHz": frequency, "estimatedHz": pitch.frequency,
                         "errorCents": errorCents, "correlation": pitch.correlation])
        }
        let maxError = rows.compactMap { $0["errorCents"] as? Double }.map(abs).max() ?? 0
        try write(["method": "Same estimator, pure generated sines, MIDI33...96", "toleranceCents": 5,
                   "maxAbsoluteErrorCents": maxError, "status": maxError < 5 ? "passed" : "failed",
                   "inputVerificationSHA256": verified["_snapshotSHA256"] ?? NSNull(),
                   "testSourceSHA256": digest(try Data(contentsOf: URL(fileURLWithPath: #filePath))),
                   "results": rows], name: "pitch-estimator-calibration.json")
    }

    func testKawaiCandidateOffline() throws { try measureCandidate(id: "vcsl-kawai") }
    func testSteinwayCandidateOffline() throws { try measureCandidate(id: "vcsl-steinway-b") }

    private func measureCandidate(id: String) throws {
        var report: [String: Any] = ["candidateID": id, "task": "C-001B", "inputState": "candidate",
                                    "timestampUTC": ISO8601DateFormatter().string(from: Date()),
                                    "renderSampleRate": rate, "renderChannels": 1,
                                    "thresholdAmplitude": threshold, "hardwareOutput": false]
        var failures: [String] = []
        var checkCount = 0
        func check(_ condition: Bool, _ message: String) {
            checkCount += 1
            if !condition { failures.append(message) }
        }
        var wavSamples: [Float] = []
        var segments: [[String: Any]] = []
        func appendSegment(_ name: String, _ samples: [Float], gain: Float, velocity: Int) {
            segments.append(["label": name, "startFrame": wavSamples.count, "frameCount": samples.count,
                             "startSeconds": Double(wavSamples.count) / rate,
                             "durationSeconds": Double(samples.count) / rate, "gain": gain, "velocity": velocity])
            wavSamples.append(contentsOf: samples)
            wavSamples.append(contentsOf: repeatElement(0, count: 2400))
        }
        let audio = SamplerAudio()
        defer { audio.shutdown() }
        do {
            let verified = try verifyInputSnapshot()
            report["inputVerificationSHA256"] = verified["_snapshotSHA256"]
            let implementationPaths: Set<String> = ["Code/Tests/PianoAudioTests/CandidateBankTests.swift",
                                                    "Code/Scripts/verify_candidate_banks.py"]
            report["verificationImplementation"] = (verified["inputFiles"] as? [[String: Any]])?.filter {
                implementationPaths.contains($0["path"] as? String ?? "")
            }
            let index = try object(input.appendingPathComponent("trial-index.json"))
            guard let trial = (index["trials"] as? [[String: Any]])?.first(where: { $0["id"] as? String == id }),
                  let bankPath = trial["bankFile"] as? String,
                  let covered = trial["coverageMIDI"] as? [Int],
                  let uncovered = trial["uncoveredMIDI"] as? [Int],
                  let roots = trial["rootMIDI"] as? [Int],
                  let zones = trial["zones"] as? [[String: Int]] else {
                throw EvidenceError.invalidInput("Trial fields")
            }
            let bank = input.appendingPathComponent(bankPath)
            report["bankPath"] = "Design/Audio/probes/A-001B/" + bankPath
            report["bankSHA256"] = digest(try Data(contentsOf: bank))
            report["loadedSelectors"] = ["program": 0, "bankMSB": 121, "bankLSB": 0]
            report["coveredMIDI"] = covered
            report["uncoveredMIDI"] = uncovered
            try audio.prepare(bankURL: bank, offline: true)
            report["loadStatus"] = "passed"
            check(audio.gain == 0.08 && audio.isOffline, "Initial gain/mode differs")

            var pitches: [Int: Pitch] = [:]
            var coverageRows: [[String: Any]] = []
            for midi in 33...96 {
                audio.panic()
                audio.noteOn(midi: UInt8(midi), velocity: 64)
                let samples = try audio.render(seconds: 0.75)
                let maximum = peak(samples)
                let onset = samples.firstIndex { abs($0) > threshold }
                let isCovered = covered.contains(midi)
                check(samples.allSatisfy(\.isFinite), "MIDI \(midi) nonfinite")
                check(isCovered ? maximum > threshold : maximum == 0,
                      "MIDI \(midi) expected \(isCovered ? "nonzero" : "exact silence"), peak \(maximum)")
                var row: [String: Any] = ["midi": midi, "declaredCovered": isCovered, "peak": maximum,
                                           "rms": rms(samples), "onsetFrameAboveThreshold": nullable(onset),
                                           "onsetSecondsAboveThreshold": nullable(onset.map { Double($0) / rate })]
                if isCovered {
                    if let pitch = estimatePitch(samples, midi: midi) {
                        pitches[midi] = pitch
                        row["estimatedHz"] = pitch.frequency
                        row["correlation"] = pitch.correlation
                        row["absoluteOffsetFromNominalCentsUncertified"] = 1200 * log2(pitch.frequency / nominal(midi))
                        row["analysisAverageStride"] = pitch.stride
                        check(pitch.correlation >= 0.6, "MIDI \(midi) pitch correlation below 0.6")
                    } else {
                        failures.append("MIDI \(midi) no interior pitch correlation peak")
                    }
                }
                coverageRows.append(row)
                audio.noteOff(midi: UInt8(midi))
                if roots.contains(midi) {
                    let tail = try audio.render(seconds: 0.8)
                    appendSegment("root MIDI \(midi), hold750ms + release800ms", samples + tail, gain: 0.08, velocity: 64)
                }
            }
            report["coverageMeasurements"] = coverageRows
            var pitchRelationships: [[String: Any]] = []
            for zone in zones {
                guard let rootMIDI = zone["rootMIDI"], let low = zone["lowMIDI"], let high = zone["highMIDI"],
                      let rootPitch = pitches[rootMIDI] else { continue }
                for neighbor in low...high where neighbor != rootMIDI {
                    guard let pitch = pitches[neighbor] else { continue }
                    let expectedCents = Double(neighbor - rootMIDI) * 100
                    let measuredCents = 1200 * log2(pitch.frequency / rootPitch.frequency)
                    let error = measuredCents - expectedCents
                    check(abs(error) <= 25, "Root \(rootMIDI) -> \(neighbor) relative pitch error \(error) cents")
                    pitchRelationships.append(["rootMIDI": rootMIDI, "neighborMIDI": neighbor,
                                                "rootEstimatedHz": rootPitch.frequency, "neighborEstimatedHz": pitch.frequency,
                                                "expectedCents": expectedCents, "measuredCents": measuredCents,
                                                "errorCents": error, "toleranceCents": 25])
                }
            }
            check(pitchRelationships.count == covered.count - roots.count, "Missing root/neighbor comparisons")
            report["pitchRelationships"] = pitchRelationships

            var releaseRows: [[String: Any]] = []
            for midi in roots {
                for hold in [0.05, 1.0, 5.0] {
                    audio.panic()
                    audio.noteOn(midi: UInt8(midi), velocity: 64)
                    let held = try audio.render(seconds: hold)
                    let before = peak(Array(held.suffix(480)))
                    audio.noteOff(midi: UInt8(midi))
                    let tail = try audio.render(seconds: 0.8)
                    let last = tail.lastIndex { abs($0) > threshold }
                    let earlyPeak = peak(Array(tail.prefix(4800)))
                    let latePeak = peak(Array(tail.suffix(9600)))
                    check(peak(held) > threshold, "MIDI \(midi) hold\(hold) no strike")
                    if before > threshold { check(earlyPeak > 0, "MIDI \(midi) hold\(hold) abrupt zero release") }
                    check(latePeak == 0, "MIDI \(midi) hold\(hold) tail remains after600ms")
                    releaseRows.append(["midi": midi, "holdSeconds": hold, "heldPeak": peak(held),
                                        "preReleaseLast10msPeak": before, "earlyRelease100msPeak": earlyPeak,
                                        "sampleAlreadySilentBeforeRelease": before <= threshold,
                                        "releaseLastFrameAboveThreshold": nullable(last),
                                        "releaseLastSecondsAboveThreshold": nullable(last.map { Double($0) / rate }),
                                        "release600to800msPeak": latePeak])
                    if midi == 60 { appendSegment("MIDI60 hold\(hold)s + release800ms", held + tail, gain: 0.08, velocity: 64) }
                }
            }
            report["releaseMeasurements"] = releaseRows

            audio.panic()
            var strikePeaks: [Float] = []
            var repeatPreview: [Float] = []
            for index in 0..<100 {
                audio.noteOn(midi: 60, velocity: 64)
                let held = try audio.render(seconds: 0.05)
                audio.noteOff(midi: 60)
                let tail = try audio.render(seconds: 0.05)
                let both = held + tail
                strikePeaks.append(peak(both))
                if index < 20 { repeatPreview.append(contentsOf: both) }
            }
            check(strikePeaks.allSatisfy { $0.isFinite && $0 > threshold && $0 < 0.9 }, "10Hz strikes invalid")
            let earlyMaximum = strikePeaks.prefix(10).max() ?? 0
            let lateMaximum = strikePeaks.suffix(10).max() ?? 0
            check(lateMaximum < earlyMaximum * 2, "10Hz repeats grew beyond2x initial10")
            report["retrigger"] = ["midi": 60, "velocity": 64, "hz": 10, "strikes": 100,
                                   "peak": strikePeaks.max() ?? 0, "first10Maximum": earlyMaximum,
                                   "last10Maximum": lateMaximum, "strikePeaks": strikePeaks]
            appendSegment("MIDI60 10Hz, first20 of100 measured strikes", repeatPreview, gain: 0.08, velocity: 64)

            var chords: [[String: Any]] = []
            for gain: Float in [0.08, 0.16] {
                audio.panic()
                audio.setGain(gain)
                // Mixer gain changes may ramp over render quanta. Measure the
                // boundary after silence has allowed the requested gain to settle.
                let settlePeak = peak(try audio.render(seconds: 0.1))
                check(settlePeak == 0, "Gain-settling interval contains stale audio")
                for midi in covered { audio.noteOn(midi: UInt8(midi), velocity: 127) }
                let samples = try audio.render(seconds: 1)
                check(samples.allSatisfy(\.isFinite) && peak(samples) > threshold && peak(samples) < 0.9,
                      "Covered chord gain\(gain) invalid/headroom below target")
                chords.append(["noteCommands": covered.count, "midi": covered, "gain": gain, "velocity": 127,
                               "peak": peak(samples), "rms": rms(samples), "renderSeconds": 1,
                               "gainSettlingSilenceSeconds": 0.1, "gainSettlingPeak": settlePeak])
                for midi in covered { audio.noteOff(midi: UInt8(midi)) }
                let tail = try audio.render(seconds: 0.8)
                if gain == 0.16 { appendSegment("All covered notes, gain0.16 velocity127, hold1s + release800ms", samples + tail, gain: gain, velocity: 127) }
            }
            report["chords"] = chords

            audio.noteOn(midi: 60, velocity: 127)
            _ = try audio.render(seconds: 0.1)
            audio.setGain(0)
            let zeroClears = peak(try audio.render(seconds: 0.2))
            audio.noteOn(midi: 60, velocity: 127)
            let zeroBlocks = peak(try audio.render(seconds: 0.2))
            audio.setGain(0.16)
            let noReplay = peak(try audio.render(seconds: 0.2))
            audio.noteOn(midi: 60, velocity: 64)
            let fresh = peak(try audio.render(seconds: 0.2))
            check(zeroClears == 0 && zeroBlocks == 0 && noReplay == 0 && fresh > threshold, "Gain0 mute/no-replay boundary")
            report["gainZero"] = ["existingVoiceClearedPeak": zeroClears, "mutedStrikePeak": zeroBlocks,
                                   "gainRaisedWithoutNewStrikePeak": noReplay, "freshStrikePeak": fresh]

            audio.panic()
            audio.setGain(0.08)
            audio.noteOn(midi: UInt8(roots[0]), velocity: 127)
            audio.noteOn(midi: 60, velocity: 64)
            _ = try audio.render(seconds: 0.1)
            audio.noteOff(midi: UInt8(roots[0]))
            _ = try audio.render(seconds: 0.05)
            audio.panic()
            let panicPeak = peak(try audio.render(seconds: 0.5))
            audio.noteOn(midi: 60, velocity: 64)
            let nextPeak = peak(try audio.render(seconds: 0.2))
            check(panicPeak == 0 && nextPeak > threshold, "Panic held/tail clearing and next strike")
            report["panic"] = ["postPanicPeak": panicPeak, "nextStrikePeak": nextPeak]

            audio.shutdown()
            var rejectedAfterShutdown = false
            do { _ = try audio.render(seconds: 0.1) } catch { rejectedAfterShutdown = true }
            try audio.prepare(bankURL: bank, offline: true)
            let blank = peak(try audio.render(seconds: 0.2))
            audio.noteOn(midi: 60, velocity: 64)
            let reloaded = peak(try audio.render(seconds: 0.2))
            check(rejectedAfterShutdown && blank == 0 && reloaded > threshold && audio.gain == 0.08, "Shutdown/reprepare")
            report["reprepare"] = ["renderRejectedWhileShutdown": rejectedAfterShutdown, "initialPeak": blank,
                                   "newStrikePeak": reloaded, "gain": audio.gain]
            audio.shutdown()

            check(wavSamples.count * 2 + 44 <= 10 * 1024 * 1024, "Per-bank WAV budget")
            let wavName = id + "-offline-representative.wav"
            try writeWAV(wavSamples, to: output.appendingPathComponent(wavName))
            let wavData = try Data(contentsOf: output.appendingPathComponent(wavName))
            report["representativeWAV"] = ["filename": wavName, "frames": wavSamples.count,
                                            "sha256": digest(wavData), "byteSize": wavData.count,
                                            "seconds": Double(wavSamples.count) / rate, "segments": segments,
                                            "normalization": "none", "format": "48kHz mono PCM16", "peakBeforePCM16": peak(wavSamples)]
            let finalSnapshot = try verifyInputSnapshot()
            guard finalSnapshot["_snapshotSHA256"] as? String == report["inputVerificationSHA256"] as? String else {
                throw EvidenceError.invalidInput("Snapshot changed during render")
            }
            report["inputSnapshotUnchangedAfterRender"] = true
        } catch {
            failures.append("Execution error: \(error)")
            report["executionError"] = String(describing: error)
        }
        report["checkCount"] = checkCount
        report["failures"] = failures
        report["status"] = failures.isEmpty ? "passed" : "failed"
        try write(report, name: id + "-results.json")
        print("CANDIDATE_AUDIO_RESULT id=\(id) status=\(failures.isEmpty ? "passed" : "failed") checks=\(checkCount) failures=\(failures.count)")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    private func writeWAV(_ samples: [Float], to url: URL) throws {
        var data = Data()
        func ascii(_ value: String) { data.append(contentsOf: value.utf8) }
        func le<T: FixedWidthInteger>(_ value: T) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        ascii("RIFF"); le(UInt32(36 + samples.count * 2)); ascii("WAVEfmt "); le(UInt32(16))
        le(UInt16(1)); le(UInt16(1)); le(UInt32(48_000)); le(UInt32(96_000)); le(UInt16(2)); le(UInt16(16))
        ascii("data"); le(UInt32(samples.count * 2))
        for sample in samples { le(Int16((max(-1, min(1, sample)) * 32767).rounded())) }
        try data.write(to: url, options: .atomic)
    }
}
