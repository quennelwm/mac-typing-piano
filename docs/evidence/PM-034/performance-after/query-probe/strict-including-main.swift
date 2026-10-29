import Foundation
import AppKit
import CoreGraphics
import Darwin
struct Row {
 let id: UInt32; let pid: Int32; let layer: Int; let bounds: CGRect; let alpha: Double
 init?(_ d: [String:Any]) {
  guard let id=d[kCGWindowNumber as String] as? NSNumber, let pid=d[kCGWindowOwnerPID as String] as? NSNumber, let layer=d[kCGWindowLayer as String] as? NSNumber, let b=d[kCGWindowBounds as String] as? NSDictionary,let bounds=CGRect(dictionaryRepresentation:b),let alpha=d[kCGWindowAlpha as String] as? NSNumber else{return nil}
  self.id=id.uint32Value;self.pid=pid.int32Value;self.layer=layer.intValue;self.bounds=bounds;self.alpha=alpha.doubleValue
 }
}
func same(_ a:CGRect,_ b:CGRect)->Bool { abs(a.minX-b.minX)<=1 && abs(a.minY-b.minY)<=1 && abs(a.width-b.width)<=1 && abs(a.height-b.height)<=1 }
func cpu()->Double{var t=timespec();clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);return Double(t.tv_sec)+Double(t.tv_nsec)/1e9}
func wall()->Double{ProcessInfo.processInfo.systemUptime}
let timestamp=ISO8601DateFormatter()
guard let screen=NSScreen.screens.first(where: { s in guard let id=s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else{return false};return CGDisplayIsBuiltin(id.uint32Value) != 0 }) ?? NSScreen.main,let display=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,let dockPID=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.dock").first?.processIdentifier else{fatalError("No target display/Dock")}
let bounds=CGDisplayBounds(display.uint32Value)
let all=(CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]]) ?? []
let candidates=all.filter{($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dockPID}.compactMap(Row.init).filter{$0.layer==20 && same($0.bounds,bounds)}
func fail(_ detail:String)->Never { let d=try! JSONSerialization.data(withJSONObject:["status":"UNKNOWN", "detail":detail,"candidateCount":candidates.count,"screenBounds":NSStringFromRect(bounds),"dockRows":all.filter{($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==dockPID}.compactMap(Row.init).map{["id":String($0.id),"layer":String($0.layer),"bounds":NSStringFromRect($0.bounds)]}],options:[.prettyPrinted,.sortedKeys]);try! d.write(to:URL(fileURLWithPath:CommandLine.arguments[1]));print(String(data:d,encoding:.utf8)!);exit(2) }
guard candidates.count==1,let tracked=candidates.first else{fail("No unique display-sized Dock layer20 candidate")}
let referenceSetupStart=wall(),referenceCPUStart=cpu()
let reference=TPCreateReference(tracked.id)
let referenceSetupWall=wall()-referenceSetupStart, referenceSetupCPU=cpu()-referenceCPUStart
if let reference {
guard CFArrayGetCount(reference)==1 else{fail("Reference count = \(CFArrayGetCount(reference))")}
guard let verified=(CGWindowListCreateDescriptionFromArray(reference) as? [[String:Any]])?.compactMap(Row.init),verified.count==1,verified[0].id==tracked.id else{fail("Reference description could not validate tracked ID")}
}
func state(_ rows:[Row]?,absent:Bool=false)->String{
 if absent{return "hidden"};guard let rows else{return "unknown"};guard let r=rows.first(where:{$0.id==tracked.id}) else{return "hidden"}
 guard r.pid==tracked.pid,r.layer==20,same(r.bounds,tracked.bounds) else{return "unknown"};return r.alpha>0 ? "visible":"hidden"
}
func full()->String{autoreleasepool{state((CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]])?.filter{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==tracked.id}.compactMap(Row.init))}}
func narrow()->String{autoreleasepool{guard let reference else{return "unavailable"};var member:Int32 = -1;let rows=TPCreateOnscreenTrackedDescription(reference,&member);if member == -1{return "unknown"};if member==0{return "hidden"};guard let dicts=rows as? [[String:Any]] else{return "unknown"};return state(dicts.compactMap(Row.init))}}
func including()->String{autoreleasepool{
 guard let dicts=CGWindowListCopyWindowInfo(.optionIncludingWindow,tracked.id) as? [[String:Any]],let d=dicts.first(where:{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==tracked.id}),let r=Row(d),r.pid==tracked.pid,r.layer==20,same(r.bounds,tracked.bounds) else{return "unknown"}
 let onscreen=(d[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
 return onscreen && r.alpha>0 ? "visible":"hidden"
}}
func stats(_ a:[Double])->[String:Double]{let s=a.sorted();return ["mean":a.reduce(0,+)/Double(a.count),"p50":s[s.count/2],"p95":s[Int(Double(s.count-1)*0.95)],"total":a.reduce(0,+)]}
var results:[[String:Any]]=[]
let start=timestamp.string(from:Date())
for n in [100,200]{
 var fc:[Double]=[],fw:[Double]=[],nc:[Double]=[],nw:[Double]=[];var ic:[Double]=[],iw:[Double]=[];var pairs:[String:Int]=[:];var mismatches=0;var simpleMismatch=0;var simplePairs:[String:Int]=[:]
 for i in 0..<n{
  var a="",b="",c=""
  func measure(_ fn:()->String,_ cpuValues:inout [Double],_ wallValues:inout [Double])->String{let c=cpu(),w=wall();let value=fn();let we=wall(),ce=cpu();cpuValues.append((ce-c)*1000);wallValues.append((we-w)*1000);return value}
  if i%2==0{a=measure(full,&fc,&fw);b=measure(narrow,&nc,&nw);c=measure(including,&ic,&iw)}else{c=measure(including,&ic,&iw);b=measure(narrow,&nc,&nw);a=measure(full,&fc,&fw)}
  pairs[a+"/"+b,default:0]+=1;if a != b {mismatches+=1};simplePairs[a+"/"+c,default:0]+=1;if a != c{simpleMismatch+=1}
  Thread.sleep(forTimeInterval:0.1) // paced observation only; not counted in call timings.
 }
 results.append(["iterations":n,"fullCPUms":stats(fc),"fullWallms":stats(fw),"idThenOneDescriptionCPUms":stats(nc),"idThenOneDescriptionWallms":stats(nw),"statePairs":pairs,"mismatches":mismatches,"includingCPUms":stats(ic),"includingWallms":stats(iw),"includingStatePairs":simplePairs,"includingMismatches":simpleMismatch])
}
let report:[String:Any]=["startAt":start,"endAt":timestamp.string(from:Date()),"OS":ProcessInfo.processInfo.operatingSystemVersionString,"trackedDockPID":dockPID,"trackedDockWindowID":tracked.id,"orientation":UserDefaults(suiteName:"com.apple.dock")?.string(forKey:"orientation") ?? "bottom","referenceCount":reference.map{CFArrayGetCount($0)} ?? 0,"referenceSetupWallms":referenceSetupWall*1000,"referenceSetupCPUms":referenceSetupCPU*1000,"idCandidateAvailable":reference != nil,"runs":results,"condition":"Read-only uncontrolled observation, alternating adjacent queries, no GUI/input/setting changes. Per-call CPU/wall exclude 100ms pacing. Other window descriptions never logged.","race":"Two-stage candidate is not an atomic snapshot. Dock visibility may change between ID membership and description. Sequential parity cannot prove equivalence across transitions." ]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]));print(String(data:data,encoding:.utf8)!)
