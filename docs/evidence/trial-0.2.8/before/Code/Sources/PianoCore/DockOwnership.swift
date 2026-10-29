import Foundation
/// Pure transaction model for future CR-001 integration. Never writes system preferences.
public struct DockOwnership {
    public enum State: String { case idle, pending, verified, failed, unknown, externalChange }
    public private(set) var state: State = .idle
    public private(set) var original: Bool?
    public private(set) var lastApplied: Bool?
    private var proposed: Bool?
    public init() {}
    public mutating func plan(desired: Bool, observed: Bool?) -> Bool? {
        guard state != .externalChange else { return nil }
        guard let observed else { state = .unknown; return nil }
        if let lastApplied, lastApplied != observed {
            self.lastApplied = nil; original = nil; proposed = nil; state = .externalChange; return nil
        }
        guard desired != observed else { state = .idle; return nil }
        if lastApplied == nil { original = observed }
        proposed = desired; state = .pending
        return desired
    }
    public mutating func readback(_ value: Bool?) {
        guard let proposed else { return }
        defer { self.proposed = nil }
        guard let value else { state = .unknown; lastApplied = nil; return }
        guard value == proposed else {
            state = .failed
            if value != lastApplied { lastApplied = nil; original = nil }
            return
        }
        lastApplied = value; state = .verified
    }
    public mutating func restoration(observed: Bool?) -> Bool? {
        guard let lastApplied, let original else { return nil }
        guard let observed else { state = .unknown; return nil }
        guard observed == lastApplied else {
            self.lastApplied = nil; self.original = nil; state = .externalChange; return nil
        }
        return original == observed ? nil : original
    }
}
