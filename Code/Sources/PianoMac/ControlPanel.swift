import AppKit

/// Ordinary controls in a transient popover, without NSMenu custom-view tracking.
public final class ControlPanel: NSViewController {
    public let running = NSButton(checkboxWithTitle: "键盘钢琴", target: nil, action: nil)
    public let floating = NSSwitch(), sound = NSSwitch()
    public let soundCheck = NSButton(checkboxWithTitle: "按键声音", target: nil, action: nil)
    public let height = NSSlider(), transparency = NSSlider(), volume = NSSlider(), alerts = NSSlider()
    public private(set) var permissionButton: NSButton?
    public let message = NSTextField(labelWithString: "")
    public var onRun: (() -> Void)?, onFloating: (() -> Void)?, onSound: (() -> Void)?
    public var onHeight: ((Double) -> Void)?, onTransparency: ((Double) -> Void)?, onVolume: ((Double) -> Void)?, onAlerts: ((Double) -> Void)?
    public var onCustomize: (() -> Void)?, onPermission: (() -> Void)?, onQuit: (() -> Void)?
    public var systemMenu: NSMenu?
    public static func normalizedHeight(_ actual: Double) -> Double { min(1, max(0, (actual - 0.5) / 1.3)) }
    public static func actualHeight(_ fraction: Double) -> Double { 0.5 + min(1, max(0, fraction)) * 1.3 }
    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 370))
        var y: CGFloat = 334
        func add(_ child: NSView, _ rect: NSRect) { child.frame = rect; view.addSubview(child) }
        func label(_ text: String, _ x: CGFloat, _ width: CGFloat) { let l = NSTextField(labelWithString: text); l.font = .systemFont(ofSize: 10); l.textColor = .secondaryLabelColor; add(l, NSRect(x: x, y: y + 4, width: width, height: 16)) }
        running.target = self; running.action = #selector(runAction)
        add(running, NSRect(x: 12, y: y, width: 114, height: 24)); label("演奏音符", 145, 56)
        floating.target = self; floating.action = #selector(floatAction); floating.setAccessibilityLabel("演奏音符")
        add(floating, NSRect(x: 212, y: y, width: 42, height: 24)); y -= 34
        func slider(_ title: String, _ control: NSSlider, _ action: Selector) {
            label(title, 28, 56); label("0%", 86, 24); label("100%", 227, 32)
            control.minValue = 0; control.maxValue = 1; control.isContinuous = true
            control.target = self; control.action = action; control.setAccessibilityLabel(title)
            add(control, NSRect(x: 111, y: y, width: 110, height: 24)); y -= 30
        }
        func separator() { let line = NSBox(); line.boxType = .separator; add(line, NSRect(x: 12, y: y + 16, width: 246, height: 1)); y -= 8 }
        slider("桌面高度", height, #selector(heightAction)); slider("透明度", transparency, #selector(transparencyAction)); separator()
        soundCheck.target = self; soundCheck.action = #selector(soundAction)
        add(soundCheck, NSRect(x: 12, y: y, width: 150, height: 24))
        sound.target = self; sound.action = #selector(soundAction); sound.setAccessibilityLabel("按键声音")
        add(sound, NSRect(x: 212, y: y, width: 42, height: 24)); y -= 32
        slider("音量大小", volume, #selector(volumeAction)); slider("提醒声音", alerts, #selector(alertAction)); separator()
        for (title, action) in [("自定义键位…", #selector(customAction)), ("键盘权限授权…", #selector(permissionAction)), ("系统设置  ›", #selector(systemAction)), ("退出软件", #selector(quitAction))] {
            let button = NSButton(title: title, target: self, action: action); button.isBordered = false; button.alignment = .left
            if title == "键盘权限授权…" { button.setButtonType(.switch); permissionButton = button }
            add(button, NSRect(x: 24, y: y, width: 232, height: 24)); y -= 26
        }
        message.font = .systemFont(ofSize: 10); message.textColor = .secondaryLabelColor
        add(message, NSRect(x: 14, y: 2, width: 242, height: 16))
    }
    @objc private func runAction() { onRun?() }
    @objc private func floatAction() { onFloating?() }
    @objc private func soundAction() { onSound?() }
    @objc private func heightAction() { onHeight?(Self.actualHeight(height.doubleValue)) }
    @objc private func transparencyAction() { onTransparency?(transparency.doubleValue) }
    @objc private func volumeAction() { onVolume?(volume.doubleValue) }
    @objc private func alertAction() { onAlerts?(alerts.doubleValue) }
    @objc private func customAction() { onCustomize?() }
    @objc private func permissionAction() { onPermission?() }
    @objc private func quitAction() { onQuit?() }
    @objc private func systemAction(_ sender: NSButton) { systemMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender) }
}
