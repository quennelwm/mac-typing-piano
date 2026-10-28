import XCTest
@testable import PianoCore
func fixtureMapping() throws -> KeyMapping {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json"))
}
final class CoordinatorTests: XCTestCase {
    func testOldReleaseCannotStopRetriggerIncludingPulse() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        let first = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        _ = c.release(key: "keyA", pressID: first.pressID)
        let second = try XCTUnwrap(c.consume(.init("keyA", .down)).last)
        XCTAssertTrue(c.release(key: "keyA", pressID: first.pressID).isEmpty)
        XCTAssertEqual(c.active["keyA"]?.id, second.pressID)
        XCTAssertEqual(c.release(key: "keyA", pressID: second.pressID).count, 1)
    }
    func testDockAndVisualHidingDoNotProduceAudioStop() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        _ = c.consume(.init("keyA", .down))
        c.dockHidden = true
        XCTAssertFalse(c.overlayVisible)
        XCTAssertEqual(c.active.count, 1)
        XCTAssertTrue(c.soundEnabled)
        c.visualEnabled = false; c.dockHidden = false
        XCTAssertFalse(c.overlayVisible)
        XCTAssertEqual(c.active.count, 1)
    }
    func testMuteClearsAudioButKeepsPhysicalVisualStateAndDoesNotRearticulateHeldKey() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        _ = c.consume(.init("keyA", .down))
        XCTAssertEqual(c.setSoundEnabled(false).map(\.phase), [.panic])
        XCTAssertNotNil(c.active["keyA"])
        XCTAssertTrue(c.overlayVisible)
        XCTAssertTrue(c.setSoundEnabled(true).isEmpty)
        XCTAssertTrue(c.consume(.init("keyA", .up)).isEmpty)
    }
    func testPanicClearsPressesAndBumpsGenerationAndPauseRejectsNewEvents() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        _ = c.consume(.init("keyA", .down))
        XCTAssertEqual(c.panic(paused: true).map(\.phase), [.panic])
        XCTAssertTrue(c.active.isEmpty)
        XCTAssertEqual(c.generation, 1)
        XCTAssertTrue(c.consume(.init("keyB", .down)).isEmpty)
        XCTAssertFalse(c.overlayVisible)
        c.resume()
        XCTAssertEqual(c.consume(.init("keyB", .down)).count, 1)
    }
    func testMappingAndUnknownKey() throws {
        let mapping = try fixtureMapping()
        XCTAssertEqual(mapping.keys.count, 64)
        XCTAssertEqual(Set(mapping.keys.map(\.midiNote)), Set(33...96))
        var c = NoteCoordinator(mapping: mapping)
        XCTAssertTrue(c.consume(.init("escape", .down)).isEmpty)
        XCTAssertEqual(c.consume(.init("space", .down)).first?.midiNote, 60)
    }
}
final class PolicyTests: XCTestCase {
    func testDockHysteresisAndDragLatch() {
        var d = DockAvoidance()
        XCTAssertTrue(d.update(nearEdge: true, recoverySafe: false, mouseDown: false, dockFrontmost: false, time: 0))
        XCTAssertTrue(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 1))
        XCTAssertFalse(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 1.5))
        XCTAssertTrue(d.update(nearEdge: true, recoverySafe: false, mouseDown: true, dockFrontmost: false, time: 2))
        XCTAssertTrue(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 4))
        d.acknowledge()
        _ = d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 5)
        XCTAssertFalse(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 6))
    }
    func testCR001DefaultLabelsAndExplicitDockConfirmation() {
        var p = ProbePreferences()
        XCTAssertTrue(p.labelsVisible)
        XCTAssertTrue(p.desiredDockAutoHide)
        p.labelsVisible = false
        XCTAssertTrue(p.desiredDockAutoHide)
        p.requestDockAutoHide(false)
        XCTAssertTrue(p.confirmationPending)
        XCTAssertTrue(p.desiredDockAutoHide)
        p.resolveDockConfirmation(disable: false)
        XCTAssertTrue(p.desiredDockAutoHide)
        p.requestDockAutoHide(false)
        p.resolveDockConfirmation(disable: true)
        XCTAssertFalse(p.desiredDockAutoHide)
        XCTAssertFalse(p.confirmationPending)
    }
}
