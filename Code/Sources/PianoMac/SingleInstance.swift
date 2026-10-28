import AppKit
import Darwin
import Foundation

struct PianoInstanceRecord {
    let pid: Int32
    let bundleID: String
    let bundlePath: String
    let executablePath: String
    let usesLockProtocol: Bool
    var isPiano: Bool {
        bundleID == "local.typingpiano.trial" &&
        URL(fileURLWithPath: bundlePath).pathExtension == "app" &&
        URL(fileURLWithPath: executablePath).standardizedFileURL ==
        URL(fileURLWithPath: bundlePath).appendingPathComponent("Contents/MacOS/TypingPianoProbe").standardizedFileURL
    }
    static func legacyBlocker(in records: [Self], ownPID: Int32) -> Self? {
        records.filter { $0.pid != ownPID && $0.isPiano && !$0.usesLockProtocol }.min { $0.pid < $1.pid }
    }
}

/// Held for the GUI lifetime. Kernel releases the lock on crash; never delete the lock file
/// while it is in use, since replacing its inode would allow a second owner.
public final class PianoInstanceLease {
    private let descriptor: Int32
    private init(_ descriptor: Int32) { self.descriptor = descriptor }
    deinit { _ = flock(descriptor, LOCK_UN); _ = close(descriptor) }
    static func acquire(at url: URL) throws -> PianoInstanceLease? {
        let fd = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), (info.st_mode & S_IFMT) == S_IFREG else {
            _ = close(fd); throw POSIXError(.EPERM)
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno; _ = close(fd)
            if code == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        return PianoInstanceLease(fd)
    }
}

public enum PianoSingleInstance {
    /// Only normal GUI startup calls this. Diagnostics/offline CLI do not create an icon.
    /// A nil lease means the new process must exit before constructing its controller.
    public static func acquireForGUI() throws -> PianoInstanceLease? {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/local.typingpiano.trial")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lease = try PianoInstanceLease.acquire(at: directory.appendingPathComponent("gui-instance.lock"))
        let running = NSWorkspace.shared.runningApplications
        let records = running.compactMap { app -> PianoInstanceRecord? in
            guard let id = app.bundleIdentifier, id == "local.typingpiano.trial",
                  let bundle = app.bundleURL, let executable = app.executableURL else { return nil }
            return PianoInstanceRecord(pid: app.processIdentifier, bundleID: id, bundlePath: bundle.path,
                executablePath: executable.path,
                usesLockProtocol: (Bundle(url: bundle)?.object(forInfoDictionaryKey: "TypingPianoSingleInstanceProtocol") as? Int) == 1)
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let existing = lease == nil
            ? records.filter { $0.pid != ownPID && $0.isPiano }.min { $0.pid < $1.pid }
            : PianoInstanceRecord.legacyBlocker(in: records, ownPID: ownPID)
        if lease == nil || existing != nil {
            if let existing, let app = running.first(where: { $0.processIdentifier == existing.pid }) {
                _ = app.activate(options: [.activateAllWindows])
            }
            fputs("打字钢琴已运行；本次启动退出，不创建第二个菜单栏图标。\n", stderr)
            return nil
        }
        return lease
    }
}
