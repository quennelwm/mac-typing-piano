import Foundation
public struct NoteEvent: Equatable {
    public enum Phase { case down, release, panic }
    public let pressID: UUID
    public let physicalKeyID: String
    public let midiNote: Int
    public let velocity: Int
    public let phase: Phase
    public let mappingVersion: String
}
public struct ActivePress {
    public let id: UUID
    public let key: KeyMapping.Key
    public var audible: Bool
}
public struct NoteCoordinator {
    public let mapping: KeyMapping
    public private(set) var active: [String: ActivePress] = [:]
    public private(set) var generation: UInt64 = 0
    public private(set) var lastStrike: NoteEvent?
    public private(set) var soundEnabled = true
    public var visualEnabled = true
    public var dockHidden = false
    public private(set) var paused = false
    public var overlayVisible: Bool { visualEnabled && !dockHidden && !paused }
    public init(mapping: KeyMapping) { self.mapping = mapping }
    public mutating func consume(_ event: NormalizedKeyEvent) -> [NoteEvent] {
        lastStrike = nil
        guard !paused, let key = mapping.key(event.physicalKeyID) else { return [] }
        if event.phase == .up {
            guard let old = active[key.physicalKeyID] else { return [] }
            return release(key: key.physicalKeyID, pressID: old.id)
        }
        if event.phase == .down, active[key.physicalKeyID] != nil { return [] }
        var result: [NoteEvent] = []
        if let old = active[key.physicalKeyID] { result += release(key: key.physicalKeyID, pressID: old.id) }
        let press = ActivePress(id: UUID(), key: key, audible: soundEnabled)
        active[key.physicalKeyID] = press
        lastStrike = note(press, .down)
        if let lastStrike, soundEnabled { result.append(lastStrike) }
        return result
    }
    public mutating func release(key: String, pressID: UUID) -> [NoteEvent] {
        guard let press = active[key], press.id == pressID else { return [] }
        active.removeValue(forKey: key)
        return press.audible ? [note(press, .release)] : []
    }
    public mutating func setSoundEnabled(_ enabled: Bool) -> [NoteEvent] {
        guard soundEnabled != enabled else { return [] }
        soundEnabled = enabled
        guard !enabled else { return [] }
        for key in Array(active.keys) { active[key]?.audible = false }
        return [panicEvent()]
    }
    public mutating func panic(paused: Bool = false) -> [NoteEvent] {
        active.removeAll(); lastStrike = nil; generation &+= 1; self.paused = paused
        return [panicEvent()]
    }
    private func note(_ press: ActivePress, _ phase: NoteEvent.Phase) -> NoteEvent {
        NoteEvent(pressID: press.id, physicalKeyID: press.key.physicalKeyID, midiNote: press.key.midiNote,
                  velocity: press.key.velocity, phase: phase, mappingVersion: mapping.mappingVersion)
    }
    private func panicEvent() -> NoteEvent {
        NoteEvent(pressID: UUID(), physicalKeyID: "", midiNote: 0, velocity: 0, phase: .panic, mappingVersion: mapping.mappingVersion)
    }
    public mutating func resume() { paused = false }
}
