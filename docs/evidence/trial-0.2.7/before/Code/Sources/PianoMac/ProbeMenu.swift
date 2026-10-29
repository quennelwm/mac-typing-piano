import AppKit
import CoreText
import PianoAudio

/// Native daily menu, with bounded input/audio/system experiments in a separate submenu.
public final class ProbeMenu: NSObject, NSMenuDelegate {
    public static let statusItemWidth: CGFloat = 16
    public let menu = NSMenu()
    public let slider: NSSlider
    public let percentage = NSTextField(labelWithString: "50%")
    public let icon: NSImage
    public var onVolume: ((Double) -> Void)?
    public var onStartup: (() -> Void)?
    public var onDownload: (() -> Void)?
    public var onMuteAlerts: (() -> Void)?
    public var onSoundSettings: (() -> Void)?
    public var onWillOpen: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onSound: (() -> Void)?
    public var onLabels: (() -> Void)?
    public var onOverlay: (() -> Void)?
    public var onGlobal: (() -> Void)?
    public var onLocal: (() -> Void)?
    public var onDock: (() -> Void)?
    public var onDockSettings: (() -> Void)?
    public var onDockRecovery: (() -> Void)?
    public var onSource: ((String) -> Void)?
    public var onAbout: (() -> Void)?
    private var statusItem: NSStatusItem?
    public var actualStatusButtonWidth: CGFloat? { statusItem?.button?.bounds.width }
    private let session = NSMenuItem(title: "已暂停：尚未开始", action: nil, keyEquivalent: "")
    private let pause = NSMenuItem(title: "暂停全部", action: nil, keyEquivalent: "")
    private let sound = NSMenuItem(title: "声音", action: nil, keyEquivalent: "")
    private let alertMute = NSMenuItem(title: "静音系统提示音", action: nil, keyEquivalent: "")
    private let alertStatus = NSMenuItem(title: "提示音：默认保持系统现状", action: nil, keyEquivalent: "")
    private let labels = NSMenuItem(title: "显示按键标签", action: nil, keyEquivalent: "")
    private let overlay = NSMenuItem(title: "显示钢琴", action: nil, keyEquivalent: "")
    private let dock = NSMenuItem(title: "自动隐藏 Dock", action: nil, keyEquivalent: "")
    private var sourceItems: [NSMenuItem] = []
    private let mode = NSMenuItem(title: "Dock：模拟模式，不改系统", action: nil, keyEquivalent: "")
    public init(volume: Double, sources: [AudioSource] = [], installStatusItem: Bool = true) {
        slider = NSSlider(value: volume, minValue: 0, maxValue: 1, target: nil, action: nil)
        icon = NSImage(size: NSSize(width: Self.statusItemWidth, height: Self.statusItemWidth), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "♪", attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.black]))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            guard ink.width.isFinite, ink.height.isFinite, ink.width > 0, ink.height > 0 else { return false }
            // Keep the 18pt glyph; fit its actual ink with a one-point antialiasing margin.
            let content = rect.insetBy(dx: 1, dy: 1)
            let scale = min(1, min(content.width / ink.width, content.height / ink.height))
            ctx.saveGState(); ctx.translateBy(x: rect.midX, y: rect.midY); ctx.scaleBy(x: scale, y: scale)
            ctx.textMatrix = .identity; ctx.textPosition = CGPoint(x: -ink.midX, y: -ink.midY)
            CTLineDraw(line, ctx); ctx.restoreGState(); return true
        }
        icon.isTemplate = true
        super.init()
        menu.delegate = self; menu.autoenablesItems = false
        session.isEnabled = false; menu.addItem(session)
        add("打开启动窗口…", #selector(openStartup), to: menu)
        wire(pause, #selector(pauseAll), menu); menu.addItem(.separator())
        wire(sound, #selector(toggleSound), menu)
        let volumeItem = NSMenuItem(), volumeView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 42))
        let label = NSTextField(labelWithString: "音量")
        label.frame = NSRect(x: 12, y: 12, width: 34, height: 18)
        slider.frame = NSRect(x: 48, y: 10, width: 145, height: 22)
        slider.isContinuous = true; slider.target = self; slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel("打字钢琴音量，仅控制本App")
        percentage.frame = NSRect(x: 199, y: 12, width: 42, height: 18); percentage.alignment = .right
        volumeView.addSubview(label); volumeView.addSubview(slider); volumeView.addSubview(percentage)
        volumeItem.view = volumeView; menu.addItem(volumeItem)
        menu.addItem(.separator())
        wire(alertMute, #selector(muteAlerts), menu)
        alertMute.state = .mixed
        alertStatus.isEnabled = false; menu.addItem(alertStatus)
        add("系统声音设置…", #selector(openSoundSettings), to: menu)
        menu.addItem(.separator())
        wire(overlay, #selector(toggleOverlay), menu); wire(labels, #selector(toggleLabels), menu)
        menu.addItem(.separator()); wire(dock, #selector(toggleDock), menu)
        add("系统Dock设置…", #selector(openDockSettings), to: menu)
        let automaticWidth = NSMenuItem(title: "钢琴宽度：自动适应屏幕", action: nil, keyEquivalent: "")
        automaticWidth.isEnabled = false; menu.addItem(automaticWidth)
        menu.addItem(.separator()); add("帮助 / 关于", #selector(about), to: menu)
        add("下载新版…", #selector(download), to: menu)
        let test = submenu("测试", in: menu)
        add("打开测试控制台…", #selector(openControl), to: test)
        add("全局观察60秒…", #selector(startGlobal), to: test)
        add("本窗口测试60秒", #selector(startLocal), to: test)
        let banks = submenu("试听音源", in: test)
        for source in sources {
            let item = add(source.title, #selector(selectSource(_:)), to: banks)
            item.representedObject = source.id; sourceItems.append(item)
        }
        let note = NSMenuItem(title: "切换后需重开测试与声音；缺音不替补", action: nil, keyEquivalent: "")
        note.isEnabled = false; banks.addItem(note)
        test.addItem(.separator()); mode.isEnabled = false; test.addItem(mode)
        add("检查上次 Dock 恢复票据…", #selector(dockRecovery), to: test)
        menu.addItem(.separator()); add("退出打字钢琴", #selector(quit), to: menu).keyEquivalent = "q"
        setVolume(volume)
        if installStatusItem {
            let item = NSStatusBar.system.statusItem(withLength: Self.statusItemWidth)
            item.button?.image = icon; item.button?.setAccessibilityLabel("打字钢琴"); item.button?.toolTip = "打字钢琴"
            item.menu = menu; statusItem = item
        }
    }
    private func wire(_ item: NSMenuItem, _ action: Selector, _ parent: NSMenu) { item.action = action; item.target = self; parent.addItem(item) }
    @discardableResult private func add(_ title: String, _ action: Selector, to parent: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); wire(item, action, parent); return item
    }
    private func submenu(_ title: String, in parent: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""), submenu = NSMenu(title: title)
        submenu.autoenablesItems = false; item.submenu = submenu; parent.addItem(item); return submenu
    }
    public func menuWillOpen(_ menu: NSMenu) { onWillOpen?() }
    public func updateAlertVolume(muted: Bool?, detail: String) {
        alertMute.state = muted.map { $0 ? .on : .off } ?? .mixed
        alertStatus.title = "提示音：" + String(detail.prefix(30)) + (detail.count > 30 ? "…" : "")
        alertStatus.toolTip = detail; alertMute.toolTip = detail
    }
    public func setVolume(_ value: Double) { slider.doubleValue = min(1, max(0, value)); percentage.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%" }
    public func update(soundEnabled: Bool, showLabels: Bool, showOverlay: Bool, paused: Bool = false, dockDesired: Bool = true, dockKnown: Bool = true, systemDock: Bool = false, sourceID: String = "synthetic", sessionStatus: String? = nil) {
        session.title = sessionStatus ?? (paused ? "已暂停" : "运行中")
        sound.state = soundEnabled ? .on : .off; labels.state = showLabels ? .on : .off; overlay.state = showOverlay ? .on : .off
        pause.title = paused ? "开始打字钢琴" : "暂停打字钢琴"; dock.state = dockKnown ? (dockDesired ? .on : .off) : .mixed
        mode.title = systemDock ? "Dock：系统原生自动隐藏" : "Dock：模拟模式，不改系统"
        for item in sourceItems { item.state = item.representedObject as? String == sourceID ? .on : .off }
    }
    @objc private func sliderChanged() { setVolume(slider.doubleValue); onVolume?(slider.doubleValue) }
    @objc private func openStartup() { onStartup?() }
    @objc private func muteAlerts() { onMuteAlerts?() }
    @objc private func openSoundSettings() { onSoundSettings?() }
    @objc private func download() { onDownload?() }
    @objc private func openControl() { onOpen?() }
    @objc private func pauseAll() { onPause?() }
    @objc private func toggleSound() { onSound?() }
    @objc private func toggleLabels() { onLabels?() }
    @objc private func toggleOverlay() { onOverlay?() }
    @objc private func toggleDock() { onDock?() }
    @objc private func openDockSettings() { onDockSettings?() }
    @objc private func dockRecovery() { onDockRecovery?() }
    @objc private func selectSource(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { onSource?(id) } }
    @objc private func startGlobal() { onGlobal?() }
    @objc private func startLocal() { onLocal?() }
    @objc private func about() { onAbout?() }
    @objc private func quit() { NSApp.terminate(nil) }
    deinit { if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) } }
}
