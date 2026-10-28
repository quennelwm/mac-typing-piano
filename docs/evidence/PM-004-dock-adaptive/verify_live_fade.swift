import AppKit
import CoreGraphics
import Darwin
import Foundation
let apps=NSRunningApplication.runningApplications(withBundleIdentifier:"local.typingpiano.trial")
guard apps.count==1,let app=apps.first,let url=app.bundleURL, let version=Bundle(url:url)?.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,version=="0.2.4" else {fatalError("Need exactly one 0.2.4 GUI app; no mutation performed")}
let pid=app.processIdentifier
let all=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
let panels=all.filter{ w in
 guard (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid,let b=w[kCGWindowBounds as String] as? [String:Double] else{return false}
 return abs((b["Width"] ?? 0)-1496)<1 && abs((b["Height"] ?? 0)-104)<1
}
guard panels.count==1,let id=(panels[0][kCGWindowNumber as String] as? NSNumber)?.uint32Value,(panels[0][kCGWindowIsOnscreen as String] as? Bool)==true else {fatalError("Adaptive 1496x104 overlay must be visible before test; no mutation")}
let p="/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
guard let lib=dlopen(p,RTLD_LAZY|RTLD_LOCAL),let g=dlsym(lib,"CoreDockGetAutoHideEnabled"),let s=dlsym(lib,"CoreDockSetAutoHideEnabled") else {fatalError("Native interface unavailable")}
let get=unsafeBitCast(g,to:(@convention(c) () -> UInt8).self)
let set=unsafeBitCast(s,to:(@convention(c) (UInt8) -> Void).self)
guard get()==1 else {fatalError("Expected user autohide on; no mutation")}
defer{set(1);dlclose(lib)}
var samples=[[String:Any]]();let start=ProcessInfo.processInfo.systemUptime
func sample(_ phase:String) {
 let entries=CGWindowListCopyWindowInfo(.optionIncludingWindow,id) as? [[String:Any]] ?? []
 let w=entries.first{$0[kCGWindowNumber as String] as? UInt32==id}
 samples.append(["elapsed":ProcessInfo.processInfo.systemUptime-start,"phase":phase,"windowID":id,"present":w != nil,"onscreen":w?[kCGWindowIsOnscreen as String] as? Bool ?? false,"alpha":w?[kCGWindowAlpha as String] as? Double ?? -1])
}
func observe(_ phase:String,_ seconds:Double) {
 let until=ProcessInfo.processInfo.systemUptime+seconds
 repeat { sample(phase);Thread.sleep(forTimeInterval:0.02) } while ProcessInfo.processInfo.systemUptime<until
}
observe("dock-hidden-before",0.4)
set(0);observe("dock-visible",1.5)
set(1);observe("dock-hidden-after",1.6)
let result:[String:Any]=["appVersion":version,"appPID":pid,"pianoBounds":panels[0][kCGWindowBounds as String]!,"finalNativeAutohide":get(),"scope":"Live application window alpha and visibility only; native Dock toggled off then restored on; no input/audio state changed directly.","samples":samples]
print(String(decoding:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
