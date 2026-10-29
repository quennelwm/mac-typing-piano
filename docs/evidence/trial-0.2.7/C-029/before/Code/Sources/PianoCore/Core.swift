import Foundation

public enum KeyPhase: String, Codable { case down, up, pulse }
public struct NormalizedKeyEvent {
    public var eventID: UUID = UUID()
    public let physicalKeyID: String
    public let phase: KeyPhase
    public let monotonicTime: TimeInterval
    public let captureCapability: String
    public init(_ key: String, _ phase: KeyPhase, time: TimeInterval = 0, capability: String = "unverified") {
        physicalKeyID = key; self.phase = phase; monotonicTime = time; captureCapability = capability
    }
}
public enum KeyInputSource: Hashable { case keyboard, preview }
public struct KeyStateReducer {
    public private(set) var pressed = Set<String>()
    private var owners: [String: Set<KeyInputSource>] = [:]
    public init() {}
    public mutating func consume(_ event: NormalizedKeyEvent, isRepeat: Bool = false, source: KeyInputSource = .keyboard) -> NormalizedKeyEvent? {
        guard !isRepeat else { return nil }
        switch event.phase {
        case .down:
            var sources = owners[event.physicalKeyID, default: []]
            guard sources.insert(source).inserted else { return nil }
            owners[event.physicalKeyID] = sources
            guard pressed.insert(event.physicalKeyID).inserted else { return nil }
        case .up:
            guard var sources = owners[event.physicalKeyID], sources.remove(source) != nil else { return nil }
            if !sources.isEmpty { owners[event.physicalKeyID] = sources; return nil }
            owners.removeValue(forKey: event.physicalKeyID)
            guard pressed.remove(event.physicalKeyID) != nil else { return nil }
        case .pulse: break
        }
        return event
    }
    public mutating func reset() { pressed.removeAll(); owners.removeAll() }
}
