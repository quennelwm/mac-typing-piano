import XCTest
@testable import PianoCore
final class FloatingNoteTests: XCTestCase {
    func testMutedStrikeStillFeedsVisualModelIndependentlyOfLabels() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        _ = c.setSoundEnabled(false)
        var preferences = ProbePreferences()
        preferences.labelsVisible = false
        XCTAssertTrue(c.consume(.init("keyA", .down)).isEmpty)
        let event = try XCTUnwrap(c.lastStrike)
        var f = FloatingNotes()
        f.strike(event, time: 0, generation: f.sceneGeneration)
        XCTAssertEqual(f.instances.count, 1)
        XCTAssertFalse(preferences.labelsVisible)
        _ = c.consume(.init("keyA", .down))
        XCTAssertNil(c.lastStrike)
    }

    func testDedupRetriggerAndOldExpiryCannotDeleteNewInstance() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        var f = FloatingNotes()
        let old = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        f.strike(old, time: 0, generation: 0)
        f.strike(old, time: 0.1, generation: 0)
        XCTAssertEqual(f.instances.count, 1)
        _ = c.consume(.init("keyA", .up))
        let new = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        f.strike(new, time: 0.5, generation: 0)
        XCTAssertEqual(f.instances.count, 2)
        f.expire(at: 0.96)
        XCTAssertNil(f.instances[old.pressID])
        XCTAssertNotNil(f.instances[new.pressID])
        f.expire(at: 1.46)
        XCTAssertTrue(f.instances.isEmpty)
    }
    func testHiddenClearsAndRejectsQueuedOldGenerationWithoutReplay() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        let event = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        var f = FloatingNotes()
        f.strike(event, time: 0, generation: 0)
        f.setVisible(false)
        XCTAssertTrue(f.instances.isEmpty)
        f.strike(event, time: 0.1, generation: 0)
        f.setVisible(true)
        f.strike(event, time: 0.2, generation: 0)
        XCTAssertTrue(f.instances.isEmpty)
        XCTAssertGreaterThan(f.sceneGeneration, 0)
    }
    func testApprovedFloatingTimingAndTravel() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        var f = FloatingNotes()
        let event = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        f.strike(event, time: 0, generation: 0)
        let note = try XCTUnwrap(f.instances[event.pressID])
        XCTAssertEqual(note.duration, 0.95)
        XCTAssertEqual(note.rise, 100)
        XCTAssertGreaterThan(f.presentations(at: 0.7).first?.opacity ?? 0, 0)
        f.expire(at: 0.95)
        XCTAssertTrue(f.instances.isEmpty)
    }
    func testReducedMotionCompletesWithinOneSecondWithoutRise() throws {
        var c = NoteCoordinator(mapping: try fixtureMapping())
        var f = FloatingNotes()
        let event = try XCTUnwrap(c.consume(.init("keyA", .down)).first)
        f.strike(event, time: 0, generation: 0, reducedMotion: true)
        let note = try XCTUnwrap(f.instances[event.pressID])
        XCTAssertEqual(note.duration, 0.2)
        XCTAssertEqual(note.rise, 0)
        f.expire(at: 0.21)
        XCTAssertTrue(f.instances.isEmpty)
    }
}
