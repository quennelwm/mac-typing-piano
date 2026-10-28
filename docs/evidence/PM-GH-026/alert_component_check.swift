import AppKit
import Foundation

// Bounded native fixture for the production menu and alert-volume adapter.
// Launch through computer-use tools, click once to mute, then restore and quit.
// No input monitor, audio engine, Dock setting or App preference file is involved.
@main
struct AlertComponentCheck {
    static func main() {
        _ = NSApplication.shared
        let delegate = AlertCheckDelegate()
        NSApp.delegate = delegate
        NSApp.setActivationPolicy(.regular)
        NSApp.run()
        withExtendedLifetime(delegate) {}
    }
}
final class AlertCheckDelegate: NSObject, NSApplicationDelegate {
    let adapter = AlertVolumeAdapter(storage: StandardAdditionsAlertVolumeStorage())
    let output = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/local.typingpiano.trial/alert-component-live.json")
    var window: NSWindow!
    var menu: ProbeMenu!
    let label = NSTextField(wrappingLabelWithString: "尚未操作")
    var records: [[String: Any]] = []
    override init() {
        super.init()
        if let data = try? Data(contentsOf: output), let old = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let events = old["events"] as? [[String: Any]] { records = events }
    }
    func volumes() throws -> [String: Any] {
        let source = "set s to get volume settings\nreturn {output volume of s, input volume of s, alert volume of s, output muted of s}"
        var error: NSDictionary?
        let result = NSAppleScript(source: source)!.executeAndReturnError(&error)
        guard error == nil, result.numberOfItems == 4 else { throw NSError(domain: "VolumeSnapshot", code: 1) }
        return ["output": result.atIndex(1)!.int32Value, "input": result.atIndex(2)!.int32Value,
                "alert": result.atIndex(3)!.int32Value, "outputMuted": result.atIndex(4)!.booleanValue]
    }
    func record(_ action: String) {
        var entry: [String: Any] = ["action": action, "outcome": adapter.outcome.rawValue, "detail": adapter.detail,
            "date": ISO8601DateFormatter().string(from: Date())]
        do { entry["volumes"] = try volumes() } catch { entry["snapshotError"] = true }
        records.append(entry)
        let record: [String: Any] = ["scope": "production AlertVolumeAdapter and ProbeMenu component; not full candidate GUI/TCC or acoustic acceptance", "events": records]
        try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
        menu?.updateAlertVolume(muted: adapter.mutedState, detail: adapter.detail)
        label.stringValue = adapter.detail
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        menu = ProbeMenu(volume: 0.5, installStatusItem: true)
        menu.onMuteAlerts = { [weak self] in self?.toggle() }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 210), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "提示音组件验收"
        let stack = NSStackView(views: [label, button("静音系统提示音", #selector(toggle)), button("恢复原提示音并退出", #selector(restoreAndQuit))])
        stack.orientation = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)])
        adapter.refresh(); record("baseline")
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    @objc func toggle() {
        if adapter.hasOwnedChange { adapter.restore(); record("toggleRestore"); return }
        let alert = NSAlert(); alert.messageText = "临时静音系统提示音以验收"
        alert.informativeText = "只修改系统提示音，不改媒体或钢琴音量。测试后恢复原值；45秒后自动恢复并退出。"
        alert.addButton(withTitle: "确认测试"); alert.addButton(withTitle: "取消")
        adapter.mute(confirmed: alert.runModal() == .alertFirstButtonReturn); record("mute")
        Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in self?.restoreAndQuit() }
    }
    @objc func restoreAndQuit() { adapter.restore(); record("restore"); NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if adapter.hasOwnedChange { adapter.restore(); record("quitRestore") }
        return .terminateNow
    }
}
