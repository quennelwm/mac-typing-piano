import AppKit
import CoreGraphics
import Darwin
import Foundation
let path="/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
guard let h=dlopen(path,RTLD_LAZY|RTLD_LOCAL),let g=dlsym(h,"CoreDockGetAutoHideEnabled"),let s=dlsym(h,"CoreDockSetAutoHideEnabled") else {fatalError("Native Dock function unavailable; no writes")}
let get=unsafeBitCast(g,to:(@convention(c) () -> UInt8).self)
let set=unsafeBitCast(s,to:(@convention(c) (UInt8) -> Void).self)
let original=get();guard original==1 else {fatalError("User state changed; no writes")}
defer { set(original);dlclose(h) }
func snapshot(_ name:String)->[String:Any] {
 let pid=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.dock").first?.processIdentifier ?? 0
 let windows=(CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] ?? []).filter{($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid}.map{w -> [String:Any] in var r:[String:Any]=[:];for k in [kCGWindowNumber,kCGWindowLayer,kCGWindowBounds,kCGWindowIsOnscreen] {if let v=w[k as String]{r[k as String]=v}};return r}
 return ["stage":name,"nativeAutohide":get(),"dockPID":pid,"onscreenDockWindows":windows,"screens":NSScreen.screens.map{NSStringFromRect($0.visibleFrame)}]
}
var rows=[snapshot("before")]
set(0);RunLoop.main.run(until:Date().addingTimeInterval(1));rows.append(snapshot("native-disabled"))
set(1);RunLoop.main.run(until:Date().addingTimeInterval(1));rows.append(snapshot("native-enabled-restored"))
print(String(decoding:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
