import XCTest
import Foundation
import PianoCore
@testable import PianoMac

final class DockWindowVisibilityTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    func row(pid: Int32 = 1339, id: UInt32 = 49, layer: Int = 20, bounds: CGRect? = nil) -> DockWindowEvidence {
        .init(pid: pid, id: id, layer: layer, bounds: bounds ?? screen, alpha: 1)
    }
    func testPairedHostObservationUsesMembershipNotFullScreenBoundsOrMissingFlag() throws {
        let tracked = try XCTUnwrap(DockWindowMatcher.candidate(in: [row()], dockPID: 1339, screen: screen))
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: tracked, onscreen: [], orientation: "bottom"), .hidden)
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: tracked, onscreen: [row()], orientation: "bottom"), .visible)
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: tracked, onscreen: [], orientation: "bottom"), .hidden)
    }
    func testOtherLayerOtherOwnerOtherDisplayAndAmbiguityAreNotCandidates() {
        XCTAssertNil(DockWindowMatcher.candidate(in: [row(pid: 99)], dockPID: 1339, screen: screen))
        XCTAssertNil(DockWindowMatcher.candidate(in: [row(layer: 101)], dockPID: 1339, screen: screen))
        XCTAssertNil(DockWindowMatcher.candidate(in: [row(bounds: CGRect(x: 1512, y: -100, width: 1920, height: 1080))], dockPID: 1339, screen: screen))
        XCTAssertNil(DockWindowMatcher.candidate(in: [row(), row(id: 50)], dockPID: 1339, screen: screen))
        let offset = CGRect(x: -1920, y: 100, width: 1920, height: 1080)
        XCTAssertNotNil(DockWindowMatcher.candidate(in: [row(bounds: offset)], dockPID: 1339, screen: offset))
    }
    func testUnknownQueryAndReusedWindowIDRemainUnknownAndSideDockDoesNotHide() {
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: row(), onscreen: nil, orientation: "bottom"), .unknown)
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: row(), onscreen: [row(pid: 99)], orientation: "bottom"), .unknown)
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: row(), onscreen: [row()], orientation: "left"), .hidden)
        XCTAssertEqual(DockWindowMatcher.visibility(tracked: row(), onscreen: [row()], orientation: "invalid"), .unknown)
    }
}
