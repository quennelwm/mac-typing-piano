import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class HeightIntegrationTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func make(_ url: URL, alertVolume: AlertVolumeAdapter? = nil) throws -> (ProbeController, ControllerIntegrationTests.Input, ControllerIntegrationTests.Engine) {
        _ = NSApplication.shared
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        let c = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename)), sources: AudioSource.available(root: root, bundled: false), preferencesURL: url, input: input, audioEngine: engine, installStatusItem: false, alertVolume: alertVolume, secureInputCheck: { false }, permissionCheck: { true }, dockVisibilityCheck: { _, _ in .hidden })
        c.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        return (c, input, engine)
    }
    func testResizeKeepsHeldReleaseAudioAndCustomMappingInAllModes() throws {
        for mode in ["running", "muted", "paused"] {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: dir) }
            let (c, input, engine) = try make(dir.appendingPathComponent("prefs.json"))
            defer { c.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            let base = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
            var custom = CustomKeymap(defaultMapping: base); try custom.swap(key: "keyG", to: 53)
            try c.saveCustomKeymap(custom)
            if mode != "paused" { c.start(global: true) }
            if mode == "running" { c.toggleSound() }
            c.toggleOverlay(); input.onEvent?(.init("keyG", .down))
            let active = c.integrationState.activeKeys, panics = engine.panics, offs = engine.offs.count
            let modeBefore = input.mode, prepared = engine.prepared, downs = engine.downs.count, shutdowns = engine.shutdowns
            let version = c.runtimeDiagnostics()["mappingVersion"] as? String
            for value in [0.5, 1, 1.8, 1.23] { c.changeHeight(value) }
            XCTAssertEqual(input.mode, modeBefore); XCTAssertEqual(engine.prepared, prepared)
            XCTAssertEqual(engine.panics, panics); XCTAssertEqual(engine.offs.count, offs)
            XCTAssertEqual(engine.shutdowns, shutdowns); XCTAssertEqual(engine.downs.count, downs)
            XCTAssertEqual(c.integrationState.activeKeys, active)
            XCTAssertEqual(c.runtimeDiagnostics()["mappingVersion"] as? String, version)
            XCTAssertEqual(c.runtimeDiagnostics()["overlayRequested"] as? Bool, true)
            c.flushPreferences()
            XCTAssertEqual(try AppPreferences.load(from: dir.appendingPathComponent("prefs.json")).heightScale, 1.23)
            input.onEvent?(.init("keyG", .up)); XCTAssertEqual(c.integrationState.activeKeys, 0)
            if mode == "running" { XCTAssertEqual(engine.offs.last, 53) }
        }
    }
    func testDebounceFailureRetryExitFlushAndRelaunch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("prefs.json")
        var initial = AppPreferences(); initial.setVolume(0.77); initial.showKeyLabels = false; try initial.save(to: url)
        let (c, _, _) = try make(url)
        c.changeHeight(0.5); c.changeHeight(1.8)
        XCTAssertEqual(try AppPreferences.load(from: url).heightScale, 1) // No per-drag synchronous write.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        XCTAssertEqual(try AppPreferences.load(from: url).heightScale, 1.8)
        try FileManager.default.removeItem(at: url); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        c.changeHeight(0.7); c.flushPreferences()
        XCTAssertEqual(c.runtimeDiagnostics()["preferencesSavePending"] as? Bool, true)
        XCTAssertNotNil(c.runtimeDiagnostics()["preferencesSaveError"] as? String)
        XCTAssertEqual(c.runtimeDiagnostics()["heightScale"] as? Double, 0.7)
        try FileManager.default.removeItem(at: url)
        c.changeHeight(1.37); c.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        let saved = try AppPreferences.load(from: url)
        XCTAssertEqual(saved.heightScale, 1.37); XCTAssertEqual(saved.volume, 0.77); XCTAssertFalse(saved.showKeyLabels)
        let (reopened, input, engine) = try make(url)
        XCTAssertEqual(reopened.runtimeDiagnostics()["heightScale"] as? Double, 1.37)
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        reopened.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }
    func testMenuActualSliderActionAndPercent() {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 0.7, installStatusItem: false)
        var height = 0.0, closed = false
        menu.onHeight = { height = $0 }; menu.onDidClose = { closed = true }
        menu.heightSlider.doubleValue = 1.8
        XCTAssertTrue(menu.heightSlider.sendAction(menu.heightSlider.action, to: menu.heightSlider.target))
        XCTAssertEqual(height, 1.8); XCTAssertEqual(menu.heightPercentage.stringValue, "180%")
        XCTAssertEqual(menu.slider.doubleValue, 0.7)
        menu.menuDidClose(menu.menu); XCTAssertTrue(closed)
    }
    func testFailedFinalSaveCanCancelExitWithoutStoppingOrRestoringState() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("prefs.json")
        var original = AppPreferences(); original.setVolume(0.67); try original.save(to: url)
        let originalBytes = try Data(contentsOf: url)
        let alertStorage = AlertVolumeTests.Storage()
        let alerts = AlertVolumeAdapter(storage: alertStorage)
        XCTAssertEqual(alerts.mute(confirmed: true), .muted)
        let (c, input, engine) = try make(url, alertVolume: alerts)
        c.start(global: true); c.toggleSound(); input.onEvent?(.init("keyG", .down))
        let backup = dir.appendingPathComponent("original.json")
        try FileManager.default.moveItem(at: url, to: backup)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        c.changeHeight(1.8)
        let panics = engine.panics, shutdowns = engine.shutdowns
        var prompts = 0
        c.confirmUnsavedPreferencesExit = { _ in prompts += 1; return false }
        XCTAssertEqual(c.applicationShouldTerminate(NSApp), .terminateCancel)
        XCTAssertEqual(prompts, 1); XCTAssertEqual(input.mode, .global); XCTAssertTrue(engine.prepared)
        XCTAssertEqual(alertStorage.writes, [0]); XCTAssertEqual(alertStorage.value, 0)
        XCTAssertEqual(c.integrationState.activeKeys, 1); XCTAssertEqual(engine.panics, panics); XCTAssertEqual(engine.shutdowns, shutdowns)
        XCTAssertEqual(try Data(contentsOf: backup), originalBytes)
        c.confirmUnsavedPreferencesExit = { _ in prompts += 1; return true }
        XCTAssertEqual(c.applicationShouldTerminate(NSApp), .terminateNow)
        XCTAssertEqual(input.mode, .global) // Teardown belongs only to the actual willTerminate.
        try FileManager.default.removeItem(at: url); try FileManager.default.moveItem(at: backup, to: url)
        c.confirmUnsavedPreferencesExit = { _ in XCTFail("Successful save must not prompt"); return false }
        XCTAssertEqual(c.applicationShouldTerminate(NSApp), .terminateNow)
        XCTAssertEqual(try AppPreferences.load(from: url).heightScale, 1.8)
        XCTAssertEqual(try AppPreferences.load(from: url).volume, 0.67)
        c.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }
    func testVolumeAndLabelsOnlySaveFailureRemainsDirtyAndRetries() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("prefs.json")
        let (c, _, _) = try make(url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        c.changeVolume(0.9); c.toggleLabels()
        XCTAssertEqual(c.runtimeDiagnostics()["heightScale"] as? Double, 1)
        XCTAssertEqual(c.runtimeDiagnostics()["preferencesSavePending"] as? Bool, true)
        c.confirmUnsavedPreferencesExit = { _ in false }
        XCTAssertEqual(c.applicationShouldTerminate(NSApp), .terminateCancel)
        try FileManager.default.removeItem(at: url)
        c.flushPreferences() // The same operation is wired to menuDidClose.
        XCTAssertEqual(c.runtimeDiagnostics()["preferencesSavePending"] as? Bool, false)
        let saved = try AppPreferences.load(from: url)
        XCTAssertEqual(saved.volume, 0.9); XCTAssertFalse(saved.showKeyLabels); XCTAssertEqual(saved.heightScale, 1)
        c.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }
    func testGeometryLabelsAndFloatingBoundsAtAllHeightsIncludingNarrowPreview() throws {
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        for width in [900.0, 1000, 1264, 1496, 1904] {
            for scale in [0.5, 1, 1.8] {
                let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: width, height: 256))
                view.automaticAnimation = false; view.setHeightScale(scale)
                XCTAssertEqual(view.frame.height, 144 + 112 * scale)
                XCTAssertEqual(view.labelMetrics.count, 64)
                XCTAssertTrue(view.labelMetrics.allSatisfy { $0.insideKey && !$0.overlap && $0.missingGlyphs == 0 })
                for reduced in [false, true] {
                    view.resetEffects(); view.reducedMotion = reduced
                    var coordinator = NoteCoordinator(mapping: mapping)
                    for key in mapping.keys {
                        _ = coordinator.consume(.init(key.physicalKeyID, .down))
                        view.strike(try XCTUnwrap(coordinator.lastStrike), at: 0)
                    }
                    for time in [0.0, 0.1, 0.199, 0.2, 0.475, 0.949, 0.95] {
                        view.advanceAnimations(at: time)
                        XCTAssertTrue(view.floatingInkBounds.allSatisfy { view.bounds.contains($0) }, "width=\(width) scale=\(scale) t=\(time)")
                        if time >= (reduced ? 0.2 : 0.95) { XCTAssertEqual(view.floatingCount, 0) }
                    }
                }
            }
        }
    }
}
