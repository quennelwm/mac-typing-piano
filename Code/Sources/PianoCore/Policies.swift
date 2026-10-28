import Foundation
public struct DockAvoidance {
    public private(set) var hidden = false
    public private(set) var latched = false
    private var safeSince: TimeInterval?
    public init() {}
    public mutating func update(nearEdge: Bool, recoverySafe: Bool, mouseDown: Bool, dockFrontmost: Bool, time: TimeInterval) -> Bool {
        if mouseDown || dockFrontmost { latched = true }
        if nearEdge || latched { hidden = true; safeSince = nil }
        else if recoverySafe {
            if safeSince == nil { safeSince = time }
            if time - (safeSince ?? time) >= 0.4 { hidden = false }
        } else { safeSince = nil }
        return hidden
    }
    public mutating func acknowledge() { latched = false; safeSince = nil }
}
public struct ProbePreferences {
    public static let dockWarning = "关闭自动隐藏后，Dock 可能与底部钢琴重叠或遮挡。仍要关闭吗？"
    public var labelsVisible = true
    public private(set) var desiredDockAutoHide = true
    public private(set) var confirmationPending = false
    public init() {}
    public mutating func requestDockAutoHide(_ value: Bool) {
        if value { desiredDockAutoHide = true; confirmationPending = false }
        else { confirmationPending = true }
    }
    public mutating func resolveDockConfirmation(disable: Bool) {
        guard confirmationPending else { return }
        if disable { desiredDockAutoHide = false }
        confirmationPending = false
    }
}
