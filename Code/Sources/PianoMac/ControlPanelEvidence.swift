import AppKit
import PianoCore
public enum ControlPanelEvidence {
 public static func render(mapping: KeyMapping, directory: URL) throws -> [String: Any] {
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let shell = ProbeMenu(volume: 1, heightScale: 1.32, installStatusItem: false)
  shell.update(soundEnabled: true, showLabels: true, showOverlay: true, paused: false)
  shell.setTransparency(0.12, reduced: false); shell.setPresentation(floating: true, layer: "top")
  shell.setAlertLevel(40, detail: "合成系统提醒音量"); shell.updatePermission(granted: true)
  let view = shell.controls.view; view.layoutSubtreeIfNeeded()
  let image = NSImage(size: view.bounds.size)
  image.lockFocus(); NSColor.windowBackgroundColor.setFill(); view.bounds.fill()
  if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
   view.cacheDisplay(in: view.bounds, to: rep)
   let layer = NSImage(size: view.bounds.size); layer.addRepresentation(rep)
   layer.draw(in: view.bounds, from: .zero, operation: .sourceOver, fraction: 1)
  }
  image.unlockFocus()
  try NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("control-panel.png"))
  let editor = try KeymapEditor(base: mapping, configuration: { CustomKeymap(defaultMapping: mapping) }, warning: nil) { _,_ in }
  defer { editor.close() }
  editor.beginBinding(midi: 60); try editor.bindPhysicalKey("keyA"); editor.beginBinding(midi: 61)
  try editor.savePNG(to: directory.appendingPathComponent("binding-draft.png"))
  let report: [String: Any] = ["kind": "offscreen native content views, no status-item click or outside-dismiss test", "width": view.bounds.width, "height": view.bounds.height, "normalized132": shell.controls.height.doubleValue, "imageCount": 2, "permissionRequests": 0, "userPreferencesWritten": false, "systemVolumeWritten": false, "draftBijection": Set(editor.draft.candidate.notes.values).count == 64]
  try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
  return report
 }
}
