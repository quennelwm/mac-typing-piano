import Foundation
import CoreGraphics
let id=CGWindowID(CommandLine.arguments[1])!
var rows:[[String:Any]]=[]
for (name,option) in [("including",CGWindowListOption.optionIncludingWindow),("all",.optionAll),("onscreen",.optionOnScreenOnly)]{
 let raw=CGWindowListCopyWindowInfo(option,name=="including" ? id:kCGNullWindowID) as? [[String:Any]]
 let selected=raw?.filter{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==id}
 rows.append(["query":name,"arrayAvailable":raw != nil,"returnedCount":raw?.count ?? -1,"trackedMatches":selected?.count ?? -1,"trackedFields":selected?.map{d in Dictionary(uniqueKeysWithValues:[kCGWindowNumber,kCGWindowOwnerPID,kCGWindowLayer,kCGWindowAlpha,kCGWindowIsOnscreen].map{k in (k as String,d[k as String] ?? "missing")})} ?? []])
}
let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:CommandLine.arguments[2]));print(String(data:data,encoding:.utf8)!)
