import Foundation
import Darwin
let path="/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
guard let h=dlopen(path, RTLD_LAZY|RTLD_LOCAL) else { print("unavailable");exit(2) }
defer {dlclose(h)}
guard let g=dlsym(h,"CoreDockGetAutoHideEnabled"), let s=dlsym(h,"CoreDockSetAutoHideEnabled") else {print("symbols missing");exit(2)}
let get=unsafeBitCast(g,to:(@convention(c) () -> UInt8).self)
print("CoreDock symbols present; native autohide=\(get()); read-only capability probe.")
