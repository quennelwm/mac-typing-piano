import AppKit
import CoreGraphics
import Foundation
import PianoCore

struct DockWindowEvidence {
    let pid: Int32
    let id: UInt32
    let layer: Int
    let bounds: CGRect
    let alpha: Double
}
enum DockWindowMatcher {
    static func sameBounds(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX-b.minX) <= 1 && abs(a.minY-b.minY) <= 1 && abs(a.width-b.width) <= 1 && abs(a.height-b.height) <= 1
    }
    static func candidate(in rows: [DockWindowEvidence], dockPID: Int32, screen: CGRect) -> DockWindowEvidence? {
        let matches = rows.filter { $0.pid == dockPID && $0.layer == 20 && sameBounds($0.bounds, screen) }
        return matches.count == 1 ? matches[0] : nil
    }
    static func visibility(tracked: DockWindowEvidence, onscreen: [DockWindowEvidence]?, orientation: String) -> DockVisibility {
        if orientation == "left" || orientation == "right" { return .hidden }
        guard orientation == "bottom", let onscreen else { return .unknown }
        guard let current = onscreen.first(where: { $0.id == tracked.id }) else { return .hidden }
        guard current.pid == tracked.pid, current.layer == 20, sameBounds(current.bounds, tracked.bounds) else { return .unknown }
        return current.alpha > 0 ? .visible : .hidden
    }
}
/// Host-calibrated Dock layer20 full-display window membership. No pixel capture or permissions.
/// Cache discovery for two seconds; ordinary ticks query only the onscreen list once.
public final class DockWindowVisibilityObserver {
    public init() {}
    private var tracked: DockWindowEvidence?
    private var lastDiscovery = -Double.infinity
    private var displayBounds = CGRect.null
    private var orientation = "bottom"
    public private(set) var detail = "Dock识别尚未采样"
    func invalidate() { lastDiscovery = -Double.infinity; tracked = nil }
    private func parse(_ row: [String: Any]) -> DockWindowEvidence? {
        guard let pid = row[kCGWindowOwnerPID as String] as? NSNumber,
              let number = row[kCGWindowNumber as String] as? NSNumber,
              let layer = row[kCGWindowLayer as String] as? NSNumber,
              let data = row[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: data),
              let alpha = row[kCGWindowAlpha as String] as? NSNumber else { return nil }
        return .init(pid: pid.int32Value, id: number.uint32Value, layer: layer.intValue, bounds: bounds, alpha: alpha.doubleValue)
    }
    public func observe(screenBounds: CGRect, at time: TimeInterval) -> DockVisibility {
        if screenBounds != displayBounds { displayBounds = screenBounds; invalidate() }
        if time - lastDiscovery >= 2 {
            lastDiscovery = time; tracked = nil
            // Unset is the native bottom default, also confirmed in the PM's system-settings observation.
            orientation = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom"
            if let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
               let all = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] {
                let owned = all.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }.compactMap(parse)
                tracked = DockWindowMatcher.candidate(in: owned, dockPID: pid, screen: screenBounds)
            }
        }
        guard let tracked else { detail = "未知：未找到唯一匹配目标屏幕的Dock layer20窗口"; return .unknown }
        let onscreen = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]])?.filter {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == tracked.id
        }.compactMap(parse)
        let state = DockWindowMatcher.visibility(tracked: tracked, onscreen: onscreen, orientation: orientation)
        detail = "\(state.rawValue)：Dock PID\(tracked.pid)/window\(tracked.id)/layer20，onScreenOnly，orientation=\(orientation)"
        return state
    }
}
