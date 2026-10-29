import XCTest
@testable import PianoCore

final class DockFadeTests: XCTestCase {
    func testUnknownStartsVisibleAndHiddenMustStabilizeBeforeRestore() {
        var fade = DockFade()
        fade.observe(.unknown, at: 0)
        XCTAssertEqual(fade.alpha(at: 0), 1)
        fade.observe(.visible, at: 0)
        XCTAssertTrue(fade.dockHidden)
        XCTAssertEqual(fade.alpha(at: 0.13), 0.5, accuracy: 0.00001)
        fade.observe(.hidden, at: 1)
        fade.observe(.hidden, at: 1.119)
        XCTAssertTrue(fade.dockHidden)
        fade.observe(.hidden, at: 1.121)
        XCTAssertFalse(fade.dockHidden)
        XCTAssertEqual(fade.alpha(at: 1.481), 1, accuracy: 0.00001)
    }
    func testUnknownCancelsPendingRestoreAndRepeatedSignalsDoNotRestart() {
        var fade = DockFade()
        fade.observe(.visible, at: 0)
        let generation = fade.generation
        fade.observe(.visible, at: 0.1)
        XCTAssertEqual(fade.generation, generation)
        fade.observe(.hidden, at: 1)
        fade.observe(.unknown, at: 1.1)
        fade.observe(.hidden, at: 1.2)
        XCTAssertTrue(fade.dockHidden)
        fade.observe(.hidden, at: 1.321)
        XCTAssertFalse(fade.dockHidden)
    }
    func testReversalIsContinuousAndUsesRemainingDistance() {
        var fade = DockFade()
        fade.observe(.visible, at: 0)
        fade.observe(.hidden, at: 0.001)
        let before = fade.alpha(at: 0.122)
        fade.observe(.hidden, at: 0.122)
        XCTAssertEqual(fade.alpha(at: 0.122), before, accuracy: 0.00001)
        let halfway = fade.alpha(at: 0.15)
        let generation = fade.generation
        fade.observe(.visible, at: 0.15)
        XCTAssertGreaterThan(fade.generation, generation)
        XCTAssertEqual(fade.alpha(at: 0.15), halfway, accuracy: 0.00001)
        XCTAssertEqual(fade.alpha(at: 0.15 + 0.26 * halfway + 0.0001), 0, accuracy: 0.00001)
    }
    func testSustainedUnknownRecoversAfterTwoSecondsWithoutRestartingTheFade() {
        var fade = DockFade()
        fade.observe(.visible, at: 0)
        fade.observe(.unknown, at: 1)
        fade.observe(.unknown, at: 2.99)
        XCTAssertTrue(fade.dockHidden)
        fade.observe(.unknown, at: 3)
        XCTAssertFalse(fade.dockHidden)
        let generation = fade.generation
        fade.observe(.unknown, at: 3.2)
        XCTAssertEqual(fade.generation, generation)
        XCTAssertEqual(fade.alpha(at: 3.36), 1, accuracy: 0.00001)
    }
    func testReducedMotionIsLinearAndRetargetsCurrentAlpha() {
        var fade = DockFade()
        fade.setReducedMotion(true, at: 0)
        fade.observe(.visible, at: 0)
        XCTAssertEqual(fade.alpha(at: 0.04), 0.5, accuracy: 0.00001)
        fade.setReducedMotion(false, at: 0.04)
        XCTAssertEqual(fade.alpha(at: 0.04), 0.5, accuracy: 0.00001)
        XCTAssertEqual(fade.alpha(at: 0.17), 0, accuracy: 0.00001)
    }
}
