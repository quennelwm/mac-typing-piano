import XCTest
@testable import PianoMac

final class DockAdapterTests: XCTestCase {
    final class Store: DockAutohideStorage {
        var value: Bool? = false
        var writes: [Bool] = []
        var failWrite = false
        var ignoreWrite = false
        func read() throws -> Bool? { value }
        func write(_ value: Bool) throws {
            writes.append(value)
            if failWrite { throw NSError(domain: "test", code: 1) }
            if !ignoreWrite { self.value = value }
        }
    }
    func testCancelZeroWritesAndReadbackNotVisual() throws {
        let storage = Store(), tickets = MemoryDockTicketStore()
        let adapter = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertEqual(adapter.request(false, confirmedDisable: false), .cancelled)
        XCTAssertTrue(storage.writes.isEmpty); XCTAssertNil(tickets.ticket)
        XCTAssertTrue(adapter.desired)
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .verifiedPreference)
        XCTAssertEqual(storage.writes, [true]); XCTAssertFalse(adapter.visualEffectVerified)
        XCTAssertEqual(tickets.ticket?.original, false)
        XCTAssertEqual(adapter.restoreOnExit(), .restoredPreference)
        XCTAssertEqual(storage.writes, [true, false]); XCTAssertNil(tickets.ticket)
    }
    func testExternalChangeIsRespectedAndWriteFailureKeepsPriorOwnership() {
        let storage = Store(), tickets = MemoryDockTicketStore()
        let adapter = DockAdapter(storage: storage, tickets: tickets)
        _ = adapter.request(true, confirmedDisable: true)
        storage.failWrite = true
        XCTAssertEqual(adapter.request(false, confirmedDisable: true), .failed)
        XCTAssertNotNil(tickets.ticket)
        storage.failWrite = false
        XCTAssertEqual(adapter.restoreOnExit(), .restoredPreference)
        let other = DockAdapter(storage: storage, tickets: tickets)
        _ = other.request(true, confirmedDisable: true)
        storage.value = false // external change
        XCTAssertEqual(other.restoreOnExit(), .externalChange)
        XCTAssertEqual(storage.writes.count, 4)
        XCTAssertNil(tickets.ticket)
    }
    func testCrashTicketNeedsExplicitRecoveryAndMatchingReadback() throws {
        let storage = Store(), tickets = MemoryDockTicketStore()
        let old = DockAdapter(storage: storage, tickets: tickets)
        _ = old.request(true, confirmedDisable: true)
        let restarted = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertEqual(storage.writes, [true])
        XCTAssertEqual(restarted.request(false, confirmedDisable: true), .recoveryRequired)
        XCTAssertEqual(restarted.recoverPreviousSession(confirmed: false), .cancelled)
        XCTAssertEqual(storage.writes, [true])
        XCTAssertEqual(restarted.recoverPreviousSession(confirmed: true), .restoredPreference)
        XCTAssertEqual(storage.writes, [true, false]); XCTAssertNil(tickets.ticket)
    }
    func testUnknownReadbackPreservesRecoveryTicketAndCannotClaimSuccess() {
        let storage = Store(), tickets = MemoryDockTicketStore()
        storage.ignoreWrite = true
        let adapter = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .failed)
        XCTAssertFalse(adapter.visualEffectVerified)
        storage.value = nil
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .unknown)
        XCTAssertEqual(storage.writes, [true])
    }
    func testFixedSystemCommandArgumentsOnlyAutohide() throws {
        var calls: [(String, [String])] = []
        let storage = DefaultsDockStorage { executable, arguments in
            calls.append((executable, arguments)); return (0, "1\n")
        }
        XCTAssertEqual(try storage.read(), true)
        try storage.write(false)
        XCTAssertEqual(calls.map(\.0), ["/usr/bin/defaults", "/usr/bin/defaults"])
        XCTAssertEqual(calls[0].1, ["read", "com.apple.dock", "autohide"])
        XCTAssertEqual(calls[1].1, ["write", "com.apple.dock", "autohide", "-bool", "false"])
    }
}

extension DockAdapterTests {
    final class UncertainStore: DockAutohideStorage {
        var value = false
        var writes: [Bool] = []
        var uncertain = true
        var throwsRead = false
        func read() throws -> Bool? {
            if !writes.isEmpty && uncertain {
                if throwsRead { throw NSError(domain: "read", code: 1) }
                return nil
            }
            return value
        }
        func write(_ value: Bool) throws { writes.append(value); self.value = value }
    }
    func testUnknownAndThrowingReadbackBlockSecondWriteAndPreserveOriginalTicket() {
        for throwsRead in [false, true] {
            let storage = UncertainStore(), tickets = MemoryDockTicketStore()
            storage.throwsRead = throwsRead
            let adapter = DockAdapter(storage: storage, tickets: tickets)
            XCTAssertEqual(adapter.request(true, confirmedDisable: true), throwsRead ? .failed : .unknown)
            XCTAssertTrue(adapter.recoveryPending)
            XCTAssertEqual(tickets.ticket?.original, false)
            XCTAssertEqual(adapter.request(false, confirmedDisable: true), .recoveryRequired)
            XCTAssertEqual(storage.writes, [true]); XCTAssertEqual(tickets.ticket?.original, false)
            storage.uncertain = false
            XCTAssertEqual(adapter.recoverPreviousSession(confirmed: true), .restoredPreference)
            XCTAssertEqual(storage.writes, [true, false]); XCTAssertNil(tickets.ticket)
        }
    }
    func testAtomicFileTicketRoundTripAndRestoreFailureRetainsTicket() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("ticket.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let tickets = FileDockTicketStore(url: url), storage = Store()
        let adapter = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertEqual(adapter.request(true, confirmedDisable: true), .verifiedPreference)
        XCTAssertEqual(try tickets.load()?.original, false)
        storage.failWrite = true
        XCTAssertEqual(adapter.restoreOnExit(), .failed)
        XCTAssertNotNil(try tickets.load())
        let restarted = DockAdapter(storage: storage, tickets: tickets)
        XCTAssertTrue(restarted.recoveryPending)
    }
}
