import XCTest
import Foundation
@testable import PianoMac

final class SingleInstanceTests: XCTestCase {
    private func record(_ id: String = "local.typingpiano.trial", pid: Int32 = 2, modern: Bool = false, executable: String? = nil) -> PianoInstanceRecord {
        let path = "/tmp/打字钢琴试用.app"
        return PianoInstanceRecord(pid: pid, bundleID: id, bundlePath: path,
            executablePath: executable ?? path + "/Contents/MacOS/TypingPianoProbe", usesLockProtocol: modern)
    }
    func testRecognizesOnlyTrialWithoutMatchingOldProbeOrOtherSoftware() {
        XCTAssertTrue(record().isPiano)
        XCTAssertFalse(record("local.typingpiano.probe").isPiano)
        XCTAssertFalse(record("com.other.music").isPiano)
        XCTAssertFalse(record(executable: "/tmp/other/TypingPianoProbe").isPiano)
        XCTAssertFalse(record(executable: "/tmp/打字钢琴试用.app/Contents/MacOS/Other").isPiano)
    }
    func testLockWinnerIgnoresCooperatingContendersButYieldsToOldApps() {
        XCTAssertNil(PianoInstanceRecord.legacyBlocker(in: [record(pid: 1), record(pid: 2, modern: true)], ownPID: 1))
        XCTAssertEqual(PianoInstanceRecord.legacyBlocker(in: [record(pid: 1, modern: true), record(pid: 3)], ownPID: 1)?.pid, 3)
        XCTAssertNil(PianoInstanceRecord.legacyBlocker(in: [record("com.other.music")], ownPID: 1))
    }
    func testLockContentionReleaseAndStaleFileRecovery() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("instance.lock")
        var first: PianoInstanceLease? = try XCTUnwrap(PianoInstanceLease.acquire(at: path))
        XCTAssertNotNil(first)
        XCTAssertNil(try PianoInstanceLease.acquire(at: path))
        first = nil
        let next = try XCTUnwrap(PianoInstanceLease.acquire(at: path))
        withExtendedLifetime(next) { XCTAssertTrue(FileManager.default.fileExists(atPath: path.path)) }
    }
    func testSymlinkIsRejectedWithoutTouchingTarget() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appendingPathComponent("target"), link = dir.appendingPathComponent("instance.lock")
        try Data("unchanged".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try PianoInstanceLease.acquire(at: link))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "unchanged")
    }
}
