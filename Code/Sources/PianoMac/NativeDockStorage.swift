import Darwin
import Foundation
import PianoCore

/// Isolated, capability-checked private SPI, approved for this local trial only.
/// PM verified the UInt8 Boolean ABI and immediate Dock effect on this host.
/// No Apple Events, keyboard injection, Dock restart or defaults-write fallback.
public final class NativeDockStorage: DockAutohideStorage {
    typealias Getter = () -> UInt8
    typealias Setter = (UInt8) -> Void
    private var library: UnsafeMutableRawPointer?
    private let getter: Getter?
    private let setter: Setter?
    private let readPreference: () throws -> Bool?
    private let unavailable = "系统Dock原生接口不可用；请使用菜单“系统Dock设置…”直接调整。"
    public init() {
        let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY | RTLD_LOCAL)
        library = handle
        if let handle, let getAddress = dlsym(handle, "CoreDockGetAutoHideEnabled"),
           let setAddress = dlsym(handle, "CoreDockSetAutoHideEnabled") {
            let get = unsafeBitCast(getAddress, to: (@convention(c) () -> UInt8).self)
            let set = unsafeBitCast(setAddress, to: (@convention(c) (UInt8) -> Void).self)
            getter = { get() }; setter = { set($0) }
        } else { getter = nil; setter = nil }
        let preferences = DefaultsDockStorage()
        readPreference = { try preferences.read() } // Verification only. Never defaults.write.
    }
    init(getter: Getter?, setter: Setter?, readPreference: @escaping () throws -> Bool?) {
        self.getter = getter; self.setter = setter; self.readPreference = readPreference
    }
    deinit { if let library { dlclose(library) } }
    public func read() throws -> Bool? {
        guard let getter, setter != nil else { throw ProbeError.invalid(unavailable) }
        switch getter() {
        case 0: return false
        case 1: return true
        default: throw ProbeError.invalid("Dock原生状态读回无效；请通过系统Dock设置核对。")
        }
    }
    public func write(_ value: Bool) throws {
        guard let setter else { throw ProbeError.invalid(unavailable) }
        _ = try read() // Reject invalid ABI/state before invoking the setter.
        setter(value ? 1 : 0)
        guard try read() == value else {
            throw ProbeError.invalid("Dock原生状态未按请求变化；请通过系统Dock设置调整。")
        }
        guard try readPreference() == value else {
            throw ProbeError.invalid("Dock原生状态已变化，但偏好读回未核对成功；保留恢复票据，请在系统Dock设置核对。")
        }
    }
}
