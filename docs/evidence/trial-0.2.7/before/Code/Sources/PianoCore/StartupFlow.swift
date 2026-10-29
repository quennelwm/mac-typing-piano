import Foundation

/// A user-requested authorization continuation, not an auto-start preference.
/// Durable intent survives relaunch as a reminder only; a fresh process requires a click.
public final class StartupFlow {
    public enum Event { case primary, becameActive, cancel }
    public enum Action: Equatable { case none, start, requestAuthorization, permissionMissing, secureInput }
    private struct Intent: Codable { var pendingAuthorization: Bool }
    private let persist: (Bool) throws -> Void
    private var needsPersistenceClear: Bool
    private var automaticContinuationArmed = false
    public private(set) var pendingAuthorization: Bool

    public init(intentURL: URL, persist: ((Bool) throws -> Void)? = nil) throws {
        pendingAuthorization = FileManager.default.fileExists(atPath: intentURL.path)
            ? try JSONDecoder().decode(Intent.self, from: Data(contentsOf: intentURL)).pendingAuthorization : false
        needsPersistenceClear = pendingAuthorization
        self.persist = persist ?? { pending in
            try FileManager.default.createDirectory(at: intentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Intent(pendingAuthorization: pending)).write(to: intentURL, options: .atomic)
        }
    }
    public func handle(_ event: Event, permission: Bool, secureInput: Bool) throws -> Action {
        if event == .cancel { try clear(); return .none }
        if event == .becameActive && (!pendingAuthorization || !automaticContinuationArmed) { return .none }
        if secureInput { try clear(); return .secureInput }
        if event == .primary && !permission {
            // Disable continuation before storage access; an error must fail closed in memory.
            pendingAuthorization = false; automaticContinuationArmed = false; needsPersistenceClear = true
            try persist(true)
            pendingAuthorization = true; automaticContinuationArmed = true
            return .requestAuthorization
        }
        try clear()
        return permission ? .start : .permissionMissing
    }
    private func clear() throws {
        // Never re-arm on later activation, even if clearing the durable flag fails.
        pendingAuthorization = false; automaticContinuationArmed = false
        if needsPersistenceClear {
            try persist(false)
            needsPersistenceClear = false
        }
    }
}

/// A nested permission sheet can activate the app before Settings has actually opened.
/// An already-granted preflight can proceed immediately; otherwise wait for a Settings visit.
public struct AuthorizationReturnGate {
    private var awaitingSettingsVisit = false
    private var settingsObserved = false
    public init() {}
    public mutating func beginRequest() { awaitingSettingsVisit = true; settingsObserved = false }
    public mutating func observedSettings() { if awaitingSettingsVisit { settingsObserved = true } }
    public func canContinue(permission: Bool) -> Bool { !awaitingSettingsVisit || settingsObserved || permission }
    public mutating func reset() { awaitingSettingsVisit = false; settingsObserved = false }
}
