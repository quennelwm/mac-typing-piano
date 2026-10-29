import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class ControllerIntegrationTests: XCTestCase {
    final class Input: InputMonitoring {
        var mode: InputMonitor.Mode = .stopped
        var onEvent: ((NormalizedKeyEvent) -> Void)?
        var onStop: ((String) -> Void)?
        var fail = false
        var duration: InputSessionDuration = .test60Seconds
        func start(global: Bool, duration: InputSessionDuration) throws { if fail { throw ProbeError.invalid("permission test failure") }; self.duration = duration; mode = global ? .global : .local }
        func stop() { mode = .stopped }
    }
    final class Engine: AuditionEngine {
        var downs: [UInt8] = []
        var shutdowns = 0
        var prepared = false
        var failPrepare = false
        func prepare(bankURL: URL, offline: Bool) throws { prepared = true; if failPrepare { throw ProbeError.invalid("audio failure") } }
        func shutdown() { shutdowns += 1; prepared = false }
        func setGain(_ gain: Float) {}
        func noteOn(midi: UInt8, velocity: UInt8) { downs.append(midi) }
        func noteOff(midi: UInt8) {}
        func panic() {}
    }
    func testFirstStrikeAfterStartRendersAndSwitchClearsWithoutStartingAudio() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let input = Input(), engine = Engine()
        let preference = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preferences.json")
        defer { try? FileManager.default.removeItem(at: preference.deletingLastPathComponent()) }
        let controller = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")), sources: AudioSource.available(root: root, bundled: false), preferencesURL: preference, input: input, audioEngine: engine, installStatusItem: false)
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        controller.showControlWindow(activate: false)
        controller.start(global: false)
        input.onEvent?(.init("keyA", .down))
        XCTAssertEqual(controller.integrationState.previewFloatingNotes, 1)
        controller.toggleOverlay()
        XCTAssertEqual(controller.integrationState.floatingNotes, 0) // Showing never replays.
        input.onEvent?(.init("keyA", .up))
        input.onEvent?(.init("keyA", .down))
        XCTAssertEqual(controller.integrationState.floatingNotes, 1)
        XCTAssertEqual(controller.integrationState.activeKeys, 1)
        XCTAssertFalse(engine.prepared)
        input.onEvent?(.init("keyA", .down))
        XCTAssertEqual(controller.integrationState.floatingNotes, 1)
        controller.toggleSound()
        XCTAssertTrue(engine.prepared)
        controller.selectSource("vcsl-kawai")
        XCTAssertFalse(engine.prepared)
        XCTAssertEqual(controller.integrationState.activeKeys, 0)
        XCTAssertEqual(controller.integrationState.floatingNotes, 0)
        XCTAssertFalse(controller.integrationState.soundEnabled)
        XCTAssertEqual(input.mode, .stopped)
        input.onEvent?(.init("keyS", .down))
        XCTAssertEqual(controller.integrationState.activeKeys, 0)
        controller.stopAll()
        XCTAssertEqual(input.mode, .stopped)
        controller.start(global: false); controller.toggleOverlay()
        input.onEvent?(.init("keyA", .down))
        XCTAssertEqual(controller.integrationState.floatingNotes, 1)
    }
}
