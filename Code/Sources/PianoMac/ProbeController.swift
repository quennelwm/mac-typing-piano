import AppKit
import AVFoundation
import PianoCore
import PianoAudio

/// A finite M0 test harness, not the M1 menu-bar product.
public final class ProbeController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let mapping: KeyMapping
    private let bankURL: URL
    private let preferencesURL: URL
    private var preferences: AppPreferences
    private var statusMenu: ProbeMenu?
    private let input: InputMonitor
    private var reducer = KeyStateReducer()
    private var coordinator: NoteCoordinator
    private let audio = SamplerAudio()
    private var audioReady = false
    private var pending: [UUID: DispatchWorkItem] = [:]
    private var notifications: [NSObjectProtocol] = []
    private var window: NSWindow!
    private var preview: PianoView!
    private var panel: ProbePanel!
    private var overlayView: PianoView!
    private var status = NSTextField(wrappingLabelWithString: "默认停止；无输入监听、无声音。先选择一个60秒探针。")
    private var soundButton: NSButton!
    private var labels = true
    private var showOverlay = false
    private var avoidance = DockAvoidance()
    private var dockTimer: Timer?
    private var targetScreen: NSScreen?
    private var receivedCount = 0

    public init(mapping: KeyMapping, bankURL: URL, preferencesURL: URL) throws {
        self.mapping = mapping; self.bankURL = bankURL; self.preferencesURL = preferencesURL
        preferences = try AppPreferences.load(from: preferencesURL)
        coordinator = NoteCoordinator(mapping: mapping)
        input = try InputMonitor(mapping: mapping)
        super.init()
        _ = coordinator.setSoundEnabled(false)
        audio.setGain(preferences.outputGain)
        labels = preferences.showKeyLabels
        input.onEvent = { [weak self] in self?.receive($0) }
        input.onStop = { [weak self] in self?.pause($0) }
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        installSafetyHooks()
        let menu = ProbeMenu(volume: preferences.volume)
        menu.onOpen = { [weak self] in self?.showControlWindow() }
        menu.onPause = { [weak self] in self?.stopAll() }
        menu.onSound = { [weak self] in self?.toggleSound() }
        menu.onLabels = { [weak self] in self?.toggleLabels() }
        menu.onOverlay = { [weak self] in self?.toggleOverlay() }
        menu.onGlobal = { [weak self] in self?.startGlobal() }
        menu.onLocal = { [weak self] in self?.showControlWindow(); self?.startLocal() }
        menu.onVolume = { [weak self] in self?.changeVolume($0) }
        statusMenu = menu
        refresh()
    }
    private func showControlWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    private func changeVolume(_ value: Double) {
        preferences.setVolume(value)
        audio.setGain(preferences.outputGain)
        savePreferences()
    }
    private func savePreferences() {
        do { try preferences.save(to: preferencesURL) }
        catch { status.stringValue = "偏好保存失败：\(error.localizedDescription)"; showControlWindow() }
    }
    private func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 300),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Typing Piano · C-001 三探针（合成占位）"
        window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "M0测试入口 · 关闭窗口停止探针，♪菜单退出 · 不修改系统Dock或权限")
        let permission = NSTextField(labelWithString: "当前进程输入监控预检：\(InputMonitor.hasExistingPermission ? "已授权（捕获待实按）" : "未授权")；Fn/Caps/双侧均待实按")
        let first = NSStackView(views: [button("本窗口测试60秒", #selector(startLocal)), button("全局观察60秒", #selector(startGlobal)), button("暂停全部", #selector(stopAll))])
        first.orientation = .horizontal; first.spacing = 8
        soundButton = button("启用占位声音", #selector(toggleSound))
        let second = NSStackView(views: [soundButton, button("显示/隐藏矩形浮层", #selector(toggleOverlay)), button("解除保守隐藏", #selector(acknowledge)), button("显示/隐藏标签", #selector(toggleLabels))])
        second.orientation = .horizontal; second.spacing = 8
        preview = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 980, height: 56))
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.heightAnchor.constraint(equalToConstant: 56).isActive = true
        preview.widthAnchor.constraint(equalToConstant: 980).isActive = true
        preview.onPress = { [weak self] key in
            guard let self, self.input.mode != .stopped else { return }
            let phase: KeyPhase = self.mapping.key(key)?.eventSemantics == "toggleCandidate" ? .pulse : .down
            self.receive(.init(key, phase, time: ProcessInfo.processInfo.systemUptime), source: .preview)
        }
        preview.onRelease = { [weak self] key in self?.receive(.init(key, .up, time: ProcessInfo.processInfo.systemUptime), source: .preview) }
        let detail = NSTextField(wrappingLabelWithString: "先开启测试，再可用键盘或点击此处琴键。声音单独启用；长按不重复击发。浮层鼠标穿透。拖拽/Dock前台后保守隐藏，需手动解除。系统Dock控制和700ms小音符仅模型验证，待M1接入。")
        let stack = NSStackView(views: [title, permission, first, second, preview, status, detail])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 18), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20)])
        overlayView = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: 56))
        panel = ProbePanel(content: overlayView)
        preview.showLabels = labels; overlayView.showLabels = labels
        positionPanel()
    }
    private func positionPanel() {
        targetScreen = NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(id.uint32Value) != 0
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = targetScreen else { showOverlay = false; panel.orderOut(nil); return }
        let available = screen.visibleFrame
        let width = min(1000, max(100, available.width - 48))
        panel.setFrame(NSRect(x: available.midX - width / 2, y: available.minY + 8, width: width, height: 56), display: true)
    }
    @objc private func startLocal() { start(global: false) }
    @objc private func startGlobal() { start(global: true) }
    private func start(global: Bool) {
        pause("准备测试")
        coordinator.resume()
        do {
            try input.start(global: global)
            receivedCount = 0
            status.stringValue = global ? "只观察监听器已建立；60秒内自动停止，实际捕获待实按。" : "本窗口60秒测试已开启。事件原样传递；不保存文本或逐键历史。"
        } catch { pause(error.localizedDescription); showControlWindow() }
    }
    private func receive(_ event: NormalizedKeyEvent, source: KeyInputSource = .keyboard) {
        guard input.mode != .stopped, !InputMonitor.secureInput, let normalized = reducer.consume(event, source: source) else { return }
        receivedCount += 1
        apply(coordinator.consume(normalized))
        if normalized.phase == .pulse, let press = coordinator.active[normalized.physicalKeyID] {
            let expected = coordinator.generation
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.coordinator.generation == expected else { return }
                self.apply(self.coordinator.release(key: normalized.physicalKeyID, pressID: press.id))
                self.pending.removeValue(forKey: press.id); self.refresh()
            }
            pending[press.id] = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: item)
        }
        status.stringValue = "仅内存聚合：有效事件\(receivedCount)，当前按住\(coordinator.active.count)；不保存键序列。"
        refresh()
    }
    private func apply(_ events: [NoteEvent]) {
        for event in events {
            switch event.phase {
            case .down: if audioReady { audio.noteOn(midi: UInt8(event.midiNote), velocity: UInt8(event.velocity)) }
            case .release: if audioReady { audio.noteOff(midi: UInt8(event.midiNote)) }
            case .panic: audio.panic()
            }
        }
    }
    private func refresh() {
        statusMenu?.update(soundEnabled: coordinator.soundEnabled, showLabels: labels, showOverlay: showOverlay)
        let keys = Set(coordinator.active.values.map { $0.key.midiNote })
        preview?.activeMIDI = keys; overlayView?.activeMIDI = keys
        if showOverlay && coordinator.overlayVisible { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
    }
    @objc private func stopAll() { pause("已暂停：监听、声音、尾音、延迟释放和浮层已清理。") }
    private func pause(_ reason: String) {
        input.stop(); reducer.reset()
        for item in pending.values { item.cancel() }; pending.removeAll()
        apply(coordinator.panic(paused: true))
        showOverlay = false; dockTimer?.invalidate(); dockTimer = nil
        status.stringValue = reason; refresh()
    }
    @objc private func toggleSound() {
        if coordinator.soundEnabled {
            apply(coordinator.setSoundEnabled(false)); audio.shutdown(); audioReady = false
            soundButton.title = "启用占位声音"
        } else {
            do {
                try audio.prepare(bankURL: bankURL, offline: false)
                audioReady = true; _ = coordinator.setSoundEnabled(true)
                soundButton.title = "关闭声音并清尾音"
            } catch { status.stringValue = "音频准备失败：\(error.localizedDescription)"; showControlWindow() }
        }
        refresh()
    }
    @objc private func toggleLabels() {
        labels.toggle(); preview.showLabels = labels; overlayView.showLabels = labels
        preferences.showKeyLabels = labels; savePreferences(); refresh()
    }
    @objc private func toggleOverlay() {
        if !showOverlay {
            guard !coordinator.paused, !InputMonitor.secureInput else {
                status.stringValue = "当前已暂停或安全输入阻断；显示开关不会解除暂停。请在安全环境重新开启测试。"
                showControlWindow()
                return
            }
        }
        showOverlay.toggle()
        if showOverlay {
            avoidance = DockAvoidance(); positionPanel()
            dockTimer?.invalidate()
            dockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.dockTick() }
            if let dockTimer { RunLoop.main.add(dockTimer, forMode: .common) }
        } else { dockTimer?.invalidate(); dockTimer = nil }
        refresh()
    }
    @objc private func acknowledge() { avoidance.acknowledge() }
    private func dockTick() {
        if InputMonitor.secureInput { pause("安全输入阻断：浮层已隐藏"); return }
        guard let screen = targetScreen else { return }
        let mouse = NSEvent.mouseLocation
        let within = screen.frame.contains(mouse)
        let bottomDistance = mouse.y - screen.frame.minY
        let sideDistance = min(mouse.x - screen.frame.minX, screen.frame.maxX - mouse.x)
        let hidden = avoidance.update(nearEdge: within && (bottomDistance < 120 || sideDistance < 80),
            recoverySafe: !within || (bottomDistance > 170 && sideDistance > 130),
            mouseDown: NSEvent.pressedMouseButtons != 0,
            dockFrontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.dock",
            time: ProcessInfo.processInfo.systemUptime)
        coordinator.dockHidden = hidden; refresh()
    }
    private func installSafetyHooks() {
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.input.mode == .local else { return }
            self.pause("本窗口测试失焦，已清理按键和声音；全局测试不受此规则影响")
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            notifications.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.pause("系统会话/睡眠阻断：已安全暂停") })
        }
        notifications.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.showOverlay = false; self?.dockTimer?.invalidate(); self?.dockTimer = nil; self?.refresh()
        })
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.showOverlay = false; self?.dockTimer?.invalidate(); self?.dockTimer = nil; self?.positionPanel(); self?.refresh()
        })
        notifications.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.audioReady else { return }
            self.pause("音频配置变化：已停用，需手动重新启用声音")
            self.audio.shutdown(); self.audioReady = false; _ = self.coordinator.setSoundEnabled(false)
            self.soundButton.title = "启用占位声音"
            self.refresh()
        })
    }
    public func windowWillClose(_ notification: Notification) { pause("控制台已关闭；探针停止，可从♪菜单重开或退出") }
    public func applicationWillTerminate(_ notification: Notification) { pause("退出"); audio.shutdown() }
}
