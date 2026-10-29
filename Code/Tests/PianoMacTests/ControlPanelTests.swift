import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac
final class ControlPanelTests: XCTestCase {
 func testPreferenceMigrationAndNormalizedHeight() throws {
  let p = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"heightScale\":1.32}".utf8))
  XCTAssertTrue(p.floatingNotesEnabled); XCTAssertEqual(p.pianoLayer, .top)
  XCTAssertEqual(ControlPanel.normalizedHeight(p.heightScale), 0.630769, accuracy: 0.00001)
  XCTAssertEqual(ControlPanel.actualHeight(0), 0.5); XCTAssertEqual(ControlPanel.actualHeight(1), 1.8)
 }
 func testAlertSliderOwnsVerifiedValueAndRespectsExternalChanges() {
  let storage = Storage(); let adapter = AlertVolumeAdapter(storage: storage)
  adapter.refresh(); XCTAssertEqual(storage.writes, [])
  adapter.setVolume(45); XCTAssertEqual(adapter.originalVolume, 70)
  adapter.setVolume(20); XCTAssertEqual(adapter.originalVolume, 70)
  adapter.mute(confirmed:true); XCTAssertEqual(adapter.originalVolume,70)
  adapter.restore(); XCTAssertEqual(storage.value, 70)
  adapter.setVolume(30); storage.value = 60; adapter.restore(); XCTAssertEqual(storage.value, 60)
 }
 func testDirectBindingIsDraftOnlyAndCancellationDoesNotSave() throws {
  _ = NSApplication.shared
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
  let original = CustomKeymap(defaultMapping: mapping); var writes = 0
  let editor = try KeymapEditor(base: mapping, configuration: { original }, warning: nil) { _,_ in writes += 1 }
  defer { editor.close() }
  let midi = original.notes["keyG"]!
  editor.beginBinding(midi: midi); try editor.bindPhysicalKey("keyA")
  XCTAssertEqual(editor.draft.candidate.notes["keyA"], midi)
  XCTAssertEqual(Set(editor.draft.candidate.notes.values).count, 64)
  XCTAssertEqual(writes, 0); editor.cancel(); XCTAssertEqual(writes, 0)
 }
 func testPausedControlsPersistWithoutStartingAndLayerDoesNotInterruptHeldInput() throws {
  _ = NSApplication.shared
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: dir) }
  let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
  let storage = Storage()
  let controller = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename)), sources: AudioSource.available(root: root, bundled: false), preferencesURL: dir.appendingPathComponent("preferences.json"), input: input, audioEngine: engine, installStatusItem: false, alertVolume: AlertVolumeAdapter(storage: storage), secureInputCheck: { false }, permissionCheck: { true })
  controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
  defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
  controller.toggleFloatingNotes(); controller.toggleSound(); controller.changeLayer("bottom"); controller.flushPreferences()
  XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
  let saved = try AppPreferences.load(from: dir.appendingPathComponent("preferences.json"))
  XCTAssertFalse(saved.floatingNotesEnabled); XCTAssertFalse(saved.soundEnabled); XCTAssertEqual(saved.pianoLayer, .bottom)
  controller.start(global: true); controller.toggleSound(); input.onEvent?(.init("keyG", .down))
  let held = controller.integrationState.activeKeys, panics = engine.panics
  controller.changeLayer("top"); controller.toggleFloatingNotes()
  XCTAssertEqual(controller.integrationState.activeKeys, held); XCTAssertEqual(engine.panics, panics)
  controller.changeAlertVolume(0.2); controller.changeAlertVolume(0.3)
  XCTAssertTrue(storage.writes.isEmpty); controller.flushAlertVolume(); XCTAssertEqual(storage.writes,[30])
  controller.statusMenu?.onCustomize?()
  XCTAssertEqual(input.mode,.stopped)
  controller.start(global:true); XCTAssertEqual(input.mode,.stopped)
  for window in NSApp.windows where window.title == "自定义键位" && window.isVisible { window.close() }
  controller.start(global:true); XCTAssertEqual(input.mode,.global)
 }
 func testUnchangedFloatingSettingDoesNotInvalidateOrResetHeldAnimation() throws {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let view = PianoView(mapping: try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename)), frame: NSRect(x:0,y:0,width:1264,height:256))
  view.automaticAnimation = false; view.floatingNotesEnabled = false; view.activeMIDI = [60]
  view.needsDisplay = false; view.floatingNotesEnabled = false; view.setFrameSize(view.frame.size)
  XCTAssertFalse(view.needsDisplay); XCTAssertEqual(view.activeMIDI, [60])
 }
 func testAllFourTracksReceiveHitsWithinContent() {
  let panel = ControlPanel(); _ = panel.view
  for slider in [panel.height, panel.transparency, panel.volume, panel.alerts] {
   for fraction in [0.1,0.5,0.9] {
    let point = NSPoint(x: slider.frame.minX + slider.frame.width * fraction, y: slider.frame.midY)
    let hit = panel.view.hitTest(point)
    XCTAssertTrue(hit === slider || hit?.isDescendant(of: slider) == true)
   }
  }
 }
 func testCommandShortcutDoesNotBindCommandButStandaloneModifierDoes() throws {
  _ = NSApplication.shared
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let mapping = try KeyMapping.load(url:root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
  let original = CustomKeymap(defaultMapping:mapping); var saves = 0
  let editor = try KeymapEditor(base:mapping,configuration:{ original },warning:nil) { _,_ in saves += 1 }
  defer { editor.close() }
  func event(_ code: UInt16, _ type: CGEventType, _ flags: UInt64) -> NSEvent {
   let e = CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true)!
   e.type = type; e.flags = CGEventFlags(rawValue:flags)
   return NSEvent(cgEvent:e)!
  }
  let down = event(55,.flagsChanged,0x100008), up = event(55,.flagsChanged,0)
  editor.beginBinding(midi:60); _ = editor.processBindingEvent(down,focused:true)
  XCTAssertEqual(editor.draft.candidate, original); XCTAssertEqual(editor.waitingMIDI,60)
  _ = editor.processBindingEvent(event(1,.keyDown,0x100008),focused:true)
  XCTAssertEqual(editor.draft.candidate,original); XCTAssertEqual(saves,0); XCTAssertNil(editor.waitingMIDI)
  editor.beginBinding(midi:60); _ = editor.processBindingEvent(down,focused:true); _ = editor.processBindingEvent(up,focused:true)
  XCTAssertEqual(editor.draft.candidate.notes["commandLeft"],60); XCTAssertEqual(saves,0)
  editor.beginBinding(midi:60)
  XCTAssertNil(editor.processBindingEvent(event(36,.keyDown,0),focused:true))
  let repeatedCG = CGEvent(keyboardEventSource:nil,virtualKey:36,keyDown:true)!
  repeatedCG.setIntegerValueField(.keyboardEventAutorepeat,value:1)
  XCTAssertNil(editor.processBindingEvent(NSEvent(cgEvent:repeatedCG)!,focused:true)); XCTAssertEqual(saves,0)
  XCTAssertNil(editor.processBindingEvent(event(36,.keyUp,0),focused:true))
  editor.beginBinding(midi:61); editor.windowDidResignKey(Notification(name:NSWindow.didResignKeyNotification))
  _ = editor.processBindingEvent(event(0,.keyDown,0),focused:false); XCTAssertNil(editor.waitingMIDI)
 }
 func testKeyCacheIsBoundedAndFloatingOnlyReusesStaticKeys() throws {
  let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let mapping = try KeyMapping.load(url:root.appendingPathComponent("contracts/"+KeyMapping.defaultFilename))
  let view = PianoView(mapping:mapping,frame:NSRect(x:0,y:0,width:1496,height:256)); view.automaticAnimation = false
  var notes = NoteCoordinator(mapping:mapping); _ = notes.consume(.init("keyG",.down)); view.strike(try XCTUnwrap(notes.lastStrike),at:0)
  for frame in 0..<20 { view.advanceAnimations(at:Double(frame)/60); _ = try view.renderedImage(scale:2) }
  XCTAssertEqual(view.keyLayerRenders,1); XCTAssertGreaterThan(view.floatingLayerRenders,1)
  XCTAssertLessThanOrEqual(view.keyCacheBytes,4*1024*1024)
  view.advanceAnimations(at:2); XCTAssertEqual(view.floatingCount,0)
 }
 final class Storage: AlertVolumeStorage {
  var value = 70; var writes: [Int] = []
  func read() throws -> Int { value }
  func write(_ volume: Int) throws { writes.append(volume); value = volume }
 }
}
