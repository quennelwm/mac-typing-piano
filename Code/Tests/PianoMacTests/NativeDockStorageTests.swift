import XCTest
@testable import PianoMac

final class NativeDockStorageTests: XCTestCase {
    func testNativeWriteVerifiesRuntimeAndPreferenceWithoutDefaultsWrite() throws {
        var native: UInt8 = 1, preference = true, calls: [UInt8] = []
        let storage = NativeDockStorage(getter: { native }, setter: { native = $0; preference = $0 == 1; calls.append($0) }, readPreference: { preference })
        XCTAssertEqual(try storage.read(), true)
        try storage.write(false)
        XCTAssertEqual(try storage.read(), false); XCTAssertEqual(calls, [0])
        try storage.write(true)
        XCTAssertEqual(calls, [0, 1]); XCTAssertTrue(preference)
    }
    func testUnavailableInvalidOrIgnoredCallsCannotClaimSuccess() {
        let missing = NativeDockStorage(getter: nil, setter: nil, readPreference: { true })
        XCTAssertThrowsError(try missing.read()); XCTAssertThrowsError(try missing.write(false))
        var writes = 0
        let invalid = NativeDockStorage(getter: { 2 }, setter: { _ in writes += 1 }, readPreference: { true })
        XCTAssertThrowsError(try invalid.write(false)); XCTAssertEqual(writes, 0)
        let ignored = NativeDockStorage(getter: { 1 }, setter: { _ in }, readPreference: { true })
        XCTAssertThrowsError(try ignored.write(false))
    }
    func testPreferenceMismatchFailsAndAdapterPreservesOwnershipForRestoration() {
        var native: UInt8 = 1, preference = true
        let storage = NativeDockStorage(getter: { native }, setter: { native = $0 }, readPreference: { preference })
        let ticket = MemoryDockTicketStore(), adapter = DockAdapter(storage: storage, tickets: ticket)
        XCTAssertEqual(adapter.request(false, confirmedDisable: true), .failed)
        XCTAssertEqual(native, 0); XCTAssertEqual(ticket.ticket?.original, true)
        preference = true
        XCTAssertEqual(adapter.restoreOnExit(), .restoredPreference)
        XCTAssertEqual(native, 1); XCTAssertNil(ticket.ticket)
    }
    func testUserEnabledNativeBaselineDoesNotWriteOrRestoreFalse() {
        var writes: [UInt8] = []
        let storage = NativeDockStorage(getter: { 1 }, setter: { writes.append($0) }, readPreference: { true })
        let adapter = DockAdapter(storage: storage, tickets: MemoryDockTicketStore())
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .noChange)
        XCTAssertEqual(adapter.restoreOnExit(), .noChange); XCTAssertTrue(writes.isEmpty)
    }
}
