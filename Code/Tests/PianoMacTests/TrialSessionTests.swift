import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class TrialSessionTests: XCTestCase {
    func testContinuousSessionHasNoTimeoutButRetainsSafetyStops() {
        XCTAssertNil(InputSessionDuration.continuous.stopReason(elapsed: 86_400, secureInput: false, permissionValid: true))
        XCTAssertNotNil(InputSessionDuration.test60Seconds.stopReason(elapsed: 60, secureInput: false, permissionValid: true))
        XCTAssertNotNil(InputSessionDuration.continuous.stopReason(elapsed: 1, secureInput: true, permissionValid: true))
        XCTAssertNotNil(InputSessionDuration.continuous.stopReason(elapsed: 1, secureInput: false, permissionValid: false))
    }
    func testStartTrialEnablesAudioOverlayAndPauseFullyCleans() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        let preferences = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preferences.json")
        defer { try? FileManager.default.removeItem(at: preferences.deletingLastPathComponent()) }
        let controller = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")), sources: AudioSource.available(root: root, bundled: false), preferencesURL: preferences, input: input, audioEngine: engine, installStatusItem: false, secureInputCheck: { false }, permissionCheck: { true }, dockVisibilityCheck: { _, _ in .hidden })
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        controller.startTrial()
        XCTAssertEqual(input.mode, .global)
        XCTAssertEqual(input.duration, .continuous)
        XCTAssertTrue(engine.prepared); XCTAssertTrue(controller.integrationState.soundEnabled)
        input.onEvent?(.init("keyA", .down))
        XCTAssertEqual(controller.integrationState.floatingNotes, 1)
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertEqual(input.mode, .global) // Closing a help/console window cannot end background work.
        input.onStop?("permission revoked")
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        XCTAssertFalse(controller.integrationState.soundEnabled)
        XCTAssertEqual(controller.integrationState.activeKeys, 0)
        XCTAssertEqual(controller.integrationState.floatingNotes, 0)
        input.fail = true
        controller.startTrial()
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        XCTAssertFalse(controller.integrationState.soundEnabled)
        input.fail = false; engine.failPrepare = true
        controller.startTrial()
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        XCTAssertEqual(controller.integrationState.activeKeys, 0)
    }
}
