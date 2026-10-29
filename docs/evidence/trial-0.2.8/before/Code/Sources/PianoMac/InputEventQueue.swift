import Foundation
import PianoCore

/// Main-run-loop capture state, updated before asynchronous delivery to the coordinator.
/// Contains only transient held identities; never persists a typing history.
final class InputEventQueue {
    private var epoch: UInt64 = 0
    private var capturedHeld = Set<String>()
    func observe(_ event: NormalizedKeyEvent) {
        switch event.phase {
        case .down: capturedHeld.insert(event.physicalKeyID)
        case .up: capturedHeld.remove(event.physicalKeyID)
        case .pulse: break
        }
    }
    func enqueue(_ event: NormalizedKeyEvent, deliver: @escaping (NormalizedKeyEvent) -> Void) {
        observe(event)
        let expected = epoch
        DispatchQueue.main.async { [weak self] in
            guard let self, self.epoch == expected else { return }
            deliver(event)
        }
    }
    /// An already captured up is reflected even if its old queued delivery is discarded.
    func discardPending() -> Set<String> { epoch &+= 1; return capturedHeld }
    func reset() { epoch &+= 1; capturedHeld.removeAll() }
}
