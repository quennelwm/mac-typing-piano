import XCTest
@testable import PianoCore
final class ReducerTests: XCTestCase {
    func testSingleStrikeIgnoresRepeatAndDuplicateDown() {
        var state = KeyStateReducer()
        XCTAssertNotNil(state.consume(.init("keyA", .down)))
        XCTAssertNil(state.consume(.init("keyA", .down), isRepeat: true))
        XCTAssertNil(state.consume(.init("keyA", .down)))
        XCTAssertNotNil(state.consume(.init("keyA", .up)))
        XCTAssertNil(state.consume(.init("keyA", .up)))
        XCTAssertNotNil(state.consume(.init("keyA", .down)))
    }
    func testModifierSidesStayIndependentInInterleavedRelease() {
        var state = KeyStateReducer()
        _ = state.consume(.init("shiftLeft", .down))
        _ = state.consume(.init("shiftRight", .down))
        _ = state.consume(.init("shiftLeft", .up))
        XCTAssertEqual(state.pressed, ["shiftRight"])
        _ = state.consume(.init("shiftRight", .up))
        XCTAssertTrue(state.pressed.isEmpty)
    }
    func testPulseDoesNotLatchAndLongHoldHasNoExpiry() {
        var state = KeyStateReducer()
        XCTAssertNotNil(state.consume(.init("capsLock", .pulse)))
        XCTAssertTrue(state.pressed.isEmpty)
        _ = state.consume(.init("keyA", .down, time: 1))
        _ = state.consume(.init("keyB", .down, time: 12))
        XCTAssertTrue(state.pressed.contains("keyA"))
        state.reset()
        XCTAssertTrue(state.pressed.isEmpty)
    }
}

extension ReducerTests {
    func testPreviewReleaseCannotReleaseHeldHardwareKeyAndViceVersa() {
        var state = KeyStateReducer()
        XCTAssertNotNil(state.consume(.init("keyA", .down), source: .keyboard))
        XCTAssertNil(state.consume(.init("keyA", .down), source: .preview))
        XCTAssertNil(state.consume(.init("keyA", .up), source: .preview))
        XCTAssertTrue(state.pressed.contains("keyA"))
        XCTAssertNotNil(state.consume(.init("keyA", .up), source: .keyboard))
        XCTAssertNotNil(state.consume(.init("keyA", .down), source: .preview))
        XCTAssertNil(state.consume(.init("keyA", .down), source: .keyboard))
        XCTAssertNil(state.consume(.init("keyA", .up), source: .keyboard))
        XCTAssertTrue(state.pressed.contains("keyA"))
        state.reset()
        XCTAssertNil(state.consume(.init("keyA", .up), source: .preview))
    }
}
