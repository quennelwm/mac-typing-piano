import Foundation

public enum DockVisibility: String { case visible, hidden, unknown }
/// Pure visual policy; has no input/audio references or asynchronous completion callbacks.
public struct DockFade {
    public private(set) var dockHidden = false
    public private(set) var generation: UInt64 = 0
    private var hiddenSince: TimeInterval?
    private var unknownSince: TimeInterval?
    private var from = 1.0, target = 1.0, start = 0.0, duration = 0.0
    private var reduced = false
    public init(initialVisibility: DockVisibility = .unknown) {
        if initialVisibility == .visible { dockHidden = true; from = 0; target = 0 }
    }
    public func alpha(at time: TimeInterval) -> Double {
        guard duration > 0 else { return target }
        let u = min(1, max(0, (time - start) / duration))
        let eased = reduced ? u : 3*u*u - 2*u*u*u
        return from + (target - from) * eased
    }
    public func isAnimating(at time: TimeInterval) -> Bool { duration > 0 && time < start + duration }
    private mutating func redirect(to value: Double, at time: TimeInterval, current: Double? = nil) {
        from = current ?? alpha(at: time); target = value; start = time
        duration = (reduced ? 0.08 : (value == 0 ? 0.26 : 0.36)) * abs(target - from)
        generation &+= 1
    }
    public mutating func setReducedMotion(_ value: Bool, at time: TimeInterval) {
        guard value != reduced else { return }
        let current = alpha(at: time); reduced = value
        redirect(to: target, at: time, current: current)
    }
    public mutating func observe(_ state: DockVisibility, at time: TimeInterval) {
        switch state {
        case .visible:
            unknownSince = nil; hiddenSince = nil
            if !dockHidden { dockHidden = true; redirect(to: 0, at: time) }
        case .hidden:
            unknownSince = nil
            guard dockHidden else { hiddenSince = nil; return }
            if hiddenSince == nil { hiddenSince = time }
            if time - (hiddenSince ?? time) >= 0.12 {
                hiddenSince = nil; dockHidden = false; redirect(to: 1, at: time)
            }
        case .unknown:
            hiddenSince = nil
            if unknownSince == nil { unknownSince = time }
            if dockHidden && time - (unknownSince ?? time) >= 2 {
                dockHidden = false; redirect(to: 1, at: time)
            }
        }
    }
}
