import XCTest
import AppKit
@testable import PianoMac
import PianoCore

final class IntegrationTests: XCTestCase {
    func mapping() throws -> KeyMapping {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json"))
    }
    func testApprovedGeometryAndNativeLabels() throws {
        let mapping = try mapping()
        for width in [900.0, 1000, 1100, 1264, 1496, 1904] {
            let keys = PianoGeometry.quietIvory(mapping: mapping, width: width)
            XCTAssertEqual(keys.count, 64)
            XCTAssertEqual(keys[0].rect.minX, 2.35, accuracy: 0.001)
            XCTAssertEqual(keys[0].rect.height, 100)
            XCTAssertEqual(keys.filter(\.isBlack).first?.rect.height, 64)
            let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: width, height: 208))
            XCTAssertTrue(view.labelMetrics.allSatisfy { $0.insideKey && $0.missingGlyphs == 0 && !$0.overlap })
            XCTAssertEqual(view.labelMetrics.count, 64)
        }
    }
    func testHiddenSceneFreezesCurrentKeyPoseAndRestoresHeldStateWithoutReplay() throws {
        let view = PianoView(mapping: try mapping(), frame: NSRect(x: 0, y: 0, width: 1496, height: 208))
        view.automaticAnimation = false
        var now = 0.0; view.clock = { now }
        view.activeMIDI = [60]
        now = 0.01; view.advanceAnimations(at: now)
        let before = view.keyDepression(midi: 60, at: now)
        view.setSceneVisible(false)
        XCTAssertEqual(view.keyDepression(midi: 60, at: 1), before, accuracy: 0.00001)
        view.activeMIDI = [61]
        view.setSceneVisible(true)
        XCTAssertEqual(view.keyDepression(midi: 61, at: 1), 1)
        XCTAssertEqual(view.keyDepression(midi: 60, at: 1), 0)
        XCTAssertFalse(view.animationTimerRunning); XCTAssertEqual(view.floatingCount, 0)
    }
    func testFloatingRendererLifecycleMutedLabelsOffHiddenAndIdle() throws {
        let mapping = try mapping()
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: 208))
        view.automaticAnimation = false
        view.showLabels = false
        var coordinator = NoteCoordinator(mapping: mapping)
        _ = coordinator.setSoundEnabled(false)
        _ = coordinator.consume(.init("keyA", .down))
        let strike = try XCTUnwrap(coordinator.lastStrike)
        view.strike(strike, at: 10)
        view.strike(strike, at: 10.01)
        XCTAssertEqual(view.floatingCount, 1)
        view.advanceAnimations(at: 10.35)
        XCTAssertEqual(view.floatingPresentations.first!.rise, 48 * (1 - pow(1 - 0.35 / 0.9, 3)), accuracy: 0.001)
        XCTAssertEqual(view.floatingPresentations.first!.opacity, 1, accuracy: 0.001)
        view.advanceAnimations(at: 10.9)
        XCTAssertEqual(view.floatingCount, 0)
        XCTAssertFalse(view.animationTimerRunning)
        view.setSceneVisible(false)
        view.strike(strike, at: 11)
        view.setSceneVisible(true)
        XCTAssertEqual(view.floatingCount, 0)
        view.reducedMotion = true
        _ = coordinator.consume(.init("keyA", .up))
        _ = coordinator.consume(.init("keyA", .down))
        view.strike(try XCTUnwrap(coordinator.lastStrike), at: 12)
        view.advanceAnimations(at: 12.1)
        XCTAssertEqual(view.floatingPresentations.first!.rise, 0)
        XCTAssertEqual(view.floatingPresentations.first!.opacity, 0.5, accuracy: 0.001)
        view.advanceAnimations(at: 12.2)
        XCTAssertEqual(view.floatingCount, 0)
    }
}

extension IntegrationTests {
    func testShortPressContinuesDepressionThenReleasesAndRestrikeUsesCurrentPosition() throws {
        let view = PianoView(mapping: try mapping(), frame: NSRect(x: 0, y: 0, width: 1000, height: 208))
        view.automaticAnimation = false
        var now = 0.0; view.clock = { now }
        view.activeMIDI = [60]
        let before = view.keyDepression(midi: 60, at: 0.01)
        now = 0.01; view.activeMIDI = []
        XCTAssertEqual(view.keyDepression(midi: 60, at: now), before, accuracy: 0.001)
        XCTAssertEqual(view.keyDepression(midi: 60, at: 0.045), 1, accuracy: 0.001)
        let released = view.keyDepression(midi: 60, at: 0.08)
        XCTAssertGreaterThan(released, 0); XCTAssertLessThan(released, 1)
        now = 0.08; view.activeMIDI = [60]
        XCTAssertEqual(view.keyDepression(midi: 60, at: now), released, accuracy: 0.001)
        view.advanceAnimations(at: 0.2)
        XCTAssertEqual(view.keyDepression(midi: 60, at: 0.2), 1)
        XCTAssertFalse(view.animationTimerRunning)
    }
    func testActualTimerStopsAfterAnimationAndOnHidden() throws {
        let view = PianoView(mapping: try mapping(), frame: NSRect(x: 0, y: 0, width: 1000, height: 208))
        var coordinator = NoteCoordinator(mapping: try mapping())
        _ = coordinator.consume(.init("keyA", .down))
        view.strike(try XCTUnwrap(coordinator.lastStrike), at: ProcessInfo.processInfo.systemUptime)
        XCTAssertTrue(view.animationTimerRunning)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        XCTAssertFalse(view.animationTimerRunning); XCTAssertEqual(view.floatingCount, 0)
        _ = coordinator.consume(.init("keyA", .up)); _ = coordinator.consume(.init("keyA", .down))
        view.strike(try XCTUnwrap(coordinator.lastStrike), at: ProcessInfo.processInfo.systemUptime)
        XCTAssertTrue(view.animationTimerRunning)
        view.setSceneVisible(false)
        XCTAssertFalse(view.animationTimerRunning); XCTAssertEqual(view.floatingCount, 0)
    }
}
