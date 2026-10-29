import Foundation
public struct FloatingNote {
    public let pressID: UUID
    public let midi: Int
    public let startedAt: TimeInterval
    public let duration: TimeInterval
    public let rise: Double
}
/// CR-002 pure lifecycle model. Used by the native renderer.
public struct FloatingNotes {
    public private(set) var instances: [UUID: FloatingNote] = [:]
    public private(set) var sceneGeneration: UInt64 = 0
    private var visible = true
    private var recentIDs: [UUID] = []
    public init() {}
    public mutating func setVisible(_ value: Bool) {
        guard visible != value else { return }
        visible = value
        if !value { instances.removeAll(); recentIDs.removeAll(); sceneGeneration &+= 1 }
    }
    public mutating func strike(_ event: NoteEvent, time: TimeInterval, generation: UInt64, reducedMotion: Bool = false) {
        guard visible, generation == sceneGeneration, event.phase == .down,
              time.isFinite, !recentIDs.contains(event.pressID) else { return }
        expire(at: time)
        recentIDs.append(event.pressID)
        if recentIDs.count > 256 { recentIDs.removeFirst() }
        if instances.count >= 128, let oldest = instances.values.min(by: { $0.startedAt < $1.startedAt }) {
            instances.removeValue(forKey: oldest.pressID)
        }
        instances[event.pressID] = FloatingNote(pressID: event.pressID, midi: event.midiNote, startedAt: time,
            duration: reducedMotion ? 0.2 : 0.7, rise: reducedMotion ? 0 : 24)
    }
    public mutating func expire(at time: TimeInterval) {
        instances = instances.filter { time + 0.000000001 < $0.value.startedAt + $0.value.duration }
    }
}

public struct FloatingPresentation {
    public let pressID: UUID
    public let midi: Int
    public let rise: Double
    public let opacity: Double
}
extension FloatingNotes {
    public func presentations(at time: TimeInterval) -> [FloatingPresentation] {
        instances.values.sorted { $0.startedAt < $1.startedAt }.compactMap { note in
            let elapsed = time - note.startedAt
            guard elapsed >= 0, elapsed + 0.000000001 < note.duration else { return nil }
            let t = elapsed / note.duration
            return FloatingPresentation(pressID: note.pressID, midi: note.midi,
                rise: note.rise * (1 - pow(1 - t, 3)),
                opacity: note.rise == 0 ? 1 - t : max(0, min(1, elapsed / 0.06, (0.7 - elapsed) / 0.4)))
        }
    }
}
