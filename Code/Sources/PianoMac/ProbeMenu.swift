import AppKit
import CoreText
import PianoAudio
import PianoCore

/// Native daily menu, with bounded input/audio/system experiments in a separate submenu.
public final class ProbeMenu: NSObject, NSMenuDelegate, NSPopoverDelegate {
    public let controls = ControlPanel()
    private let popover = NSPopover()
    private var escapeMonitor: Any?
    private var explicitClose = false
    private var dismissedStatusEvent: Int?
    public var onFloating: (() -> Void)?
    public var onAlertVolume: ((Double) -> Void)?
    public var onLayer: ((String) -> Void)?
    private var layerItems: [NSMenuItem] = []
    public var isPopoverShown: Bool { popover.isShown }
    public static let statusItemWidth: CGFloat = 16
    public let menu = NSMenu()
    public let slider: NSSlider
    public let percentage = NSTextField(labelWithString: "50%")
    public let icon: NSImage
    public var onVolume: ((Double) -> Void)?
    public let heightSlider = NSSlider(value: 1, minValue: 0.5, maxValue: 1.8, target: nil, action: nil)
    public let heightPercentage = NSTextField(labelWithString: "100%")
    private var saveError: String?
    private let preferencesSaveStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    public var onHeight: ((Double) -> Void)?
    public let transparencySlider = NSSlider(value: 0.15, minValue: 0, maxValue: 1, target: nil, action: nil)
    public let transparencyPercentage = NSTextField(labelWithString: "15%")
    private let transparencyStatus = NSMenuItem(title: "已减少透明度", action: nil, keyEquivalent: "")
    public var onTransparency: ((Double) -> Void)?
    public var onInputPermission: (() -> Void)?
    public var onDidClose: (() -> Void)?
    public var onStartup: (() -> Void)?
    public var onDownload: (() -> Void)?
    public var onMuteAlerts: (() -> Void)?
    public var onSoundSettings: (() -> Void)?
    public var onWillOpen: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onSound: (() -> Void)?
    public var onCustomize: (() -> Void)?
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
    private let permission = NSMenuItem(title: "输入监控授权…", action: nil, keyEquivalent: "")
    private let customizeItem = NSMenuItem(title: "自定义键位…", action: nil, keyEquivalent: "")
    private let session = NSMenuItem(title: "已暂停", action: nil, keyEquivalent: "")
    private let pause = NSMenuItem(title: "暂停全部", action: nil, keyEquivalent: "")
    private let sound = NSMenuItem(title: "声音", action: nil, keyEquivalent: "")
    private let alertMute = NSMenuItem(title: "静音系统提示音", action: nil, keyEquivalent: "")
    private let alertStatus = NSMenuItem(title: "提示音：默认保持系统现状", action: nil, keyEquivalent: "")
    private let labels = NSMenuItem(title: "显示按键标签", action: nil, keyEquivalent: "")
    private let overlay = NSMenuItem(title: "显示钢琴", action: nil, keyEquivalent: "")
    private let keymapStatus = NSMenuItem(title: "当前：默认键位", action: nil, keyEquivalent: "")
    private let overlayStatusItem = NSMenuItem(title: "钢琴：已隐藏", action: nil, keyEquivalent: "")
    private let dock = NSMenuItem(title: "自动隐藏 Dock", action: nil, keyEquivalent: "")
    private var sourceItems: [NSMenuItem] = []
    private let mode = NSMenuItem(title: "Dock：模拟模式，不改系统", action: nil, keyEquivalent: "")
    public init(volume: Double, heightScale: Double = 1, sources: [AudioSource] = [], installStatusItem: Bool = true) {
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
        menu.delegate = self; menu.autoenablesItems = false; menu.minimumWidth = 180
        session.isEnabled = false; menu.addItem(session)
        wire(pause, #selector(pauseAll), menu); menu.addItem(.separator())
        wire(sound, #selector(toggleSound), menu)
        sliderRow("音量", slider: slider, value: percentage, action: #selector(sliderChanged), accessibility: "打字钢琴音量，仅控制本App")
        menu.addItem(.separator())
        wire(overlay, #selector(toggleOverlay), menu); wire(labels, #selector(toggleLabels), menu)
        sliderRow("钢琴高度", slider: heightSlider, value: heightPercentage, action: #selector(heightChanged), accessibility: "钢琴高度，50%至180%，100%为112点")
        sliderRow("琴键透明度", slider: transparencySlider, value: transparencyPercentage, action: #selector(transparencyChanged), accessibility: "琴键透明度，0%不透明，100%材质透明；文字和音符保留")
        transparencyStatus.isEnabled = false; transparencyStatus.isHidden = true
        transparencyStatus.toolTip = "系统减少透明度正在生效；保存的透明度保留，系统选项关闭后恢复。"
        menu.addItem(transparencyStatus)
        preferencesSaveStatus.isEnabled = false; preferencesSaveStatus.isHidden = true; menu.addItem(preferencesSaveStatus)
        wire(customizeItem, #selector(customize), menu)
        keymapStatus.isEnabled = false; keymapStatus.isHidden = true; menu.addItem(keymapStatus)
        menu.addItem(.separator()); wire(permission, #selector(inputPermission), menu)
        let system = submenu("系统选项", in: menu)
        wire(alertMute, #selector(muteAlerts), system); alertMute.state = .mixed
        alertStatus.isEnabled = false; system.addItem(alertStatus)
        add("系统声音设置…", #selector(openSoundSettings), to: system)
        system.addItem(.separator()); wire(dock, #selector(toggleDock), system)
        add("系统Dock设置…", #selector(openDockSettings), to: system)
        mode.isEnabled = false; system.addItem(mode)
        add("检查上次 Dock 恢复票据…", #selector(dockRecovery), to: system)
        let help = submenu("帮助与测试", in: menu)
        add("打开启动窗口…", #selector(openStartup), to: help)
        add("帮助 / 关于", #selector(about), to: help); add("下载新版…", #selector(download), to: help)
        let automaticWidth = NSMenuItem(title: "钢琴宽度：自动适应屏幕", action: nil, keyEquivalent: "")
        automaticWidth.isEnabled = false; help.addItem(automaticWidth)
        overlayStatusItem.isEnabled = false; help.addItem(overlayStatusItem)
        help.addItem(.separator())
        add("打开测试控制台…", #selector(openControl), to: help)
        add("全局观察60秒…", #selector(startGlobal), to: help)
        add("本窗口测试60秒", #selector(startLocal), to: help)
        let banks = submenu("试听音源", in: help)
        for source in sources {
            let item = add(source.title, #selector(selectSource(_:)), to: banks)
            item.representedObject = source.id; sourceItems.append(item)
        }
        let note = NSMenuItem(title: "切换后需重开测试与声音；缺音不替补", action: nil, keyEquivalent: "")
        note.isEnabled = false; banks.addItem(note)
        menu.addItem(.separator()); add("退出打字钢琴", #selector(quit), to: menu).keyEquivalent = "q"
        setVolume(volume)
        setHeight(heightScale)
        _ = controls.view
        controls.onRun = { [weak self] in self?.onPause?() }
        controls.onFloating = { [weak self] in self?.onFloating?() }
        controls.onSound = { [weak self] in self?.onSound?() }
        controls.onHeight = { [weak self] in self?.onHeight?($0) }
        controls.onTransparency = { [weak self] in self?.onTransparency?($0) }
        controls.onVolume = { [weak self] in self?.onVolume?($0) }
        controls.onAlerts = { [weak self] in self?.onAlertVolume?($0) }
        controls.onCustomize = { [weak self] in self?.closePopover(); self?.onCustomize?() }
        controls.onPermission = { [weak self] in self?.closePopover(); self?.onInputPermission?() }
        controls.onQuit = { NSApp.terminate(nil) }
        let options = NSMenu(title: "系统设置"); options.autoenablesItems = false
        for parent in [system, help] {
            for item in parent.items { if let copy = item.copy() as? NSMenuItem { options.addItem(copy) } }
            options.addItem(.separator())
        }
        // The legacy tree remains a diagnostic adapter; the live host is the popover.
        wire(NSMenuItem(title: "显示按键标签", action: nil, keyEquivalent: ""), #selector(toggleLabels), options)
        let layers = submenu("琴键层级", in: options)
        for (title, value) in [("始终置顶", "top"), ("始终在底层", "bottom")] {
            let item = add(title, #selector(selectLayer(_:)), to: layers); item.representedObject = value; layerItems.append(item)
        }
        controls.systemMenu = options
        popover.behavior = .transient; popover.animates = false; popover.contentViewController = controls; popover.delegate = self
        setVolume(volume); setHeight(heightScale)
        if installStatusItem {
            let item = NSStatusBar.system.statusItem(withLength: Self.statusItemWidth)
            item.button?.image = icon; item.button?.setAccessibilityLabel("打字钢琴"); item.button?.toolTip = "打字钢琴"
            item.button?.sendAction(on: .leftMouseDown)
            item.button?.target = self; item.button?.action = #selector(togglePopover); statusItem = item
        }
    }
    @objc private func togglePopover() {
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, dismissedStatusEvent == event.eventNumber { dismissedStatusEvent = nil; return }
        dismissedStatusEvent = nil
        if popover.isShown { explicitClose = true; closePopover(); explicitClose = false; return }
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.popover.isShown == true, event.keyCode == 53 else { return event }
            self?.closePopover(); return nil
        }
        onWillOpen?()
    }
    public func closePopover() { explicitClose = true; popover.performClose(nil); explicitClose = false }
    public func popoverWillClose(_ notification: Notification) {
        guard !explicitClose, let event = NSApp.currentEvent, event.type == .leftMouseDown, let button = statusItem?.button, let window = button.window else { return }
        let point = button.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        if button.bounds.contains(point) { dismissedStatusEvent = event.eventNumber }
    }
    public func popoverDidClose(_ notification: Notification) {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
        onDidClose?()
    }
    @objc private func selectLayer(_ sender: NSMenuItem) { onLayer?(sender.representedObject as? String ?? "top") }
    public func setPresentation(floating: Bool, layer: String) {
        controls.floating.state = floating ? .on : .off
        for item in layerItems { item.state = item.representedObject as? String == layer ? .on : .off }
    }
    public func setAlertLevel(_ value: Int?, detail: String) {
        controls.alerts.isEnabled = value != nil
        controls.alerts.doubleValue = Double(value ?? 0) / 100
        controls.alerts.toolTip = detail
    }
    private func sliderRow(_ title: String, slider: NSSlider, value: NSTextField, action: Selector, accessibility: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 166, height: 50))
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13); value.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 10, y: 29, width: 96, height: 18)
        value.frame = NSRect(x: 112, y: 29, width: 44, height: 18); value.alignment = .right
        slider.frame = NSRect(x: 10, y: 7, width: 146, height: 20)
        slider.isContinuous = true; slider.target = self; slider.action = action
        slider.setAccessibilityLabel(accessibility)
        view.addSubview(label); view.addSubview(value); view.addSubview(slider)
        item.view = view; menu.addItem(item)
    }
    public func updatePermission(granted: Bool) {
        permission.state = granted ? .on : .off
        controls.permissionButton?.state = granted ? .on : .off
        controls.message.stringValue = saveError == nil ? (granted ? "输入监控已授权" : "需要输入监控授权") : "设置未保存"
        controls.message.toolTip = saveError
        permission.toolTip = granted ? "输入监控已授权；点击打开系统设置，不中断打字钢琴。" : "尚未获得输入监控授权；点击办理授权并开始；请在系统设置亲自允许。"
    }
    @objc private func inputPermission() { onInputPermission?() }
    private func wire(_ item: NSMenuItem, _ action: Selector, _ parent: NSMenu) { item.action = action; item.target = self; parent.addItem(item) }
    @discardableResult private func add(_ title: String, _ action: Selector, to parent: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); wire(item, action, parent); return item
    }
    private func submenu(_ title: String, in parent: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""), submenu = NSMenu(title: title)
        submenu.autoenablesItems = false; item.submenu = submenu; parent.addItem(item); return submenu
    }
    public func updateKeymap(custom: Bool, warning: String?) {
        keymapStatus.title = "键位读取失败"; keymapStatus.isHidden = warning == nil
        keymapStatus.toolTip = warning
        customizeItem.toolTip = warning ?? (custom ? "当前：自定义键位" : "当前：默认键位")
    }
    @objc private func customize() { onCustomize?() }
    public func menuWillOpen(_ menu: NSMenu) { if menu === self.menu { onWillOpen?() } }
    public func menuDidClose(_ menu: NSMenu) { if menu === self.menu { onDidClose?() } }
    public func setHeight(_ value: Double) {
        controls.height.doubleValue = ControlPanel.normalizedHeight(value)
        heightSlider.doubleValue = PianoHeight.normalized(value)
        heightPercentage.stringValue = "\(Int((heightSlider.doubleValue * 100).rounded()))%"
    }
    public func setTransparency(_ value: Double, reduced: Bool) {
        controls.transparency.doubleValue = value; controls.transparency.isEnabled = !reduced
        transparencySlider.doubleValue = value.isFinite ? min(1, max(0, value)) : 0.15
        transparencyPercentage.stringValue = "\(Int((transparencySlider.doubleValue * 100).rounded()))%"
        transparencySlider.isEnabled = !reduced; transparencyStatus.isHidden = !reduced
    }
    @objc private func transparencyChanged() {
        guard transparencySlider.isEnabled else { return }
        setTransparency(transparencySlider.doubleValue, reduced: false)
        onTransparency?(transparencySlider.doubleValue)
    }
    public func setPreferencesSaveError(_ error: String?) {
        saveError = error
        if let error { controls.message.stringValue = "设置未保存"; controls.message.toolTip = error }
        preferencesSaveStatus.isHidden = error == nil
        preferencesSaveStatus.title = error == nil ? "" : "设置未保存"
        preferencesSaveStatus.toolTip = error.map { "关闭菜单或退出时重试。" + $0 }
    }
    @objc private func heightChanged() { setHeight(heightSlider.doubleValue); onHeight?(heightSlider.doubleValue) }
    public func updateAlertVolume(muted: Bool?, detail: String) {
        alertMute.state = muted.map { $0 ? .on : .off } ?? .mixed
        alertStatus.title = "提示音：" + String(detail.prefix(30)) + (detail.count > 30 ? "…" : "")
        alertStatus.toolTip = detail; alertMute.toolTip = detail
    }
    public func setVolume(_ value: Double) { controls.volume.doubleValue = value; slider.doubleValue = min(1, max(0, value)); percentage.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%" }
    public func update(soundEnabled: Bool, showLabels: Bool, showOverlay: Bool, overlayVisible: Bool = true, overlayStatus: String? = nil, paused: Bool = false, dockDesired: Bool = true, dockKnown: Bool = true, systemDock: Bool = false, sourceID: String = "synthetic", sessionStatus: String? = nil) {
        controls.running.state = paused ? .off : .on
        controls.sound.state = soundEnabled ? .on : .off; controls.soundCheck.state = controls.sound.state
        let detail = sessionStatus ?? (paused ? "已暂停" : "运行中")
        session.toolTip = detail
        if detail.contains("安全输入") { session.title = "安全输入已暂停" }
        else if detail.contains("授权") || detail.contains("权限") { session.title = "需要输入监控" }
        else if detail.contains("失败") { session.title = "启动失败" }
        else { session.title = paused ? "已暂停" : "运行中" }
        sound.state = soundEnabled ? .on : .off; labels.state = showLabels ? .on : .off; overlay.state = showOverlay ? (overlayVisible ? .on : .mixed) : .off
        overlayStatusItem.title = "钢琴：" + (overlayStatus ?? (showOverlay ? "已显示" : "已隐藏"))
        pause.title = paused ? "开始打字钢琴" : "暂停打字钢琴"; dock.state = dockKnown ? (dockDesired ? .on : .off) : .mixed
        mode.title = systemDock ? "Dock：系统原生自动隐藏" : "Dock：模拟模式，不改系统"
        for item in sourceItems { item.state = item.representedObject as? String == sourceID ? .on : .off }
        func all(_ menu: NSMenu) -> [NSMenuItem] { menu.items + menu.items.compactMap(\.submenu).flatMap { all($0) } }
        if let options = controls.systemMenu {
            let masters = all(menu)
            for copy in all(options) {
                if let original = masters.first(where: { $0.title == copy.title && !$0.title.isEmpty }) { copy.state = original.state; copy.toolTip = original.toolTip }
            }
        }
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
    deinit { if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }; if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) } }
}
