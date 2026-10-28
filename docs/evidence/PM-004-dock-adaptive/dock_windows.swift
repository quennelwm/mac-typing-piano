import Foundation
import AppKit
import CoreGraphics
let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
let rows = all.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == dock?.processIdentifier }.map { w in
    var r: [String:Any] = [:]
    for k in [kCGWindowNumber, kCGWindowBounds, kCGWindowLayer, kCGWindowIsOnscreen, kCGWindowAlpha] { if let v = w[k as String] {r[k as String] = v} }
    return r
}
let result: [String:Any] = ["scope":"Read-only Dock-owned window geometry only; no pixels, other-app data, or writes", "dockPID":dock?.processIdentifier ?? 0, "windows":rows, "screens":NSScreen.screens.map { ["frame":NSStringFromRect($0.frame),"visibleFrame":NSStringFromRect($0.visibleFrame)] }]
print(String(decoding:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
