import AppKit
import CoreGraphics
import Foundation
let end=Date().addingTimeInterval(180)
var previous=""
while Date()<end {
 let pid=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.dock").first?.processIdentifier ?? 0
 let windows=(CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []).filter{ ($0[kCGWindowOwnerPID as String] as? Int32)==pid }.map{w -> [String:Any] in
 var r:[String:Any]=[:]
 for k in [kCGWindowNumber,kCGWindowLayer,kCGWindowBounds,kCGWindowIsOnscreen,kCGWindowAlpha] {if let v=w[k as String] {r[k as String]=v}}
 return r
 }
 let serialized=String(decoding:try! JSONSerialization.data(withJSONObject:windows,options:[.sortedKeys]),as:UTF8.self)
 if serialized != previous { print(ISO8601DateFormatter().string(from:Date())+" "+serialized);fflush(stdout);previous=serialized }
 Thread.sleep(forTimeInterval:0.15)
}
