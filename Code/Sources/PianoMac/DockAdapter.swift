import Foundation
import PianoCore

public protocol DockAutohideStorage: AnyObject {
    func read() throws -> Bool?
    func write(_ value: Bool) throws
}
public final class SimulatedDockStorage: DockAutohideStorage {
    public var value: Bool?
    public private(set) var writes: [Bool] = []
    public init(value: Bool? = false) { self.value = value }
    public func read() throws -> Bool? { value }
    public func write(_ value: Bool) throws { writes.append(value); self.value = value }
}
/// Fixed executable and key. No shell, killall, automation or unrelated preferences.
public final class DefaultsDockStorage: DockAutohideStorage {
    public typealias Runner = (String, [String]) throws -> (Int32, String)
    private let run: Runner
    public init(run: @escaping Runner = DefaultsDockStorage.execute) { self.run = run }
    public static func execute(_ executable: String, _ arguments: [String]) throws -> (Int32, String) {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
    public func read() throws -> Bool? {
        let (status, output) = try run("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])
        guard status == 0 else { return nil }
        switch output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
    public func write(_ value: Bool) throws {
        let (status, _) = try run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", value ? "true" : "false"])
        guard status == 0 else { throw ProbeError.invalid("Dock偏好命令失败（\(status)）") }
    }
}
public struct DockTicket: Codable, Equatable {
    public let session: UUID
    public let original: Bool
    public let intended: Bool
    public let lastVerified: Bool?
    public init(session: UUID, original: Bool, intended: Bool, lastVerified: Bool?) {
        self.session = session; self.original = original; self.intended = intended; self.lastVerified = lastVerified
    }
}
public protocol DockTicketStore: AnyObject {
    func load() throws -> DockTicket?
    func save(_ ticket: DockTicket?) throws
}
public final class MemoryDockTicketStore: DockTicketStore {
    public var ticket: DockTicket?
    public init() {}
    public func load() throws -> DockTicket? { ticket }
    public func save(_ ticket: DockTicket?) throws { self.ticket = ticket }
}
public final class FileDockTicketStore: DockTicketStore {
    private let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> DockTicket? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(DockTicket.self, from: Data(contentsOf: url))
    }
    public func save(_ ticket: DockTicket?) throws {
        if let ticket {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(ticket).write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
/// All operations run on the menu's serial/main context. Only injected storage can write.
public final class DockAdapter {
    public enum Outcome: String { case cancelled, noChange, verifiedPreference, restoredPreference, failed, unknown, externalChange, recoveryRequired }
    public private(set) var desired = true
    public private(set) var observed: Bool?
    public private(set) var outcome: Outcome = .noChange
    public private(set) var detail = ""
    public let visualEffectVerified = false
    private let storage: DockAutohideStorage
    private let tickets: DockTicketStore
    private let session = UUID()
    private var ownership = DockOwnership()
    private var priorTicket: DockTicket?
    private var ticketLoadFailed = false
    public var recoveryPending: Bool { priorTicket != nil || ticketLoadFailed }
    public init(storage: DockAutohideStorage, tickets: DockTicketStore) {
        self.storage = storage; self.tickets = tickets
        do { priorTicket = try tickets.load() } catch { ticketLoadFailed = true; detail = error.localizedDescription }
    }
    private func finish(_ result: Outcome) -> Outcome { outcome = result; return result }
    public func request(_ desired: Bool, confirmedDisable: Bool) -> Outcome {
        guard desired || confirmedDisable else { return finish(.cancelled) }
        guard !recoveryPending else { return finish(.recoveryRequired) }
        do {
            observed = try storage.read()
            guard let observed else { return finish(.unknown) }
            guard let value = ownership.plan(desired: desired, observed: observed) else {
                if ownership.state == .externalChange { try tickets.save(nil); return finish(.externalChange) }
                self.desired = desired; return finish(.noChange)
            }
            // Save BEFORE any write: a crash after write but before readback remains recoverable.
            let original = ownership.original ?? observed
            try tickets.save(DockTicket(session: session, original: original, intended: value, lastVerified: ownership.lastApplied))
            var writeFailed = false
            do { try storage.write(value) } catch { writeFailed = true; detail = error.localizedDescription }
            self.observed = try storage.read()
            ownership.readback(self.observed)
            if ownership.state == .verified {
                try tickets.save(DockTicket(session: session, original: original, intended: value, lastVerified: value))
                self.desired = desired
                return finish(writeFailed ? .failed : .verifiedPreference)
            }
            if ownership.lastApplied == nil, self.observed == original { try tickets.save(nil) }
            if self.observed == nil { priorTicket = try tickets.load() }
            return finish(self.observed == nil ? .unknown : .failed)
        } catch {
            detail = error.localizedDescription
            do { priorTicket = try tickets.load() } catch { ticketLoadFailed = true }
            return finish(.failed)
        }
    }
    public func restoreOnExit() -> Outcome {
        // A previous session's ticket is never acted on by normal exit.
        guard !recoveryPending else { return finish(.recoveryRequired) }
        do {
            observed = try storage.read()
            guard let value = ownership.restoration(observed: observed) else {
                if ownership.state == .externalChange { try tickets.save(nil); return finish(.externalChange) }
                if ownership.state == .unknown { return finish(.unknown) }
                if ownership.lastApplied != nil, ownership.original == observed { try tickets.save(nil); ownership = DockOwnership() }
                return finish(.noChange)
            }
            try storage.write(value); observed = try storage.read()
            guard observed == value else { return finish(observed == nil ? .unknown : .failed) }
            try tickets.save(nil); ownership = DockOwnership()
            return finish(.restoredPreference)
        } catch { detail = error.localizedDescription; return finish(.failed) }
    }
    public func recoverPreviousSession(confirmed: Bool) -> Outcome {
        guard confirmed else { return finish(.cancelled) }
        guard let ticket = priorTicket, !ticketLoadFailed else { return finish(ticketLoadFailed ? .failed : .noChange) }
        do {
            observed = try storage.read()
            guard let observed else { return finish(.unknown) }
            if observed == ticket.original {
                try tickets.save(nil); priorTicket = nil; return finish(.noChange)
            }
            guard observed == ticket.intended || observed == ticket.lastVerified else {
                try tickets.save(nil); priorTicket = nil; return finish(.externalChange)
            }
            try storage.write(ticket.original); self.observed = try storage.read()
            guard self.observed == ticket.original else { return finish(self.observed == nil ? .unknown : .failed) }
            try tickets.save(nil); priorTicket = nil; ownership = DockOwnership()
            return finish(.restoredPreference)
        } catch { detail = error.localizedDescription; return finish(.failed) }
    }
}
