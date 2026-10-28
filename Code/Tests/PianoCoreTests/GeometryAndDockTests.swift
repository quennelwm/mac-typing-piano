import XCTest
@testable import PianoCore
final class GeometryAndDockTests: XCTestCase {
    func testContinuousPianoGeometryAtAllProbeWidths() throws {
        let mapping = try fixtureMapping()
        for width in [900.0, 1000, 1100] {
            let keys = PianoGeometry.layout(mapping: mapping, width: width, height: 56)
            XCTAssertEqual(keys.count, 64)
            XCTAssertEqual(keys.filter { !$0.isBlack }.count, 38)
            XCTAssertEqual(keys.filter(\.isBlack).count, 26)
            XCTAssertTrue(keys.allSatisfy { $0.rect.minX >= 0 && $0.rect.maxX <= width + 0.001 })
            XCTAssertEqual(keys.first { $0.midi == 33 }?.rect.minX, 0)
            XCTAssertEqual(try XCTUnwrap(keys.first { $0.midi == 96 }).rect.maxX, width, accuracy: 0.001)
            for black in keys.filter(\.isBlack) {
                let left = try XCTUnwrap(keys.first { $0.midi == black.midi - 1 })
                XCTAssertEqual(black.rect.midX, left.rect.maxX, accuracy: 0.001)
                XCTAssertLessThan(black.rect.maxY, 56) // label baseline remains on own shorter key
            }
        }
    }
    func testDockReadbackFailureNeverClaimsOwnership() {
        var d = DockOwnership()
        XCTAssertNil(d.plan(desired: true, observed: nil))
        XCTAssertEqual(d.state, .unknown)
        XCTAssertEqual(d.plan(desired: true, observed: false), true)
        d.readback(false)
        XCTAssertEqual(d.state, .failed)
        XCTAssertNil(d.lastApplied)
        XCTAssertNil(d.restoration(observed: false))
    }
    func testDockRestoreOnlyOwnVerifiedChangeAndRespectExternalValue() {
        var d = DockOwnership()
        XCTAssertEqual(d.plan(desired: true, observed: false), true)
        d.readback(true)
        XCTAssertEqual(d.state, .verified)
        XCTAssertEqual(d.restoration(observed: true), false)
        XCTAssertNil(d.restoration(observed: false))
        XCTAssertEqual(d.state, .externalChange)
        XCTAssertNil(d.restoration(observed: true))
    }
}

extension GeometryAndDockTests {
    func testExternalDockChangeStopsAutomaticPlansUntilNewTransaction() {
        var d = DockOwnership()
        _ = d.plan(desired: true, observed: false)
        d.readback(true)
        XCTAssertNil(d.plan(desired: true, observed: false))
        XCTAssertEqual(d.state, .externalChange)
        XCTAssertNil(d.plan(desired: true, observed: false))
    }
}

extension GeometryAndDockTests {
    func testFailedSecondDockWritePreservesVerifiedRestorationResponsibility() {
        var d = DockOwnership()
        _ = d.plan(desired: true, observed: false)
        d.readback(true)
        _ = d.plan(desired: false, observed: true)
        d.readback(true) // disabling failed; our prior enabled value is still current
        XCTAssertEqual(d.state, .failed)
        XCTAssertEqual(d.lastApplied, true)
        XCTAssertEqual(d.restoration(observed: true), false)
    }
}

extension GeometryAndDockTests {
    func testNormalClickOutsideDockNeverHidesAndDockDragRestoresAfterRelease() {
        var d = DockAvoidance()
        XCTAssertFalse(d.update(nearEdge: false, recoverySafe: true, mouseDown: true, dockFrontmost: false, time: 0))
        XCTAssertFalse(d.latched)
        XCTAssertTrue(d.update(nearEdge: true, recoverySafe: false, mouseDown: true, dockFrontmost: false, time: 1))
        XCTAssertTrue(d.update(nearEdge: false, recoverySafe: true, mouseDown: true, dockFrontmost: false, time: 2))
        XCTAssertTrue(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 3))
        XCTAssertFalse(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: false, time: 3.5))
        XCTAssertFalse(d.latched)
        XCTAssertTrue(d.update(nearEdge: false, recoverySafe: true, mouseDown: false, dockFrontmost: true, time: 4))
    }
}
