import XCTest
import PianoCore
@testable import PianoMac

final class AlertVolumeTests: XCTestCase {
    final class Storage: AlertVolumeStorage {
        var value = 65
        var reads = 0
        var writes: [Int] = []
        var readFails = false, writeFails = false, ignoresWrites = false, failAfterWrite = false, readFailsAfterWrite = false
        func read() throws -> Int { reads += 1; if readFails { throw ProbeError.invalid("read failed") }; return value }
        func write(_ value: Int) throws {
            writes.append(value)
            if writeFails { throw ProbeError.invalid("write denied") }
            if !ignoresWrites { self.value = value }
            if readFailsAfterWrite { readFails = true }
            if failAfterWrite { throw ProbeError.invalid("write reply failed") }
        }
    }
    func testDefaultAndCancellationDoNotReadOrWriteSystem() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        XCTAssertEqual(tested.mute(confirmed: false), .cancelled)
        XCTAssertEqual(tested.restore(), .noChange)
        XCTAssertNil(tested.observed)
        XCTAssertEqual(storage.reads, 0); XCTAssertEqual(storage.writes, [])
    }
    func testMuteAndCloseOrExitRestoreOnlyOriginalOwnedValue() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        XCTAssertEqual(tested.mute(confirmed: true), .muted)
        XCTAssertEqual(tested.originalVolume, 65); XCTAssertEqual(tested.mutedState, true)
        XCTAssertEqual(tested.restore(), .restored)
        XCTAssertEqual(storage.value, 65); XCTAssertEqual(storage.writes, [0, 65])
        XCTAssertEqual(tested.restore(), .noChange)
        XCTAssertEqual(storage.writes, [0, 65])
    }
    func testAlreadyZeroHasNoInventedRestoreValue() {
        let storage = Storage(); storage.value = 0
        let adapter = AlertVolumeAdapter(storage: storage)
        XCTAssertEqual(adapter.mute(confirmed: true), .alreadySilent)
        XCTAssertEqual(adapter.mutedState, true); XCTAssertNil(adapter.originalVolume)
        XCTAssertEqual(adapter.restore(), .noChange)
        XCTAssertEqual(storage.value, 0); XCTAssertTrue(storage.writes.isEmpty)
    }
    func testExternalChangeDropsOwnershipAndIsNeverOverwrittenOnExit() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        _ = tested.mute(confirmed: true)
        storage.value = 27
        XCTAssertEqual(tested.refresh(), .externalChange)
        XCTAssertNil(tested.originalVolume)
        XCTAssertEqual(tested.restore(), .noChange)
        XCTAssertEqual(storage.value, 27); XCTAssertEqual(storage.writes, [0])
    }
    func testFailedOrIgnoredWritesDoNotReportSuccess() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        storage.writeFails = true
        XCTAssertEqual(tested.mute(confirmed: true), .failed); XCTAssertNil(tested.mutedState)
        storage.writeFails = false; storage.ignoresWrites = true
        XCTAssertEqual(tested.mute(confirmed: true), .failed)
        XCTAssertEqual(storage.value, 65); XCTAssertNil(tested.originalVolume)
    }
    func testWriteErrorAfterActualChangeRetainsRestorableOwnership() {
        let storage = Storage()
        let adapter = AlertVolumeAdapter(storage: storage)
        storage.failAfterWrite = true
        XCTAssertEqual(adapter.mute(confirmed: true), .failed)
        XCTAssertNil(adapter.mutedState); XCTAssertEqual(adapter.originalVolume, 65)
        storage.failAfterWrite = false
        XCTAssertEqual(adapter.restore(), .restored); XCTAssertEqual(storage.value, 65)
    }
    func testReadFailurePreventsWritesAndFailedRestoreCanBeRetried() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        storage.readFails = true
        XCTAssertEqual(tested.mute(confirmed: true), .failed); XCTAssertTrue(storage.writes.isEmpty)
        storage.readFails = false; _ = tested.mute(confirmed: true)
        storage.writeFails = true
        XCTAssertEqual(tested.restore(), .failed); XCTAssertEqual(tested.originalVolume, 65)
        storage.writeFails = false
        XCTAssertEqual(tested.restore(), .restored)
    }
    func testUnverifiedWriteRequiresManualRecoveryAndDoesNotInventOwnership() {
        let storage = Storage()
        let tested = AlertVolumeAdapter(storage: storage)
        storage.readFailsAfterWrite = true
        XCTAssertEqual(tested.mute(confirmed: true), .failed)
        XCTAssertEqual(tested.originalVolume, 65); XCTAssertNil(tested.mutedState)
        storage.readFails = false
        XCTAssertEqual(tested.restore(), .failed)
        XCTAssertEqual(storage.writes, [0])
        storage.value = 30
        XCTAssertEqual(tested.restore(), .externalChange)
        XCTAssertEqual(storage.writes, [0]); XCTAssertNil(tested.originalVolume)
    }
    func testStandardAdditionsBackendOnlyUsesAlertParameterAndRejectsInvalidReadback() throws {
        var commands: [String] = []
        var answer = "65"
        let backend = StandardAdditionsAlertVolumeStorage { command in commands.append(command); return answer }
        XCTAssertEqual(try backend.read(), 65)
        try backend.write(0)
        XCTAssertEqual(commands, ["return alert volume of (get volume settings)", "set volume alert volume 0"])
        for invalid in ["", "missing value", "101", "-1", "true"] {
            answer = invalid; XCTAssertThrowsError(try backend.read())
        }
        let count = commands.count
        XCTAssertThrowsError(try backend.write(-1)); XCTAssertThrowsError(try backend.write(101))
        XCTAssertEqual(commands.count, count)
        let denied = StandardAdditionsAlertVolumeStorage { _ in throw ProbeError.invalid("-1743") }
        XCTAssertThrowsError(try denied.read())
        XCTAssertThrowsError(try denied.write(0))
    }
}
