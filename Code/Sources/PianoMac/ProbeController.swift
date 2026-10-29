import AppKit
import AVFoundation
import PianoCore
import PianoAudio

/// Native integrated candidate with explicit bounded test entry points.
public final class ProbeController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mapping: KeyMapping
    private let defaultMapping: KeyMapping
    private let customStore: CustomKeymapStore
    private var customConfiguration: CustomKeymap
    private var keymapWarning: String?
    private var keymapEditor: KeymapEditor?
    private var ignoredUntilRelease = Set<String>()
    private let sources: [AudioSource]
    private let preferencesURL: URL
    private var preferences: AppPreferences
    private var statusMenu: ProbeMenu?
    private let startupFlow: StartupFlow
    private let startupWindowPresenter: (() -> Void)?
    private var startupPrimary: NSButton?
    private var startupCancel: NSButton?
    private var authorizationRequestInFlight = false
    private var authorizationReturnGate = AuthorizationReturnGate()
    private let alertVolume: AlertVolumeAdapter
    private var skipAlertRestoreOnExit = false
    private var sessionStatus = "已暂停：尚未开始"
    private let input: InputMonitoring
    private let installStatusItem: Bool
    private var reducer = KeyStateReducer()
    private var coordinator: NoteCoordinator
    private let audio: AuditionSession
    private var audioReady: Bool { audio.enabled }
    private var dock = DockAdapter(storage: SimulatedDockStorage(), tickets: MemoryDockTicketStore())
    private var systemDock = false
    private var lastGlobal = false
    private var sessionDuration: InputSessionDuration = .test60Seconds
    private var startupWindow: NSWindow!
    private let startupMessage = NSTextField(wrappingLabelWithString: "点击开始后，在其他 App 打字即可听到钢琴并看到按键反馈。可随时从 ♪ 菜单暂停或退出。")
    private var pending: [UUID: DispatchWorkItem] = [:]
    private var notifications: [NSObjectProtocol] = []
    private var window: NSWindow!
    private var preview: PianoView!
    private var panel: ProbePanel!
    private var overlayView: PianoView!
    private var status = NSTextField(wrappingLabelWithString: "默认停止；点击“开始打字钢琴”后持续运行，可随时暂停。")
    private var soundButton: NSButton!
    private var labels = true
    private var showOverlay = false
    private let permissionCheck: () -> Bool
    private let secureInputCheck: () -> Bool
    private let dockVisibilityCheck: ((CGRect, TimeInterval) -> DockVisibility)?
    private var sessionBlocks = Set<String>()
    private var sessionBlocked: Bool { !sessionBlocks.isEmpty }
    private var overlayBlocked: Bool { sessionBlocked || secureInputCheck() }
    private var overlayStatus: String {
        if !showOverlay { return "已隐藏" }
        if sessionBlocked { return "锁屏/睡眠期间隐藏" }
        if secureInputCheck() { return "安全输入阻断，结束后仅恢复静态显示" }
        if targetScreen == nil { return "等待可用屏幕" }
        if dockFade.dockHidden { return lastDockVisibility == .unknown ? "Dock状态未知，短暂等待" : "等待Dock隐藏" }
        return lastDockVisibility == .unknown ? "已显示（Dock状态未知）" : "已显示"
    }
    private var dockFade = DockFade()
    private let dockObserver = DockWindowVisibilityObserver()
    private var fadeTimer: Timer?
    private var fadeTimerGeneration: UInt64?
    private var overlaySceneVisible = false
    private var lastDockVisibility = DockVisibility.unknown
    private var dockTimer: Timer?
    private var targetScreen: NSScreen?
    private var receivedCount = 0
    private var diagnosticsTimer: Timer?
    private let diagnosticsLabel = NSTextField(wrappingLabelWithString: "运行诊断：尚未开始。")

    public init(mapping: KeyMapping, sources: [AudioSource], preferencesURL: URL, input: InputMonitoring? = nil, audioEngine: AuditionEngine = SamplerAudio(), installStatusItem: Bool = true, dockAdapter: DockAdapter? = nil, startupWindowPresenter: (() -> Void)? = nil, alertVolume: AlertVolumeAdapter? = nil, secureInputCheck: @escaping () -> Bool = { InputMonitor.secureInput }, permissionCheck: @escaping () -> Bool = { InputMonitor.hasExistingPermission }, dockVisibilityCheck: ((CGRect, TimeInterval) -> DockVisibility)? = nil) throws {
        guard let first = sources.first else { throw ProbeError.invalid("没有可用试听音源") }
        self.permissionCheck = permissionCheck
        self.secureInputCheck = secureInputCheck; self.dockVisibilityCheck = dockVisibilityCheck
        self.defaultMapping = mapping
        customStore = CustomKeymapStore(url: preferencesURL.deletingLastPathComponent().appendingPathComponent("custom-keymap.json"), defaultMapping: mapping)
        let custom = customStore.load()
        customConfiguration = custom.configuration; keymapWarning = custom.warning
        let effectiveMapping = try custom.configuration.mapping(from: mapping)
        self.mapping = effectiveMapping; self.sources = sources; self.preferencesURL = preferencesURL
        audio = AuditionSession(engine: audioEngine, source: first)
        self.installStatusItem = installStatusItem
        if let dockAdapter { self.dock = dockAdapter; self.systemDock = true }
        preferences = try AppPreferences.load(from: preferencesURL)
        startupFlow = try StartupFlow(intentURL: preferencesURL.deletingLastPathComponent().appendingPathComponent("authorization-start.json"))
        self.startupWindowPresenter = startupWindowPresenter
        self.alertVolume = alertVolume ?? AlertVolumeAdapter(storage: StandardAdditionsAlertVolumeStorage())
        coordinator = NoteCoordinator(mapping: effectiveMapping)
        self.input = try input ?? InputMonitor(mapping: effectiveMapping)
        super.init()
        _ = coordinator.setSoundEnabled(false)
        _ = coordinator.panic(paused: true)
        audio.setVolume(preferences.volume)
        labels = preferences.showKeyLabels
        self.input.onEvent = { [weak self] in self?.receive($0) }
        self.input.onStop = { [weak self] in self?.pause($0) }
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        buildStartupWindow()
        installSafetyHooks()
        let menu = ProbeMenu(volume: preferences.volume, sources: sources, installStatusItem: installStatusItem)
        menu.onStartup = { [weak self] in self?.showStartupWindow() }
        menu.onDownload = { [weak self] in self?.downloadNewVersion() }
        menu.onMuteAlerts = { [weak self] in self?.toggleAlertMute() }
        menu.onSoundSettings = { [weak self] in self?.openSoundSettings() }
        menu.onWillOpen = { [weak self] in self?.alertVolume.refresh(); self?.refreshAlertMenu() }
        menu.onOpen = { [weak self] in self?.showControlWindow() }
        menu.onPause = { [weak self] in self?.togglePause() }
        menu.onSound = { [weak self] in self?.toggleSound() }
        menu.onCustomize = { [weak self] in self?.showKeymapEditor() }
        menu.onLabels = { [weak self] in self?.toggleLabels() }
        menu.onOverlay = { [weak self] in self?.toggleOverlay() }
        menu.onGlobal = { [weak self] in self?.startGlobal() }
        menu.onLocal = { [weak self] in self?.showControlWindow(); self?.startLocal() }
        menu.onVolume = { [weak self] in self?.changeVolume($0) }
        menu.onSource = { [weak self] in self?.selectSource($0) }
        menu.onDock = { [weak self] in self?.toggleDock() }
        menu.onDockSettings = { [weak self] in self?.openDockSettings() }
        menu.onDockRecovery = { [weak self] in self?.recoverDock() }
        menu.onAbout = { [weak self] in self?.showAbout() }
        statusMenu = menu
        dockResult(dock.request(true, confirmedDisable: true)) // GUI injects native storage; tests retain simulation.
        refresh()
        if installStatusItem {
            showStartupWindow()
            if NSApp.isActive { handleStartup(.becameActive) }
        }
    }
    private func buildStartupWindow() {
        startupWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 490), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.7"
        startupWindow.delegate = self
        startupWindow.title = "打字钢琴试用 · \(version)"; startupWindow.center(); startupWindow.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "让打字伴随琴声")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let start = button("开始打字钢琴", #selector(startTrial))
        start.bezelStyle = .rounded; startupPrimary = start
        let hint = NSTextField(wrappingLabelWithString: "首次默认停止。点击授权并开始后，请在系统设置亲自允许；返回时继续本次开始操作。若系统要求退出，请重新打开同一路径App并点击主按钮继续。仅观察键盘，不保存输入。")
        hint.textColor = .secondaryLabelColor; hint.font = .systemFont(ofSize: 11)
        let local = button("本窗口试弹（无需权限）", #selector(startLocalTrial))
        local.bezelStyle = .rounded
        let cancel = button("取消本次开始", #selector(cancelStartup)); startupCancel = cancel
        let stack = NSStackView(views: [title, startupMessage, start, cancel, local, button("退出App", #selector(quitApp)), hint])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        startupWindow.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: startupWindow.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: startupWindow.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: startupWindow.contentView!.topAnchor, constant: 20)])
    }
    private func showStartupWindow() {
        if let startupWindowPresenter { startupWindowPresenter(); return }
        updateStartupControls()
        if startupFlow.pendingAuthorization {
            startupMessage.stringValue = "存在尚未完成的授权开始请求。本次请求返回App可续接；若已退出重开，请点击主按钮继续，或取消本次开始。"
        } else { startupMessage.stringValue = sessionStatus }
        if let keymapWarning { startupMessage.stringValue += "\n" + keymapWarning }
        startupWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStartupWindow()
        return false
    }
    func handleDuplicateLaunch() { showStartupWindow() }
    private func updateStartupControls() {
        startupPrimary?.title = permissionCheck() ? "开始打字钢琴" : "授权并开始"
        startupPrimary?.isEnabled = input.mode != .global && !authorizationRequestInFlight
        startupCancel?.isHidden = !startupFlow.pendingAuthorization
    }
    private func downloadNewVersion() {
        let url = URL(string: "https://github.com/quennelwm/mac-typing-piano/releases")!
        if !NSWorkspace.shared.open(url) {
            showStartupWindow()
            startupMessage.stringValue = "无法打开浏览器，请手动访问 github.com/quennelwm/mac-typing-piano/releases 下载新版。"
        }
    }
    func showControlWindow(activate: Bool = true) {
        if activate { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        else { window.orderFront(nil) }
        refresh()
    }
    private func changeVolume(_ value: Double) {
        preferences.setVolume(value)
        audio.setVolume(preferences.volume)
        savePreferences()
    }
    private func savePreferences() {
        do { try preferences.save(to: preferencesURL) }
        catch { status.stringValue = "偏好保存失败：\(error.localizedDescription)"; showControlWindow() }
    }
    private func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "打字钢琴试用 · 测试控制台"
        window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "本窗口试弹：无需输入监控权限，失焦或关闭窗口即停止；全局打字可后台持续运行。")
        let permission = NSTextField(labelWithString: "当前进程输入监控预检：\(permissionCheck() ? "已授权（捕获待实按）" : "未授权")；Fn/Caps/双侧均待实按")
        let first = NSStackView(views: [button("本窗口试弹（无需权限）", #selector(startLocalTrial)), button("本窗口测试60秒", #selector(startLocal)), button("全局观察60秒", #selector(startGlobal)), button("暂停全部", #selector(stopAll)), button("退出", #selector(quitApp))])
        first.orientation = .horizontal; first.spacing = 8
        soundButton = button("启用所选声音", #selector(toggleSound))
        let second = NSStackView(views: [soundButton, button("显示/隐藏钢琴", #selector(toggleOverlay)), button("重新检查Dock状态", #selector(acknowledge)), button("显示/隐藏标签", #selector(toggleLabels))])
        second.orientation = .horizontal; second.spacing = 8
        preview = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: AdaptiveOverlay.canvasHeight))
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.heightAnchor.constraint(equalToConstant: AdaptiveOverlay.canvasHeight).isActive = true
        preview.widthAnchor.constraint(equalToConstant: 1000).isActive = true
        preview.onPress = { [weak self] key in
            guard let self, self.input.mode != .stopped else { return }
            let phase: KeyPhase = self.mapping.key(key)?.eventSemantics == "toggleCandidate" ? .pulse : .down
            self.receive(.init(key, phase, time: ProcessInfo.processInfo.systemUptime), source: .preview)
        }
        preview.onRelease = { [weak self] key in self?.receive(.init(key, .up, time: ProcessInfo.processInfo.systemUptime), source: .preview) }
        let detail = NSTextField(wrappingLabelWithString: "本窗口试弹会同时开启所选声音，可打字或点击琴键；60秒测试需单独启用声音。默认试用音源覆盖64键，局部候选可能缺音。诊断仅记录本App聚合计数与输出峰值，不含按键序列或音频样本；非扬声器实际出声证明。系统Dock使用原生自动隐藏设置。")
        diagnosticsLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let diagnosticButtons = NSStackView(views: [button("刷新运行诊断", #selector(refreshDiagnostics)), button("导出诊断 JSON…", #selector(exportDiagnostics))])
        diagnosticButtons.orientation = .horizontal; diagnosticButtons.spacing = 10
        let stack = NSStackView(views: [title, permission, first, second, preview, status, diagnosticsLabel, diagnosticButtons, detail])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 18), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20)])
        overlayView = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: AdaptiveOverlay.canvasHeight))
        panel = ProbePanel(content: overlayView)
        preview.showLabels = labels; overlayView.showLabels = labels
        positionPanel()
    }
    private func positionPanel() {
        let screens = NSScreen.screens
        if targetScreen == nil || !screens.contains(where: { $0 === targetScreen }) {
            targetScreen = screens.first { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(id.uint32Value) != 0
            } ?? NSScreen.main ?? screens.first
        }
        guard let screen = targetScreen else { panel.alphaValue = 0; panel.orderOut(nil); return }
        panel.setFrame(AdaptiveOverlay.frame(screen: screen.frame), display: true)
    }
    @objc private func startLocal() { start(global: false) }
    @objc private func startGlobal() { start(global: true) }
    func start(global: Bool) {
        lastGlobal = global
        sessionDuration = .test60Seconds
        pause("准备测试")
        coordinator.resume()
        do {
            try input.start(global: global, duration: .test60Seconds)
            receivedCount = 0
            sessionStatus = global ? "运行中：全局60秒测试" : "运行中：本窗口60秒测试"
            status.stringValue = global ? "只观察监听器已建立；60秒内自动停止，实际捕获待实按。" : "本窗口60秒测试已开启。事件原样传递；不保存文本或逐键历史。"
        } catch { pause(error.localizedDescription); showControlWindow() }
        refresh()
    }
    @objc private func cancelStartup() {
        pause("已取消本次开始；可随时重新点击主按钮。")
        startupMessage.stringValue = sessionStatus
        updateStartupControls()
    }
    private func handleStartup(_ event: StartupFlow.Event) {
        guard !authorizationRequestInFlight else { return }
        if event == .becameActive && !authorizationReturnGate.canContinue(permission: permissionCheck()) { return }
        do {
            let action = try startupFlow.handle(event, permission: permissionCheck(), secureInput: overlayBlocked)
            switch action {
            case .none: break
            case .start: startContinuousTrial(global: true)
            case .requestAuthorization:
                sessionStatus = "已暂停：等待本次输入监控授权"
                startupMessage.stringValue = "请在系统设置中允许打字钢琴，返回App后将继续本次开始操作。若系统要求退出，请重新打开同一路径App并点击主按钮继续。可取消本次开始。"
                authorizationReturnGate.beginRequest()
                authorizationRequestInFlight = true
                updateStartupControls()
                _ = CGRequestListenEventAccess() // Only this explicit primary-button path can request.
                if permissionCheck() && NSApp.isActive {
                    authorizationRequestInFlight = false
                    authorizationReturnGate.reset()
                    handleStartup(.becameActive)
                    return
                }
                let opened = NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.systempreferences" { authorizationReturnGate.observedSettings() }
                authorizationRequestInFlight = false
                if !opened {
                    _ = try startupFlow.handle(.cancel, permission: false, secureInput: false)
                    startupMessage.stringValue = "未能打开系统设置，本次开始已取消。请手动前往隐私与安全性 → 输入监控允许本App，再点击开始。"
                    sessionStatus = "已暂停：未能打开输入监控设置"
                } else if NSApp.isActive && authorizationReturnGate.canContinue(permission: permissionCheck()) {
                    // A nested Settings activation/return may have occurred while the request was in flight.
                    handleStartup(.becameActive)
                    return
                }
            case .permissionMissing:
                startupMessage.stringValue = "尚未获得输入监控授权，本次开始已取消。可再次点击授权并开始；若系统要求重启或旧条目失效，请按安装说明处理后重开同一路径App。"
                sessionStatus = "已暂停：尚未获得输入监控授权"
            case .secureInput:
                startupMessage.stringValue = "安全输入正在阻断键盘监听，本次开始已取消。离开密码框或安全输入环境后，请主动点击开始。"
                sessionStatus = "已暂停：安全输入阻断"
            }
        } catch {
            startupMessage.stringValue = "无法保存本次开始状态，已保持停止：\(error.localizedDescription)"
            sessionStatus = "已暂停：开始状态保存失败"
        }
        updateStartupControls(); refresh()
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc func startLocalTrial() { startContinuousTrial(global: false) }
    @objc func startTrial() {
        guard input.mode != .global else { showStartupWindow(); return }
        pause("准备开始")
        showStartupWindow()
        handleStartup(.primary)
    }
    private func startContinuousTrial(global: Bool) {
        pause("准备开始")
        sessionDuration = .continuous; lastGlobal = global
        do {
            try ContinuousTrialStart.run(global: global, input: input, audio: audio) // Preloads outside key callbacks.
            _ = coordinator.setSoundEnabled(true); coordinator.resume()
            soundButton.title = "关闭声音并清尾音"
            receivedCount = 0
            sessionStatus = global ? "运行中：持续全局打字" : "运行中：本窗口试弹"
            if global && !showOverlay { toggleOverlay() }
            startupWindow.orderOut(nil)
            if !global { showControlWindow(); window.makeFirstResponder(preview) }
            status.stringValue = global ? "打字钢琴已开始；持续运行，使用 ♪ 菜单暂停或退出。" : "本窗口试弹已开始（无需权限）；可持续打字或点击琴键，失焦、关闭窗口或暂停即停止。"
            diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self, self.window.isVisible else { return }; self.refreshDiagnostics()
            }
            if let diagnosticsTimer { RunLoop.main.add(diagnosticsTimer, forMode: .common) }
            refreshDiagnostics()
        } catch {
            pause(error.localizedDescription)
            startupMessage.stringValue = "无法开始：\(error.localizedDescription)"
            startupWindow.setContentSize(NSSize(width: 480, height: 490))
            if installStatusItem { showStartupWindow() }
        }
        refresh()
    }
    func runtimeDiagnostics() -> [String: Any] {
        var result = audio.runtimeDiagnostics()
        result["effectiveKeyEvents"] = receivedCount
        result["inputMode"] = String(describing: input.mode)
        result["globalInputPermission"] = permissionCheck()
        result["secureInput"] = InputMonitor.secureInput
        result["alertVolumeObserved"] = alertVolume.observed.map { $0 as Any } ?? NSNull()
        result["alertVolumeOriginalThisSession"] = alertVolume.originalVolume.map { $0 as Any } ?? NSNull()
        result["alertVolumeOutcome"] = alertVolume.outcome.rawValue
        result["capturedAt"] = ISO8601DateFormatter().string(from: Date())
        result["requestedStatusItemWidthPt"] = ProbeMenu.statusItemWidth
        result["actualStatusItemButtonWidthPt"] = statusMenu?.actualStatusButtonWidth.map { $0 as Any } ?? NSNull()
        result["dockVisibility"] = lastDockVisibility.rawValue
        result["dockVisibilitySource"] = dockObserver.detail
        result["overlayAlpha"] = panel?.alphaValue ?? 0
        result["overlayRequested"] = showOverlay
        result["overlayVisible"] = panel?.isVisible ?? false
        result["overlayStatus"] = overlayStatus
        result["mappingVersion"] = mapping.mappingVersion
        result["keymapWarning"] = keymapWarning.map { $0 as Any } ?? NSNull()
        result["privacy"] = "Aggregate counters only; no key identities, sequences, samples, microphone, or other-app audio."
        return result
    }
    @objc private func refreshDiagnostics() {
        let d = runtimeDiagnostics()
        func value(_ key: String) -> String { guard let v = d[key], !(v is NSNull) else { return "未知" }; return String(describing: v) }
        diagnosticsLabel.stringValue = "输入 \(value("inputMode")) · 有效事件 \(value("effectiveKeyEvents")) · NoteOn 请求/受理 \(value("noteOnRequests"))/\(value("noteOnAccepted"))\n引擎运行 \(value("engineRunning")) · 采样器已载入 \(value("samplerLoaded")) · 音源 \(value("selectedSource")) · App音量 \(value("appVolume")) · mixer \(value("mixerGain")) · sampler dB \(value("samplerGainDB"))\n当前引擎输出 \(value("currentOutputDeviceName"))（ID \(value("currentOutputDeviceID"))）\n本引擎输出 tap：回调 \(value("outputTapCallbackCount")) · 帧 \(value("outputTapFrameCount")) · 峰值 \(value("outputTapPeak")) · 距末次回调秒 \(value("outputTapCallbackAgeSeconds"))"
    }
    @objc private func exportDiagnostics() {
        let snapshot = runtimeDiagnostics()
        let panel = NSSavePanel(); panel.nameFieldStringValue = "typing-piano-diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            status.stringValue = "已导出聚合诊断：\(url.lastPathComponent)；输出峰值不是声学出声证明。"
        } catch { status.stringValue = "诊断导出失败：\(error.localizedDescription)" }
    }
    private func receive(_ event: NormalizedKeyEvent, source: KeyInputSource = .keyboard) {
        guard input.mode != .stopped, !overlayBlocked else { return }
        if source == .keyboard && ignoredUntilRelease.contains(event.physicalKeyID) {
            if event.phase == .up { ignoredUntilRelease.remove(event.physicalKeyID) }
            return
        }
        guard let normalized = reducer.consume(event, source: source) else { return }
        receivedCount += 1
        apply(coordinator.consume(normalized))
        if let strike = coordinator.lastStrike {
            let time = ProcessInfo.processInfo.systemUptime
            preview.strike(strike, at: time); overlayView.strike(strike, at: time)
        }
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
        statusMenu?.update(soundEnabled: coordinator.soundEnabled, showLabels: labels, showOverlay: showOverlay, overlayVisible: !overlayBlocked && !dockFade.dockHidden && targetScreen != nil, overlayStatus: overlayStatus,
            paused: coordinator.paused, dockDesired: dock.observed ?? dock.desired, dockKnown: dock.observed != nil, systemDock: systemDock, sourceID: audio.source.id, sessionStatus: sessionStatus + (!coordinator.paused && !coordinator.soundEnabled ? "（声音关闭）" : ""))
        statusMenu?.updateKeymap(custom: customConfiguration != CustomKeymap(defaultMapping: defaultMapping), warning: keymapWarning)
        updateStartupControls()
        preview?.setSceneVisible(window?.isVisible == true && !coordinator.paused)
        let keys = Set(coordinator.active.values.map { $0.key.midiNote })
        preview?.activeMIDI = keys
        let sceneVisible = showOverlay && !overlayBlocked && coordinator.visualEnabled && !dockFade.dockHidden
        if sceneVisible && !overlaySceneVisible {
            // Restore held-key state while invisible, so no historical down animation or note is replayed.
            overlayView?.setSceneVisible(false); overlayView?.activeMIDI = keys
        }
        overlayView?.setSceneVisible(sceneVisible); overlaySceneVisible = sceneVisible
        if sceneVisible { overlayView?.activeMIDI = keys }
        updatePanelOpacity()
    }
    @objc func stopAll() { pause("已暂停：监听、声音、尾音与动画已清理；钢琴可静态显示。") }
    private func pause(_ reason: String, preserveAuthorization: Bool = false) {
        if !preserveAuthorization {
            authorizationReturnGate.reset()
            do { _ = try startupFlow.handle(.cancel, permission: false, secureInput: false) }
            catch { startupMessage.stringValue = "取消待授权开始状态保存失败：\(error.localizedDescription)" }
        }
        sessionStatus = "已暂停：\(reason)"
        diagnosticsTimer?.invalidate(); diagnosticsTimer = nil
        input.stop(); reducer.reset(); ignoredUntilRelease.removeAll()
        for item in pending.values { item.cancel() }; pending.removeAll()
        apply(coordinator.panic(paused: true))
        audio.disable(); _ = coordinator.setSoundEnabled(false)
        soundButton?.title = "启用所选声音"
        preview?.resetEffects(); overlayView?.resetEffects()
        status.stringValue = reason; refresh(); refreshDiagnostics()
    }
    @objc func toggleSound() {
        if coordinator.soundEnabled {
            apply(coordinator.setSoundEnabled(false)); audio.disable()
            soundButton.title = "启用所选声音"
        } else {
            do {
                try audio.enable()
                _ = coordinator.setSoundEnabled(true)
                soundButton.title = "关闭声音并清尾音"
            } catch { status.stringValue = "音频准备失败：\(error.localizedDescription)"; showControlWindow() }
        }
        refresh()
    }
    @objc private func toggleLabels() {
        labels.toggle(); preview.showLabels = labels; overlayView.showLabels = labels
        preferences.showKeyLabels = labels; savePreferences(); refresh()
    }
    @objc func toggleOverlay() {
        showOverlay.toggle()
        if showOverlay {
            dockObserver.invalidate()
            dockFade.setReducedMotion(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, at: ProcessInfo.processInfo.systemUptime)
            positionPanel()
            lastDockVisibility = observeDock(at: ProcessInfo.processInfo.systemUptime)
            dockFade = DockFade(initialVisibility: lastDockVisibility)
            dockFade.setReducedMotion(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, at: ProcessInfo.processInfo.systemUptime)
            coordinator.dockHidden = dockFade.dockHidden
            dockTimer?.invalidate()
            dockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.dockTick() }
            if let dockTimer { RunLoop.main.add(dockTimer, forMode: .common) }
        } else { dockTimer?.invalidate(); dockTimer = nil }
        refresh()
    }
    @objc private func acknowledge() { dockObserver.invalidate(); dockTick() }
    private func observeDock(at time: TimeInterval) -> DockVisibility {
        guard let screen = targetScreen,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return .unknown }
        let bounds = CGDisplayBounds(id.uint32Value)
        return dockVisibilityCheck?(bounds, time) ?? dockObserver.observe(screenBounds: bounds, at: time)
    }
    func setSessionBlocked(_ blocked: Bool, reason: String = "session") {
        if blocked { sessionBlocks.insert(reason) } else { sessionBlocks.remove(reason) }
        if blocked { pause("系统会话/睡眠阻断：已安全暂停") }
        else { refresh() } // Never resumes input or audio.
    }
    func dockTick() {
        if overlayBlocked && !coordinator.paused { pause("安全输入或系统会话阻断：已安全暂停") }
        guard showOverlay else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastDockVisibility = observeDock(at: now)
        dockFade.observe(lastDockVisibility, at: now)
        coordinator.dockHidden = dockFade.dockHidden
        refresh()
    }
    private func updatePanelOpacity() {
        guard showOverlay, !overlayBlocked, targetScreen != nil, coordinator.visualEnabled else {
            fadeTimer?.invalidate(); fadeTimer = nil; fadeTimerGeneration = nil
            panel?.alphaValue = 0; panel?.orderOut(nil); return
        }
        let now = ProcessInfo.processInfo.systemUptime
        panel?.alphaValue = dockFade.alpha(at: now)
        if dockFade.alpha(at: now) > 0 || dockFade.isAnimating(at: now) {
            if panel?.isVisible == false { panel?.orderFrontRegardless() }
        } else { panel?.orderOut(nil) }
        guard dockFade.isAnimating(at: now) else {
            fadeTimer?.invalidate(); fadeTimer = nil; fadeTimerGeneration = nil; return
        }
        guard fadeTimerGeneration != dockFade.generation else { return }
        fadeTimer?.invalidate()
        let generation = dockFade.generation; fadeTimerGeneration = generation
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { [weak self] timer in
            guard let self, self.dockFade.generation == generation else { timer.invalidate(); return }
            self.updatePanelOpacity()
        }
        if let fadeTimer { RunLoop.main.add(fadeTimer, forMode: .common) }
    }
    private func togglePause() {
        if coordinator.paused { startTrial() } else { stopAll() }
    }
    func selectSource(_ id: String) {
        guard let source = sources.first(where: { $0.id == id }), source.id != audio.source.id else { return }
        audio.select(source) { [self] in
            // stop() advances the input epoch, invalidating observations queued for the old bank.
            pause("切换音源，测试已停止")
            _ = coordinator.setSoundEnabled(false)
            preview.resetEffects(); overlayView.resetEffects()
        }
        soundButton.title = "启用所选声音"
        status.stringValue = "已选择\(source.title)。测试与声音已停止，需重新开启测试并启用声音；缺音不会替补。"
        refresh()
    }
    private func showKeymapEditor() {
        do {
            if keymapEditor?.window?.isVisible != true {
                keymapEditor = try KeymapEditor(base: defaultMapping, configuration: { [unowned self] in self.customConfiguration }, warning: keymapWarning) { [unowned self] candidate, baseline in
                    try self.saveCustomKeymap(candidate, expected: baseline)
                }
            }
            keymapEditor?.showWindow(nil); keymapEditor?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch { status.stringValue = "无法打开键位设置：\(error.localizedDescription)" }
    }
    func saveCustomKeymap(_ configuration: CustomKeymap, expected: CustomKeymap? = nil) throws {
        if let expected, expected != customConfiguration { throw ProbeError.invalid("键位已在其他位置更新，请重新载入后调整") }
        let next = try configuration.mapping(from: defaultMapping)
        try customStore.save(configuration) // No runtime changes if validation/persistence fails.
        let paused = coordinator.paused, sound = coordinator.soundEnabled
        ignoredUntilRelease = input.discardPendingEvents()
        reducer.reset()
        for item in pending.values { item.cancel() }; pending.removeAll()
        apply(coordinator.panic(paused: paused)) // Keep the prepared audio engine and volume.
        mapping = next; coordinator = NoteCoordinator(mapping: next)
        _ = coordinator.setSoundEnabled(sound)
        if paused { _ = coordinator.panic(paused: true) }
        preview?.setMapping(next); overlayView?.setMapping(next)
        customConfiguration = configuration; keymapWarning = nil
        if overlayBlocked { pause("安全输入或系统会话阻断：已安全暂停") }
        refresh()
    }
    private func alert(_ title: String, _ text: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
        for title in buttons { alert.addButton(withTitle: title) }
        alert.buttons.first?.keyEquivalent = "\r"
        return alert.runModal()
    }
    private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.7"
        _ = alert("打字钢琴 · \(version)", "默认停止输入与声音。点击开始打字钢琴后持续运行，可从菜单暂停或退出；测试菜单仍保留60秒模式。全局测试仅在已有输入监控授权时启动；仅在点击授权并开始时申请输入监控，不修改输入。Fn、Caps Lock、双侧修饰、中文输入和系统Dock仍需实按验收。Dock调用系统原生自动隐藏设置，钢琴宽度自动适应屏幕。默认使用全64音试用钢琴；测试子菜单中的局部候选缺音不替补。", buttons: ["知道了"])
    }
    private func dockResult(_ outcome: DockAdapter.Outcome) {
        let observed = dock.observed.map { $0 ? "开启" : "关闭" } ?? "未知"
        status.stringValue = "Dock\(systemDock ? "系统" : "模拟")：\(outcome.rawValue)，原生状态读回\(observed)。实际Dock显隐由独立观察器核对。\(dock.detail)"
        if [.failed, .unknown, .externalChange, .recoveryRequired].contains(outcome) { showControlWindow() }
        refresh()
    }
    private func toggleDock() {
        let desired = !(dock.observed ?? dock.desired)
        if !desired {
            let response = alert("关闭 Dock 自动隐藏？", "关闭自动隐藏后，Dock 可能与底部钢琴重叠或遮挡。仍要关闭吗？", buttons: ["保持自动隐藏", "仍然关闭"])
            guard response == .alertSecondButtonReturn else { return }
        }
        dockResult(dock.request(desired, confirmedDisable: true))
    }
    private func refreshAlertMenu() {
        statusMenu?.updateAlertVolume(muted: alertVolume.mutedState, detail: alertVolume.detail)
    }
    private func toggleAlertMute() {
        if alertVolume.hasOwnedChange {
            _ = alertVolume.restore()
        } else {
            let result = alertVolume.refresh()
            guard result != .failed else { reportAlertVolumeFailure(); return }
            if alertVolume.observed == 0 {
                _ = alert("系统提示音原已静音", "本App没有可恢复的原音量，不会猜测50%或100%。如需开启，请使用菜单中的系统声音设置。", buttons: ["知道了"])
                refreshAlertMenu(); return
            }
            let confirmed = alert("静音系统提示音？", "这会将macOS系统提示音音量设为0，影响所有遵守该音量的系统警告，不仅是没有输入框时的提示音。钢琴与媒体音量不变。关闭或正常退出仅恢复本次仍由App拥有的改动；异常退出请在系统声音设置恢复。", buttons: ["取消", "静音提示音"]) == .alertSecondButtonReturn
            _ = alertVolume.mute(confirmed: confirmed)
        }
        if alertVolume.outcome == .failed { reportAlertVolumeFailure() }
        refreshAlertMenu()
    }
    private func reportAlertVolumeFailure() {
        refreshAlertMenu()
        _ = alert("系统提示音操作未完成", alertVolume.detail + "\n未报告成功。可使用“系统声音设置…”检查；不会追加权限或修改媒体音量。", buttons: ["知道了"])
    }
    private func openSoundSettings() {
        if !NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!) {
            _ = alert("系统声音设置", "请手动打开系统设置 → 声音 → 提示音音量。", buttons: ["知道了"])
        }
    }
    private func openDockSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            _ = alert("系统Dock设置", "请打开系统设置 → 桌面与程序坞 → 自动隐藏和显示程序坞。", buttons: ["知道了"])
        }
    }
    private func systemAdapter() -> DockAdapter {
        DockAdapter(storage: NativeDockStorage(), tickets: FileDockTicketStore(url: preferencesURL.deletingLastPathComponent().appendingPathComponent("dock-recovery.json")))
    }
    private func recoverDock() {
        let adapter = systemDock ? dock : systemAdapter()
        guard adapter.recoveryPending else {
            _ = alert("Dock恢复票据", "没有待处理的恢复票据。未修改系统。", buttons: ["知道了"]); return
        }
        guard alert("处理上次 Dock 恢复票据？", "将重新读取系统值；只有仍与票据记录相符才恢复原值。布尔值相同无法证明期间没有外部操作，请确认当前需要恢复。", buttons: ["暂不处理", "检查并恢复"]) == .alertSecondButtonReturn else { return }
        let outcome = adapter.recoverPreviousSession(confirmed: true)
        if systemDock { dockResult(outcome) }
        else { _ = alert("Dock恢复结果", "\(outcome.rawValue)。偏好读回不等于视觉生效。\(adapter.detail)", buttons: ["知道了"]) }
    }
    private func installSafetyHooks() {
        notifications.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.systempreferences" else { return }
            self?.authorizationReturnGate.observedSettings()
        })
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.startupWindow != nil, !self.authorizationRequestInFlight else { return }
            self.handleStartup(.becameActive)
        })
        notifications.append(DistributedNotificationCenter.default().addObserver(forName: PianoSingleInstance.reopenNotification,
            object: String(ProcessInfo.processInfo.processIdentifier), queue: .main) { [weak self] _ in
            self?.handleDuplicateLaunch() // Reveal only; notification never starts input or requests permission.
        })
        let access = NSWorkspace.shared.notificationCenter
        notifications.append(access.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            self?.preview.reducedMotion = reduced; self?.overlayView.reducedMotion = reduced
            self?.dockFade.setReducedMotion(reduced, at: ProcessInfo.processInfo.systemUptime)
            self?.refresh()
        })
        preview.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        overlayView.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.input.mode == .local else { return }
            self.pause("本窗口测试失焦，已清理按键和声音；全局测试不受此规则影响")
        })
        let distributed = DistributedNotificationCenter.default()
        notifications.append(distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.setSessionBlocked(true, reason: "lock") })
        notifications.append(distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.setSessionBlocked(false, reason: "lock") })
        let workspace = NSWorkspace.shared.notificationCenter
        for (name, reason) in [(NSWorkspace.willSleepNotification, "sleep"), (NSWorkspace.sessionDidResignActiveNotification, "inactiveSession")] {
            notifications.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.setSessionBlocked(true, reason: reason) })
        }
        for (name, reason) in [(NSWorkspace.didWakeNotification, "sleep"), (NSWorkspace.sessionDidBecomeActiveNotification, "inactiveSession")] {
            notifications.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.setSessionBlocked(false, reason: reason) })
        }
        notifications.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.dockObserver.invalidate(); self?.dockTick()
        })
        notifications.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.targetScreen = nil; self?.positionPanel(); self?.refresh()
        })
        notifications.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] notification in
            guard let self, self.audioReady, self.audio.isCurrentEngineNotification(notification.object as AnyObject?) else { return }
            self.pause("音频配置变化：已停用，需手动重新启用声音")
            self.audio.disable(); _ = self.coordinator.setSoundEnabled(false)
            self.soundButton.title = "启用所选声音"
            self.refresh()
        })
    }
    var integrationState: (activeKeys: Int, floatingNotes: Int, previewFloatingNotes: Int, soundEnabled: Bool) {
        (coordinator.active.count, overlayView?.floatingCount ?? 0, preview?.floatingCount ?? 0, coordinator.soundEnabled)
    }
    public func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow, closing === startupWindow {
            if startupFlow.pendingAuthorization { cancelStartup() }
            return
        }
        if input.mode == .local || sessionDuration == .test60Seconds { pause("测试控制台已关闭；测试停止") }
    }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let result = alertVolume.restore()
        guard result == .failed else { return .terminateNow }
        let response = alert("提示音恢复未完成", alertVolume.detail + "\n取消退出可重试或打开系统声音设置；仍然退出可能保留当前提示音设置。", buttons: ["取消退出", "仍然退出"])
        skipAlertRestoreOnExit = response == .alertSecondButtonReturn
        return skipAlertRestoreOnExit ? .terminateNow : .terminateCancel
    }
    public func applicationWillTerminate(_ notification: Notification) {
        if !skipAlertRestoreOnExit { _ = alertVolume.restore() }
        keymapEditor?.close()
        showOverlay = false; dockTimer?.invalidate(); dockTimer = nil
        pause("退出", preserveAuthorization: true); audio.disable(); window?.orderOut(nil); startupWindow?.orderOut(nil)
        _ = dock.restoreOnExit() // Failure leaves an atomic recovery ticket; no retry loop.
    }
}
