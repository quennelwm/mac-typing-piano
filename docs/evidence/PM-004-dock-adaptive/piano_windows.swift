import AppKit
import CoreGraphics
import Foundation
let pids=Set(NSRunningApplication.runningApplications(withBundleIdentifier:"local.typingpiano.trial").map{$0.processIdentifier})
let all=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
let rows=all.filter {guard let p=($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else{return false};return pids.contains(p)}.map{w -> [String:Any] in var r:[String:Any]=[:];for k in [kCGWindowOwnerPID,kCGWindowNumber,kCGWindowBounds,kCGWindowLayer,kCGWindowIsOnscreen,kCGWindowAlpha] {if let v=w[k as String]{r[k as String]=v}};return r}
print(String(decoding:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
