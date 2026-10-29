import AppKit
import Darwin
import PianoCore
public enum RenderBenchmark {
 public static func run(mapping: KeyMapping) throws -> [String: Any] {
  var view = PianoView(mapping: mapping, frame: NSRect(x:0,y:0,width:1496,height:256)); view.automaticAnimation = false
  var now = 0.0; view.clock = { now }
  func cpu() -> Double { var t = timespec(); clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t); return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9 }
  var samples: [Double] = []
  var scenarios: [[String: Any]] = []
  var walls: [Double] = []
  var coldCPU = 0.0, coldWall = 0.0
  for enabled in [false,true] { for scenario in ["static","floating-only","press-plus-floating"] {
  view = PianoView(mapping: mapping, frame:NSRect(x:0,y:0,width:1496,height:256)); view.automaticAnimation = false; view.clock = { now }
  view.cacheKeys = enabled
  samples = []; walls = []
  for frame in 0..<64 {
   let start = cpu(), wall = ProcessInfo.processInfo.systemUptime
   now = Double(frame)/60
   if scenario == "press-plus-floating" { view.activeMIDI = Set((33...96).filter { ($0 + frame/8) % 3 == 0 }) } else { view.activeMIDI = [] }
   if scenario != "static" && frame % 8 == 0 {
    var notes = NoteCoordinator(mapping: mapping); _ = notes.consume(.init("keyG", .down))
    if let strike = notes.lastStrike { view.strike(strike, at: now) }
   }
   view.advanceAnimations(at: now)
   try autoreleasepool { _ = try view.renderedImage(scale: 2) }
   if frame == 0 { coldCPU = (cpu()-start)*1000; coldWall = (ProcessInfo.processInfo.systemUptime-wall)*1000 }
   if frame >= 4 { samples.append((cpu()-start)*1000); walls.append((ProcessInfo.processInfo.systemUptime-wall)*1000) }
  }
  let sorted = samples.sorted()
  view.advanceAnimations(at: now + 2)
  scenarios.append(["coldCPUms":coldCPU,"coldWallms":coldWall,"p95Wallms":walls.sorted()[Int(Double(walls.count-1)*0.95)],"keyLayerRenders":view.keyLayerRenders,"floatingLayerRenders":view.floatingLayerRenders,"finalFloatingCount":view.floatingCount,"scenario":scenario,"cacheEnabled":enabled,"frames":samples.count,"p50CPUms":sorted[sorted.count/2],"p95CPUms":sorted[Int(Double(sorted.count-1)*0.95)],"meanCPUms":samples.reduce(0,+)/Double(samples.count),"retainedKeyCacheBytes":view.keyCacheBytes])
  } }
  return ["kind":"paired same-process offline CPU milliseconds per production frame, no PNG IO; NOT hosted frame pacing", "canvasPt":[1496,256],"scale":2,"scenarios":scenarios,"cacheLimitPerViewBytes":4*1024*1024]
 }
}
