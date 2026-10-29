import XCTest
import Foundation
import PianoCore
@testable import PianoMac

final class AdaptiveOverlayTests: XCTestCase {
    func testUsesWholeScreenWidthAndSmallMarginsIncludingOffsetScreen() {
        XCTAssertEqual(AdaptiveOverlay.frame(screen: CGRect(x: 0, y: 0, width: 1512, height: 982)), CGRect(x: 8, y: 0, width: 1496, height: 256))
        XCTAssertEqual(AdaptiveOverlay.frame(screen: CGRect(x: -1920, y: -200, width: 1920, height: 1080)), CGRect(x: -1912, y: -200, width: 1904, height: 256))
    }
    func testUserEnabledDockIsNotRestoredToAnOlderFalseValue() {
        let storage = SimulatedDockStorage(value: true), tickets = MemoryDockTicketStore()
        let adapter = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .noChange)
        XCTAssertTrue(storage.writes.isEmpty); XCTAssertNil(tickets.ticket)
        XCTAssertEqual(adapter.restoreOnExit(), .noChange)
        XCTAssertEqual(storage.value, true); XCTAssertTrue(storage.writes.isEmpty)
        XCTAssertEqual(adapter.request(false, confirmedDisable: true), .verifiedPreference)
        XCTAssertEqual(tickets.ticket?.original, true)
        XCTAssertEqual(adapter.restoreOnExit(), .restoredPreference)
        XCTAssertEqual(storage.writes, [false, true])
    }
    func testDockVisualStateNeverClearsHeldNotesOrSound() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var coordinator = NoteCoordinator(mapping: try KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")))
        let events = coordinator.consume(.init("keyA", .down))
        let original = coordinator.active["keyA"]?.id
        coordinator.dockHidden = true
        XCTAssertFalse(coordinator.overlayVisible); XCTAssertTrue(coordinator.soundEnabled)
        XCTAssertEqual(coordinator.active["keyA"]?.id, original)
        coordinator.dockHidden = false
        XCTAssertEqual(coordinator.consume(.init("keyA", .up)).first?.pressID, events.first?.pressID)
    }
}
