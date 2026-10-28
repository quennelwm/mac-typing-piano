import Foundation
import Darwin
let path="/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
guard let h=dlopen(path, RTLD_LAZY|RTLD_LOCAL) else { print("unavailable");exit(2) }
defer {dlclose(h)}
guard let g=dlsym(h,"CoreDockGetAutoHideEnabled"), let s=dlsym(h,"CoreDockSetAutoHideEnabled") else {print("symbols missing");exit(2)}
let get=unsafeBitCast(g,to:(@convention(c) () -> UInt8).self)
let set=unsafeBitCast(s,to:(@convention(c) (UInt8)->Void).self)
guard get()==1 else {fatalError("Unexpected current setting; no writes")}
defer {set(1)}
var result=[[String:Any]]()
for value:UInt8 in [0,1] {
 set(value)
 let native=get()
 let process=Process(),pipe=Pipe();process.executableURL=URL(fileURLWithPath:"/usr/bin/defaults");process.arguments=["read","com.apple.dock","autohide"];process.standardOutput=pipe;try process.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
 let preference=String(decoding:data,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)
 result.append(["requested":value,"nativeImmediate":native,"preferenceImmediate":preference,"match":native==value && preference==String(value)])
}
print(String(decoding:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
