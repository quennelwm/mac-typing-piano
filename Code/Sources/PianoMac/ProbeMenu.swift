import AppKit

/// CR-003 minimal menu shell. The slider is a native embedded continuous control.
public final class ProbeMenu: NSObject, NSMenuDelegate {
    public let menu = NSMenu()
    public let slider: NSSlider
    public let percentage = NSTextField(labelWithString: "50%")
    public let icon: NSImage
    public var onVolume: ((Double) -> Void)?
    public var onOpen: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onSound: (() -> Void)?
    public var onLabels: (() -> Void)?
    public var onOverlay: (() -> Void)?
    public var onGlobal: (() -> Void)?
    public var onLocal: (() -> Void)?
    private var statusItem: NSStatusItem?
    private let sound = NSMenuItem(title: "声音（合成占位）", action: nil, keyEquivalent: "")
    private let labels = NSMenuItem(title: "显示按键标签", action: nil, keyEquivalent: "")
    private let overlay = NSMenuItem(title: "显示钢琴探针", action: nil, keyEquivalent: "")
    public init(volume: Double, installStatusItem: Bool = true) {
        slider = NSSlider(value: volume, minValue: 0, maxValue: 1, target: nil, action: nil)
        icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let text = NSAttributedString(string: "♪", attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.black])
            text.draw(at: NSPoint(x: (rect.width - text.size().width) / 2, y: (rect.height - text.size().height) / 2))
            return true
        }
        icon.isTemplate = true
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        add("打开测试控制台…", #selector(openControl))
        add("全局观察60秒", #selector(startGlobal))
        add("本窗口测试60秒", #selector(startLocal))
        add("暂停全部", #selector(pauseAll))
        menu.addItem(.separator())
        sound.action = #selector(toggleSound); sound.target = self; menu.addItem(sound)
        let volumeItem = NSMenuItem()
        let volumeView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 42))
        let label = NSTextField(labelWithString: "音量")
        label.frame = NSRect(x: 12, y: 12, width: 34, height: 18)
        slider.frame = NSRect(x: 48, y: 10, width: 145, height: 22)
        slider.isContinuous = true; slider.target = self; slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel("打字钢琴音量，仅控制本App")
        percentage.frame = NSRect(x: 199, y: 12, width: 42, height: 18)
        percentage.alignment = .right
        volumeView.addSubview(label); volumeView.addSubview(slider); volumeView.addSubview(percentage)
        volumeItem.view = volumeView; menu.addItem(volumeItem)
        overlay.action = #selector(toggleOverlay); overlay.target = self; menu.addItem(overlay)
        labels.action = #selector(toggleLabels); labels.target = self; menu.addItem(labels)
        let pending = NSMenuItem(title: "系统Dock控制：M1待接入", action: nil, keyEquivalent: "")
        pending.isEnabled = false; menu.addItem(pending)
        menu.addItem(.separator())
        add("退出探针", #selector(quit))
        setVolume(volume)
        if installStatusItem {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = icon
            item.button?.setAccessibilityLabel("打字钢琴")
            item.button?.toolTip = "打字钢琴 · C-001探针"
            item.menu = menu; statusItem = item
        }
    }
    private func add(_ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; menu.addItem(item)
    }
    public func setVolume(_ value: Double) {
        slider.doubleValue = min(1, max(0, value))
        percentage.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%"
    }
    public func update(soundEnabled: Bool, showLabels: Bool, showOverlay: Bool) {
        sound.state = soundEnabled ? .on : .off
        labels.state = showLabels ? .on : .off
        overlay.state = showOverlay ? .on : .off
    }
    @objc private func sliderChanged() { setVolume(slider.doubleValue); onVolume?(slider.doubleValue) }
    @objc private func openControl() { onOpen?() }
    @objc private func pauseAll() { onPause?() }
    @objc private func toggleSound() { onSound?() }
    @objc private func toggleLabels() { onLabels?() }
    @objc private func toggleOverlay() { onOverlay?() }
    @objc private func startGlobal() { onGlobal?() }
    @objc private func startLocal() { onLocal?() }
    @objc private func quit() { NSApp.terminate(nil) }
    deinit { if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) } }
}
