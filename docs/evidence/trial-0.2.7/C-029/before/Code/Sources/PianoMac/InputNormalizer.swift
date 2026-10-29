import Foundation
import CoreGraphics
import PianoCore

public struct InputNormalizer {
    public enum Kind { case down, up, flags }
    private let keys: [UInt16: KeyMapping.Key]
    public init(mapping: KeyMapping) throws { keys = try SDKKeys.resolve(mapping) }
    public func normalize(code: UInt16, kind: Kind, flags: UInt64 = 0, isRepeat: Bool = false, time: TimeInterval = 0) -> NormalizedKeyEvent? {
        guard !isRepeat, let key = keys[code] else { return nil }
        let phase: KeyPhase
        if key.eventSemantics == "ordinary" {
            guard kind != .flags else { return nil }
            phase = kind == .down ? .down : .up
        } else {
            guard kind == .flags else { return nil }
            if key.eventSemantics == "toggleCandidate" { phase = .pulse }
            else {
                // Public SDK IOKit/hidsystem/IOLLEvent.h NX_DEVICE* masks.
                // Never infer sides from the aggregate NSEvent modifier bit.
                let sideMask: [String: UInt64] = ["shiftLeft": 0x2, "shiftRight": 0x4,
                    "commandLeft": 0x8, "commandRight": 0x10, "optionLeft": 0x20,
                    "optionRight": 0x40, "controlLeft": 0x1, "fn": 0x800000]
                guard let mask = sideMask[key.physicalKeyID] else { return nil }
                phase = flags & mask != 0 ? .down : .up
            }
        }
        return NormalizedKeyEvent(key.physicalKeyID, phase, time: time, capability: "unverified")
    }
}
