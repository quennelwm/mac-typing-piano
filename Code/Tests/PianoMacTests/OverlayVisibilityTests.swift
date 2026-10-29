import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class OverlayVisibilityTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func make(secure: @escaping () -> Bool = { false }, dock: @escaping () -> DockVisibility = { .hidden }) throws -> (ProbeController, ControllerIntegrationTests.Input, ControllerIntegrationTests.Engine, URL) {
        _ = NSApplication.shared
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let prefs = dir.appendingPathComponent("preferences.json")
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        let controller = try ProbeController(mapping: mapping, sources: AudioSource.available(root: root, bundled: false), preferencesURL: prefs, input: input, audioEngine: engine, installStatusItem: false, secureInputCheck: secure, dockVisibilityCheck: { _, _ in dock() })
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        addTeardownBlock {
            controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            try? FileManager.default.removeItem(at: dir)
        }
        return (controller, input, engine, prefs)
    }
    private func alpha(_ c: ProbeController) -> CGFloat { c.runtimeDiagnostics()["overlayAlpha"] as? CGFloat ?? -1 }
    private func visible(_ c: ProbeController) -> Bool { c.runtimeDiagnostics()["overlayVisible"] as? Bool ?? false }
    func testRepeatedStaticShowHideAndOrdinaryPauseNeverStartServices() throws {
        let (c, input, engine, _) = try make()
        for _ in 0..<5 {
            c.toggleOverlay(); XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
            c.stopAll(); XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
            c.toggleOverlay(); XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
        }
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared); XCTAssertTrue(engine.downs.isEmpty)
    }
    func testSafetyReasonsBlockStaticDisplayAndClearWithoutRestartingInput() throws {
        var secure = true
        let (c, input, engine, _) = try make(secure: { secure })
        c.toggleOverlay(); XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
        XCTAssertTrue((c.runtimeDiagnostics()["overlayStatus"] as? String ?? "").contains("安全输入"))
        secure = false; c.dockTick(); XCTAssertEqual(alpha(c), 0)
        c.start(global: false); XCTAssertEqual(input.mode, .local)
        secure = true; c.dockTick(); XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(visible(c))
        c.setSessionBlocked(true); secure = false; c.dockTick(); XCTAssertFalse(visible(c))
        c.setSessionBlocked(false); XCTAssertFalse(visible(c)); XCTAssertEqual(alpha(c), 0)
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
    }
    func testDockSuppressesImmediatelyThenHiddenAndUnknownRecoverWithoutServices() throws {
        var dock = DockVisibility.visible
        let (c, input, engine, _) = try make(dock: { dock })
        c.start(global: true)
        c.toggleOverlay(); XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
        dock = .hidden; c.dockTick()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        XCTAssertEqual(alpha(c), 1); XCTAssertTrue(visible(c))
        dock = .visible; c.dockTick()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        XCTAssertEqual(alpha(c), 0); XCTAssertFalse(visible(c))
        dock = .unknown; c.dockTick()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertEqual(alpha(c), 1); XCTAssertTrue(visible(c))
        XCTAssertTrue((c.runtimeDiagnostics()["overlayStatus"] as? String ?? "").contains("未知"))
        c.toggleOverlay(); dock = .hidden; c.dockTick(); XCTAssertFalse(visible(c))
        XCTAssertEqual(input.mode, .global); XCTAssertFalse(engine.prepared)
    }
    func testExistingCustomConfigurationChangesPitchOnRelaunch() throws {
        let (_, _, _, prefs) = try make()
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        var notes = Dictionary(uniqueKeysWithValues: mapping.keys.map { ($0.physicalKeyID, $0.midiNote) })
        notes["keyA"] = 60; notes["keyG"] = 53
        let object: [String: Any] = ["schemaVersion": 1, "baseMappingVersion": KeyMapping.defaultMappingVersion, "notes": notes]
        try FileManager.default.createDirectory(at: prefs.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object).write(to: prefs.deletingLastPathComponent().appendingPathComponent("custom-keymap.json"))
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        let controller = try ProbeController(mapping: mapping, sources: AudioSource.available(root: root, bundled: false), preferencesURL: prefs, input: input, audioEngine: engine, installStatusItem: false, secureInputCheck: { false }, permissionCheck: { true }, dockVisibilityCheck: { _, _ in .hidden })
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        controller.start(global: false); controller.toggleSound()
        input.onEvent?(.init("keyG", .down))
        XCTAssertEqual(engine.downs.last, 53)
    }
    func testSavingCustomMappingPreservesRunningMutedAndPausedStates() throws {
        for mode in ["running", "muted", "paused"] {
            let (c, input, engine, prefs) = try make()
            let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
            var custom = CustomKeymap(defaultMapping: mapping); try custom.swap(key: "keyG", to: 53)
            c.toggleOverlay()
            if mode != "paused" { c.start(global: true) }
            if mode == "running" { c.toggleSound() }
            input.onEvent?(.init("keyG", .down)); input.onEvent?(.init("capsLock", .pulse))
            let wasMode = input.mode, wasSound = c.integrationState.soundEnabled, wasPrepared = engine.prepared
            let shutdowns = engine.shutdowns
            try c.saveCustomKeymap(custom)
            XCTAssertEqual(input.mode, wasMode); XCTAssertEqual(c.integrationState.soundEnabled, wasSound)
            XCTAssertEqual(engine.prepared, wasPrepared); XCTAssertEqual(engine.shutdowns, shutdowns)
            XCTAssertEqual(c.integrationState.activeKeys, 0); XCTAssertEqual(c.integrationState.floatingNotes, 0)
            XCTAssertEqual(alpha(c), mode == "paused" ? 0 : 1); XCTAssertEqual(input.discardedEpochs, 1)
            let stored = try JSONDecoder().decode(CustomKeymap.self, from: Data(contentsOf: prefs.deletingLastPathComponent().appendingPathComponent("custom-keymap.json")))
            XCTAssertEqual(stored, custom)
            if mode != "paused" {
                input.onEvent?(.init("keyG", .down)); XCTAssertEqual(c.integrationState.activeKeys, 0)
                input.onEvent?(.init("keyG", .up)); input.onEvent?(.init("keyG", .down))
                XCTAssertEqual(c.integrationState.activeKeys, 1)
                if mode == "running" { XCTAssertEqual(engine.downs.last, 53) }
                input.onEvent?(.init("capsLock", .down))
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
                XCTAssertEqual(c.integrationState.activeKeys, 2) // Old pulse callback cannot release new presses.
            }
        }
    }
    func testCapturedQueuedReleaseBeforeSaveDoesNotSwallowNextRealDown() throws {
        let (c, input, engine, _) = try make()
        let base = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        var custom = CustomKeymap(defaultMapping: base); try custom.swap(key: "keyG", to: 53)
        c.start(global: true); c.toggleSound()
        input.onEvent?(.init("keyG", .down))
        input.enqueue(.init("keyG", .up)) // Captured before save, delivery still on the main queue.
        try c.saveCustomKeymap(custom)
        let delivered = expectation(description: "new down delivered after mapping transaction")
        input.enqueue(.init("keyG", .down)) { delivered.fulfill() }
        wait(for: [delivered], timeout: 2)
        XCTAssertEqual(c.integrationState.activeKeys, 1)
        XCTAssertEqual(engine.downs.last, 53)
    }
    func testRealWriteFailureLeavesRunningMappingAndHeldStateUntouched() throws {
        let (c, input, engine, prefs) = try make()
        let base = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        var custom = CustomKeymap(defaultMapping: base); try custom.swap(key: "keyG", to: 53)
        c.start(global: true); c.toggleSound(); input.onEvent?(.init("keyG", .down))
        let file = prefs.deletingLastPathComponent().appendingPathComponent("custom-keymap.json")
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        XCTAssertThrowsError(try c.saveCustomKeymap(custom))
        XCTAssertEqual(c.runtimeDiagnostics()["mappingVersion"] as? String, KeyMapping.defaultMappingVersion)
        XCTAssertEqual(input.mode, .global); XCTAssertTrue(engine.prepared); XCTAssertEqual(c.integrationState.activeKeys, 1)
        XCTAssertEqual(input.discardedEpochs, 0)
        input.onEvent?(.init("keyG", .up)); input.onEvent?(.init("keyG", .down)); XCTAssertEqual(engine.downs.last, 60)
    }
    func testClearingSleepDoesNotClearConcurrentLockOrSecureInput() throws {
        var secure = false
        let (c, input, _, _) = try make(secure: { secure })
        c.toggleOverlay()
        c.setSessionBlocked(true, reason: "lock"); c.setSessionBlocked(true, reason: "sleep")
        c.setSessionBlocked(false, reason: "sleep"); XCTAssertFalse(visible(c))
        secure = true; c.setSessionBlocked(false, reason: "lock"); XCTAssertFalse(visible(c))
        secure = false; c.dockTick(); XCTAssertFalse(visible(c)); XCTAssertEqual(input.mode, .stopped)
    }
    func testPlayableLabelsAndFloatingInkFitAllWidthsAndReducedMotion() throws {
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        XCTAssertEqual(PianoView.floatingFontSize, 24)
        for width in [1264.0, 1496, 1904] {
            for reduced in [false, true] {
                let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: width, height: AdaptiveOverlay.canvasHeight))
                view.automaticAnimation = false; view.reducedMotion = reduced
                XCTAssertTrue(view.labelMetrics.allSatisfy { $0.insideKey && $0.missingGlyphs == 0 && !$0.overlap })
                var coordinator = NoteCoordinator(mapping: mapping)
                for key in mapping.keys {
                    _ = coordinator.consume(.init(key.physicalKeyID, .down))
                    view.strike(try XCTUnwrap(coordinator.lastStrike), at: 0)
                }
                for ms in stride(from: 0, through: 960, by: 20) {
                    view.advanceAnimations(at: Double(ms) / 1000)
                    XCTAssertTrue(view.floatingInkBounds.allSatisfy { view.bounds.contains($0) })
                    XCTAssertTrue(view.floatingPresentations.allSatisfy { abs($0.driftX) <= 8 && $0.rise <= 100 })
                }
                XCTAssertEqual(view.floatingCount, 0); XCTAssertFalse(view.animationTimerRunning)
            }
        }
    }
}
