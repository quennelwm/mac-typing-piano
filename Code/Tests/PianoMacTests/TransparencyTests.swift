import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class TransparencyTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func mapping() throws -> KeyMapping { try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename)) }
    func testOldInvalidAndRoundTripPreferences() throws {
        for extra in ["", ",\"transparency\":null", ",\"transparency\":\"bad\""] {
            let p = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"volume\":0.7,\"heightScale\":1.8,\"showKeyLabels\":false\(extra)}".utf8))
            XCTAssertEqual(p.transparency, 0.15); XCTAssertEqual(p.volume, 0.7); XCTAssertEqual(p.heightScale, 1.8); XCTAssertFalse(p.showKeyLabels)
        }
        var p = AppPreferences(); p.setTransparency(-4); XCTAssertEqual(p.transparency, 0)
        p.setTransparency(4); XCTAssertEqual(p.transparency, 1)
        p.setTransparency(0.546); p.setTransparency(.nan); p.setTransparency(.infinity)
        let saved = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(saved.transparency, 0.55)
    }
    func testSliderAndAccessibilityOverridePreserveSetting() {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 0.7, installStatusItem: false)
        var values: [Double] = []; menu.onTransparency = { values.append($0) }
        menu.transparencySlider.doubleValue = 0.5
        XCTAssertTrue(menu.transparencySlider.sendAction(menu.transparencySlider.action, to: menu.transparencySlider.target))
        XCTAssertEqual(values, [0.5]); XCTAssertEqual(menu.transparencyPercentage.stringValue, "50%")
        menu.setTransparency(0.5, reduced: true); XCTAssertFalse(menu.transparencySlider.isEnabled)
        _ = menu.transparencySlider.sendAction(menu.transparencySlider.action, to: menu.transparencySlider.target)
        XCTAssertEqual(values, [0.5])
        menu.setTransparency(0.5, reduced: false); XCTAssertTrue(menu.transparencySlider.isEnabled)
        XCTAssertEqual(menu.transparencySlider.doubleValue, 0.5); XCTAssertEqual(menu.slider.doubleValue, 0.7)
    }
    func testMaterialAlphaEndpointsAllKeysAndReducedTransparencyRestore() throws {
        let mapping = try mapping()
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        view.showLabels = false; view.automaticAnimation = false
        for value in [0.0, 0.15, 0.5, 1] {
            view.setTransparency(value)
            let bitmap = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
            for key in PianoGeometry.quietIvory(mapping: mapping, width: 1264) {
                let y = 144 + key.rect.minY + key.rect.height * (key.isBlack ? 0.5 : 0.8)
                XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: Int(key.rect.midX * 2), y: Int(y * 2))).alphaComponent, 1 - value, accuracy: 0.006)
            }
            if value == 1 {
                let data = try XCTUnwrap(bitmap.bitmapData)
                XCTAssertTrue((0..<(bitmap.pixelsWide * bitmap.pixelsHigh)).allSatisfy { data[$0 * 4 + 3] == 0 }, "100% must leave no base/highlight/shadow residue")
            }
        }
        view.reducedTransparency = true
        XCTAssertEqual(view.transparency, 1); XCTAssertEqual(view.effectiveMaterialOpacity, 1)
        let bitmap = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
        XCTAssertEqual(bitmap.colorAt(x: 30, y: 450)?.alphaComponent, 1)
        view.reducedTransparency = false; XCTAssertEqual(view.effectiveMaterialOpacity, 0)
    }
    func testLabelsAndFloatingNotesRemainWhenMaterialIsInvisible() throws {
        let mapping = try mapping()
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        view.automaticAnimation = false
        var c = NoteCoordinator(mapping: mapping); _ = c.consume(.init("keyG", .down))
        view.strike(try XCTUnwrap(c.lastStrike), at: 0); view.advanceAnimations(at: 0.475)
        view.setTransparency(0)
        let opaque = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
        view.setTransparency(1)
        let clear = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
        let count = opaque.bytesPerRow * 280 // Headroom only; contains floating note, no material.
        XCTAssertEqual(Data(bytes: try XCTUnwrap(opaque.bitmapData), count: count), Data(bytes: try XCTUnwrap(clear.bitmapData), count: count))
        for key in PianoGeometry.quietIvory(mapping: mapping, width: 1264) {
            var alpha: CGFloat = 0
            for y in Int((144 + key.rect.maxY - 16) * 2)..<Int((144 + key.rect.maxY) * 2) {
                for x in Int(key.rect.minX * 2)..<Int(key.rect.maxX * 2) { alpha = max(alpha, clear.colorAt(x: x, y: y)?.alphaComponent ?? 0) }
            }
            // Thin glyphs need not fully cover any pixel; antialiasing lowers their peak alpha.
            XCTAssertGreaterThan(alpha, 0.6)
            XCTAssertLessThanOrEqual(alpha, (key.isBlack ? 0.84 : 0.86) + 0.01)
        }
    }
    func testControllerPersistenceKeepsHeldInputAudioAndOtherPreferences() throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("preferences.json")
        var p = AppPreferences(); p.setVolume(0.73); p.setHeightScale(1.8); p.showKeyLabels = false; try p.save(to: url)
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        let c = try ProbeController(mapping: mapping(), sources: AudioSource.available(root: root, bundled: false), preferencesURL: url, input: input, audioEngine: engine, installStatusItem: false, secureInputCheck: { false }, permissionCheck: { true }, dockVisibilityCheck: { _, _ in .hidden })
        c.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { c.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        c.start(global: true); c.toggleSound(); input.onEvent?(.init("keyG", .down))
        let panics = engine.panics, shutdowns = engine.shutdowns, downs = engine.downs.count
        c.changeTransparency(0.5); c.applyTransparencyAccessibility(true)
        XCTAssertEqual(c.runtimeDiagnostics()["transparency"] as? Double, 0.5)
        XCTAssertEqual(c.runtimeDiagnostics()["effectiveMaterialOpacity"] as? Double, 1)
        c.applyTransparencyAccessibility(false); c.flushPreferences()
        let saved = try AppPreferences.load(from: url)
        XCTAssertEqual(saved.transparency, 0.5); XCTAssertEqual(saved.heightScale, 1.8); XCTAssertEqual(saved.volume, 0.73); XCTAssertFalse(saved.showKeyLabels)
        XCTAssertEqual(input.mode, .global); XCTAssertTrue(engine.prepared); XCTAssertEqual(c.integrationState.activeKeys, 1)
        XCTAssertEqual(engine.panics, panics); XCTAssertEqual(engine.shutdowns, shutdowns); XCTAssertEqual(engine.downs.count, downs)
        input.onEvent?(.init("keyG", .up)); XCTAssertEqual(c.integrationState.activeKeys, 0)
    }
}
