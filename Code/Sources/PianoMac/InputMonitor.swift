import AppKit
import Carbon
import CoreGraphics
import PianoCore

/// Finite, opt-in probe. No authorization request or event injection APIs.
/// All state belongs to the main run loop; callbacks only normalize and enqueue.
public final class InputMonitor {
    public enum Mode { case stopped, local, global }
    public private(set) var mode: Mode = .stopped
    public var onEvent: ((NormalizedKeyEvent) -> Void)?
    public var onStop: ((String) -> Void)?
    private let normalizer: InputNormalizer
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitor: Any?
    private var timer: Timer?
    private var epoch: UInt64 = 0
    private var accepting = false
    public static var hasExistingPermission: Bool { CGPreflightListenEventAccess() }
    public static var secureInput: Bool { IsSecureEventInputEnabled() }
    public init(mapping: KeyMapping) throws { normalizer = try InputNormalizer(mapping: mapping) }

    public func start(global: Bool) throws {
        precondition(Thread.isMainThread)
        stop()
        guard !Self.secureInput else { throw ProbeError.invalid("安全输入已启用；探针保持停止") }
        if global {
            guard Self.hasExistingPermission else {
                throw ProbeError.invalid("尚无输入监控授权。探针不会弹授权或改设置；请自行在系统设置中授权后重开测试，或用本窗口测试。")
            }
            let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
            guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    let owner = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
                    owner.receive(type: type, event: event)
                    return Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
                throw ProbeError.invalid("只观察监听器创建失败；未增加权限，未截获输入")
            }
            guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
                CFMachPortInvalidate(newTap)
                throw ProbeError.invalid("无法创建监听 run-loop source")
            }
            tap = newTap; source = newSource; mode = .global
            CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
            CGEvent.tapEnable(tap: newTap, enable: true)
        } else {
            mode = .local
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
                guard let self else { return event }
                if Self.secureInput { self.fail("安全输入阻断"); return event }
                let kind: InputNormalizer.Kind = event.type == .keyDown ? .down : event.type == .keyUp ? .up : .flags
                let repeatFlag = event.type == .keyDown ? event.isARepeat : false
                self.enqueue(self.normalizer.normalize(code: event.keyCode, kind: kind,
                    flags: UInt64(event.modifierFlags.rawValue), isRepeat: repeatFlag, time: event.timestamp))
                return event
            }
        }
        accepting = true
        let start = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if ProcessInfo.processInfo.systemUptime - start >= 60 { self.fail("60秒测试窗口结束") }
            else if Self.secureInput { self.fail("安全输入阻断") }
            else if self.mode == .global && !Self.hasExistingPermission { self.fail("输入监控授权已失效") }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    public func stop() {
        precondition(Thread.isMainThread)
        accepting = false; epoch &+= 1; timer?.invalidate(); timer = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil; mode = .stopped
    }
    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            fail("系统停用了监听器；已安全暂停，需手动重新测试"); return
        }
        guard accepting else { return }
        if Self.secureInput { fail("安全输入阻断"); return }
        let kind: InputNormalizer.Kind
        switch type { case .keyDown: kind = .down; case .keyUp: kind = .up; case .flagsChanged: kind = .flags; default: return }
        enqueue(normalizer.normalize(code: UInt16(event.getIntegerValueField(.keyboardEventKeycode)), kind: kind,
            flags: event.flags.rawValue, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            time: Double(event.timestamp) / 1_000_000_000))
    }
    private func enqueue(_ event: NormalizedKeyEvent?) {
        guard accepting, let event else { return }
        let expected = epoch
        DispatchQueue.main.async { [weak self] in
            guard let self, self.accepting, self.epoch == expected else { return }
            self.onEvent?(event)
        }
    }
    private func fail(_ reason: String) {
        guard accepting else { return }
        accepting = false; epoch &+= 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stop(); self.onStop?(reason)
        }
    }
}
