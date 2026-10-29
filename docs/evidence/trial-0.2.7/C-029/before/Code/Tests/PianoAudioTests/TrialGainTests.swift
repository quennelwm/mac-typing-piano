import XCTest
@testable import PianoAudio

final class TrialGainTests: XCTestCase {
    func testSourceCalibrationCanUseUnityMixerAndSamplerGainWithoutLegacyClamp() {
        let audio = SamplerAudio()
        audio.configureGain(maximum: 1, samplerDB: 12)
        audio.setGain(0.5)
        XCTAssertEqual(audio.gain, 0.5)
        XCTAssertEqual(audio.samplerGainDB, 12)
        audio.setGain(2); XCTAssertEqual(audio.gain, 1)
        audio.setGain(.nan); XCTAssertEqual(audio.gain, 1)
        audio.configureGain(maximum: 0.16, samplerDB: 0)
        XCTAssertEqual(audio.gain, 0.16)
        XCTAssertEqual(audio.samplerGainDB, 0)
    }
    func testStereoOfflineRenderingReturnsBothChannelsAndFrameCount() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let audio = SamplerAudio(renderChannelCount: 2)
        defer { audio.shutdown() }
        try audio.prepare(bankURL: root.appendingPathComponent("Assets/placeholder-original.sf2"), offline: true)
        audio.noteOn(midi: 60, velocity: 64)
        let samples = try audio.render(seconds: 0.1)
        XCTAssertEqual(samples.count, 9600)
        XCTAssertGreaterThan(stride(from: 0, to: samples.count, by: 2).map { abs(samples[$0]) }.max() ?? 0, 0)
        XCTAssertGreaterThan(stride(from: 1, to: samples.count, by: 2).map { abs(samples[$0]) }.max() ?? 0, 0)
    }

}
