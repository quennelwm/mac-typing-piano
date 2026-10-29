import AppKit
import CoreGraphics
import Foundation

// Read-only metadata probe. Never requests permission, captures pixels, moves the pointer,
// starts input/audio, writes preferences, or prints metadata belonging to other apps.
let count = min(600, max(1, CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 1 : 1))
let interval = min(2.0, max(0.05, CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 0.1 : 0.1))
func rect(_ r: CGRect) -> [String: Double] { ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height] }
for index in 0..<count {
    let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    let all = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]]
    let onscreen = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
    func owned(_ rows: [[String: Any]]?) -> [[String: Any]] {
        guard let pid else { return [] }
        return (rows ?? []).filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
    }
    let onscreenIDs = Set(owned(onscreen).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
    let windows = owned(all).map { row -> [String: Any] in
        var result: [String: Any] = [:]
        for key in [kCGWindowNumber,kCGWindowBounds,kCGWindowLayer,kCGWindowAlpha,kCGWindowIsOnscreen] {
            result[key as String] = row[key as String] ?? NSNull()
        }
        if let number = row[kCGWindowNumber as String] as? NSNumber {
            result["inOnscreenOnlySnapshot"] = onscreenValue(number.uint32Value, onscreenIDs, onscreen != nil)
        }
        return result
    }
    let result: [String: Any] = ["sample": index,"uptime":ProcessInfo.processInfo.systemUptime,
        "dockPID":pid.map { $0 as Any } ?? NSNull(),"allQuerySucceeded":all != nil,"onscreenQuerySucceeded":onscreen != nil,
        "dockWindows":windows,"screens":NSScreen.screens.map { ["frame":rect($0.frame),"visibleFrame":rect($0.visibleFrame)] },
        "scope":"Dock-only metadata; no pixels; raw observations, not a visibility conclusion"]
    let data = try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
    print(String(decoding:data,as:UTF8.self)); fflush(stdout)
    if index+1<count { Thread.sleep(forTimeInterval:interval) }
}
func onscreenValue(_ id: UInt32, _ values: Set<UInt32>, _ succeeded: Bool) -> Any {
    succeeded ? values.contains(id) as Any : NSNull()
}
