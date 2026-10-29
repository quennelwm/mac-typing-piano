import XCTest
import AVFoundation
@testable import PianoAudio

final class RuntimeDiagnosticsTests: XCTestCase {
    func testMeterMeasuresOnlyProvidedBufferAndRetainsAggregates() throws {
        let meter = OutputMeter()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16))
        buffer.frameLength = 16
        for channel in 0..<2 { for frame in 0..<16 { buffer.floatChannelData![channel][frame] = 0 } }
        buffer.floatChannelData![1][7] = -0.5
        meter.consume(buffer)
        let result = meter.snapshot()
        XCTAssertEqual(result["outputTapCallbackCount"] as? Int, 1)
        XCTAssertEqual(result["outputTapFrameCount"] as? UInt64, 16)
        XCTAssertEqual(result["outputTapPeak"] as? Float, 0.5)
        XCTAssertEqual(result["outputTapInspectedSamples"] as? UInt64, 32)
        XCTAssertNotNil(result["outputTapLastCallbackUptime"] as? Double)
        XCTAssertEqual(result["acousticProof"] as? Bool, false)
    }
    func testUnpreparedEngineDoesNotPretendToHaveOutput() {
        let audio = SamplerAudio()
        let d = audio.runtimeDiagnostics()
        XCTAssertEqual(d["engineRunning"] as? Bool, false)
        XCTAssertEqual(d["samplerLoaded"] as? Bool, false)
        XCTAssertTrue(d["currentOutputDeviceID"] is NSNull)
        XCTAssertEqual(d["meterStatus"] as? String, "not-installed")
        audio.noteOn(midi: 60, velocity: 80)
        XCTAssertEqual(audio.runtimeDiagnostics()["noteOnRequests"] as? Int, 1)
        XCTAssertEqual(audio.runtimeDiagnostics()["noteOnAccepted"] as? Int, 0)
    }
    func testIdentityRejectsUnrelatedAndRetiredEngines() {
        let identity = EngineNotificationIdentity()
        let old = NSObject(), current = NSObject(), unrelated = NSObject()
        identity.set(old)
        XCTAssertTrue(identity.matches(old))
        identity.set(current)
        XCTAssertFalse(identity.matches(old)); XCTAssertFalse(identity.matches(unrelated))
        XCTAssertTrue(identity.matches(current))
        identity.set(nil); XCTAssertFalse(identity.matches(current)); XCTAssertFalse(identity.matches(nil))
    }
    func testMockDiagnosticsStayUnknown() {
        let mock = AudioSelectionTests.Engine()
        XCTAssertEqual(mock.runtimeDiagnostics()["diagnosticsSupport"] as? String, "unsupported")
        XCTAssertNil(mock.runtimeDiagnostics()["engineRunning"])
    }
}
