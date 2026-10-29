import AppKit
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "local.typingpiano.trial")
let pids = Set(apps.map { $0.processIdentifier })
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter { info in
    guard let pid = info[kCGWindowOwnerPID as String] as? Int32 else { return false }; return pids.contains(pid)
}.map { info -> [String: Any] in
    var result: [String: Any] = [:]
    for key in [kCGWindowOwnerPID, kCGWindowBounds, kCGWindowLayer, kCGWindowAlpha, kCGWindowIsOnscreen] {
        if let value = info[key as String] { result[key as String] = value }
    }
    return result
}
let result: [String: Any] = ["runningInstances": apps.count, "windows": windows, "screenFrames": NSScreen.screens.map { NSStringFromRect($0.frame) }, "scope": "read-only current application window geometry; no screenshot, input capture, or settings changes"]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
