import AppKit
import CryptoKit
import Foundation
import PianoCore
import PianoAudio
import PianoMac

func emit(_ object: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
}
let arguments = CommandLine.arguments
let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let resources = Bundle.main.resourceURL ?? sourceRoot
let bundleMap = resources.appendingPathComponent(KeyMapping.defaultFilename)
let bundled = FileManager.default.fileExists(atPath: bundleMap.path)
let mappingFolder = bundled ? resources : sourceRoot.appendingPathComponent("contracts")
let mappingURL = mappingFolder.appendingPathComponent(KeyMapping.defaultFilename)
let themeURL = bundled ? resources.appendingPathComponent("theme.candidate.json") : sourceRoot.appendingPathComponent("Design/UI/theme.candidate.json")
do {
    let mapping = try KeyMapping.load(url: mappingURL)
    let provenance = try QuietIvoryProvenance(themeURL: themeURL, mappingURL: mappingURL)
    _ = try SDKKeys.resolve(mapping)
    if let index = arguments.firstIndex(of: "--live-audio-smoke") {
        guard arguments.count > index + 1, let seconds = Double(arguments[index + 1]), seconds.isFinite, (2...30).contains(seconds) else {
            throw ProbeError.invalid("--live-audio-smoke requires 2...30 seconds; this explicit command plays a fixed test phrase through the current output device.")
        }
        let source = try AudioSource.available(root: bundled ? resources : sourceRoot, bundled: bundled)[0]
        let engine = SamplerAudio()
        let session = AuditionSession(engine: engine, source: source)
        session.setVolume(0.5)
        defer { session.disable() }
        try session.enable()
        // Explicit CLI only. No input listener, windows, microphone, or system setting changes.
        for midi: UInt8 in [60, 64, 67] {
            session.noteOn(midi: midi, velocity: 64)
            Thread.sleep(forTimeInterval: 0.12)
            session.noteOff(midi: midi)
        }
        Thread.sleep(forTimeInterval: max(0, seconds - 0.36))
        var report = session.runtimeDiagnostics()
        report["kind"] = "explicit live output smoke; aggregate mixer metrics are not acoustic proof"
        report["durationSeconds"] = seconds; report["listenerStarted"] = false
        session.disable()
        report["cleanupEngineRunning"] = engine.runtimeDiagnostics()["engineRunning"]
        emit(report)
    } else if arguments.contains("--dock-visibility-snapshot") {
        let screen = NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(id.uint32Value) != 0
        } ?? NSScreen.main
        guard let screen, let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { throw ProbeError.invalid("没有可用目标屏幕") }
        let observer = DockWindowVisibilityObserver()
        let state = observer.observe(screenBounds: CGDisplayBounds(id.uint32Value), at: ProcessInfo.processInfo.systemUptime)
        emit(["dockVisibility":state.rawValue,"source":observer.detail,"targetDisplayID":id,
              "pianoWidthPt":AdaptiveOverlay.frame(screen:screen.frame).width,"permissionRequested":false,"systemSettingWritten":false])
    } else if arguments.contains("--self-check") {
        emit(["mappingVersion": mapping.mappingVersion, "keyCount": mapping.keys.count,
            "theme": provenance.metadata,
            "audioSources": try AudioSource.available(root: bundled ? resources : sourceRoot, bundled: bundled).map { source in
                ["id": source.id, "title": source.title, "coverage": source.coveredMIDI.sorted(), "path": source.url.path,
                 "exists": FileManager.default.fileExists(atPath: source.url.path), "maximumMixerGain": source.maximumMixerGain, "samplerGainDB": source.samplerGainDB]
            },
            "mappingSHA256": SHA256.hash(data: try Data(contentsOf: mappingURL)).map { String(format: "%02x", $0) }.joined(),
            "existingInputPermissionForThisProcess": InputMonitor.hasExistingPermission,
            "secureInputEnabled": InputMonitor.secureInput,
            "listenerStarted": false, "permissionRequested": false, "audioOutputStarted": false,
            "dockSettingWritten": false, "realKeysTested": false])
    } else if let index = (arguments.firstIndex(of: "--snapshot") ?? arguments.firstIndex(of: "--adaptive-snapshot")), arguments.count > index + 1 {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scenarios: [String: [String]] = ["rest": [], "single": ["keyA"],
            "multi": ["arrowRight", "commandLeft", "commandRight", "digit1", "digit8", "keyA", "keyD", "keyS", "optionLeft", "optionRight", "shiftLeft", "shiftRight", "space"]]
        var captures: [[String: Any]] = []
        for width in (arguments.contains("--adaptive-snapshot") ? [1264, 1496, 1904] : [900, 1000, 1100]) {
            for labels in [true, false] {
                for scenario in ["rest", "single", "multi"] {
                    let ids = scenarios[scenario]!
                    let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: CGFloat(width), height: AdaptiveOverlay.canvasHeight))
                    view.appearance = NSAppearance(named: .aqua); view.showLabels = labels
                    view.automaticAnimation = false; view.clock = { 0 }
                    view.activeMIDI = Set(ids.compactMap { mapping.key($0)?.midiNote })
                    view.advanceAnimations(at: 0.045)
                    for scale in [1, 2] {
                        let filename = "native-\(width)-\(scenario)-labels-\(labels)@\(scale)x.png"
                        try view.savePNG(to: directory.appendingPathComponent(filename), scale: scale)
                        captures.append(["file": filename, "widthPt": width, "canvasHeightPt": AdaptiveOverlay.canvasHeight,
                            "bodyOriginPt": [0, AdaptiveOverlay.headroom], "cropOriginPt": [0, 0], "backingScale": scale,
                            "scenario": scenario, "pressedPhysicalIDs": ids, "elapsedMs": 45, "showLabels": labels,
                            "reducedMotion": false, "hiddenReasons": [], "actualNativeMetrics": view.renderMetrics])
                    }
                }
            }
        }
        var metadata = provenance.metadata
        metadata["mappingVersion"] = mapping.mappingVersion; metadata["captures"] = captures
        metadata["kind"] = "production native offscreen RGBA rendering; no screen/hardware acceptance"
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("captures.json"))
        emit(["kind": "offscreen AppKit integration snapshots", "images": captures.count, "hardwareInput": false, "outputDirectory": directory.path])
    } else if let index = arguments.firstIndex(of: "--animation-snapshot"), arguments.count > index + 1 {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var rows: [[String: Any]] = []
        for reduced in [false, true] {
            for labels in [false, true] {
                let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: AdaptiveOverlay.canvasHeight))
                view.automaticAnimation = false; view.reducedMotion = reduced; view.showLabels = labels
                view.clock = { 0 }
                var coordinator = NoteCoordinator(mapping: mapping)
                for key in ["keyA", "commandLeft", "space", "digit8", "shiftRight"] {
                    _ = coordinator.consume(.init(key, .down))
                    if let strike = coordinator.lastStrike { view.strike(strike, at: 0) }
                }
                view.activeMIDI = Set(coordinator.active.values.map { $0.key.midiNote })
                for ms in Array(Set(Array(stride(from: 0, through: 920, by: 20)) + [350, 450, 899, 900])).sorted() {
                    let time = Double(ms) / 1000
                    if ms == 180 {
                        view.clock = { time }; view.activeMIDI = []
                        for key in Array(coordinator.active.keys) { _ = coordinator.consume(.init(key, .up)) }
                    }
                    view.advanceAnimations(at: time)
                    try view.savePNG(to: directory.appendingPathComponent("native-reduced-\(reduced)-labels-\(labels)-\(ms)ms.png"))
                    rows.append(["reducedMotion": reduced, "labels": labels, "timeMs": ms, "instances": view.floatingCount, "timer": view.animationTimerRunning,
                        "backingScale": 2, "canvasPt": [1000,AdaptiveOverlay.canvasHeight], "bodyOriginPt": [0,AdaptiveOverlay.headroom], "hiddenReasons": [],
                        "pressedPhysicalIDs": coordinator.active.keys.sorted(),
                        "pressIDs": coordinator.active.values.map { $0.id.uuidString },
                        "inkBoundsWithHaloPt": view.floatingInkBounds.map { [$0.minX, $0.minY, $0.width, $0.height] },
                        "notes": view.floatingPresentations.map { ["pressID": $0.pressID.uuidString, "midi": $0.midi, "rise": $0.rise, "driftX": $0.driftX, "opacity": $0.opacity] }])
                }
            }
        }
        // Short-up and mid-return restrike are rendered from the same live transition model.
        for scenario in ["short-tap", "restrike"] {
            let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1000, height: AdaptiveOverlay.canvasHeight))
            view.automaticAnimation = false
            var now = 0.0; view.clock = { now }
            var coordinator = NoteCoordinator(mapping: mapping)
            let midi = mapping.key("keyA")!.midiNote
            _ = coordinator.consume(.init("keyA", .down)); view.activeMIDI = [midi]
            view.strike(coordinator.lastStrike!, at: 0)
            for ms in [0, 10, 20, 44, 45, 60, 80, 90, 100, 125, 180, 350, 700, 780] {
                now = Double(ms) / 1000
                if ms == 10 { _ = coordinator.consume(.init("keyA", .up)); view.activeMIDI = [] }
                if ms == 80 && scenario == "restrike" {
                    _ = coordinator.consume(.init("keyA", .down)); view.activeMIDI = [midi]
                    view.strike(coordinator.lastStrike!, at: now)
                }
                view.advanceAnimations(at: now)
                let filename = "native-\(scenario)-\(ms)ms.png"
                try view.savePNG(to: directory.appendingPathComponent(filename))
                rows.append(["file": filename, "scenario": scenario, "timeMs": ms,
                    "backingScale": 2, "canvasPt": [1000,AdaptiveOverlay.canvasHeight], "bodyOriginPt": [0,AdaptiveOverlay.headroom],
                    "syntheticKey": "keyA", "depression": view.keyDepression(midi: midi, at: now),
                    "instances": view.floatingCount, "timer": view.animationTimerRunning,
                    "inkBoundsWithHaloPt": view.floatingInkBounds.map { [$0.minX, $0.minY, $0.width, $0.height] },
                        "notes": view.floatingPresentations.map { ["pressID": $0.pressID.uuidString, "midi": $0.midi, "rise": $0.rise, "driftX": $0.driftX, "opacity": $0.opacity] }])
            }
        }
        var metadata = provenance.metadata
        metadata["kind"] = "deterministic native production renderer frames; not hardware input or screen recording"
        metadata["frames"] = rows
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("frames.json"))
        emit(["frames": rows.count, "hardwareInput": false, "audioOutputStarted": false, "outputDirectory": directory.path])
    } else if let index = arguments.firstIndex(of: "--keymap-editor-snapshot"), arguments.count > index + 1 {
        _ = NSApplication.shared; NSApp.setActivationPolicy(.prohibited)
        emit(try KeymapEditorEvidence.render(base: mapping, directory: URL(fileURLWithPath: arguments[index + 1], isDirectory: true)))
    } else if arguments.contains("--window-smoke") {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory) // Match production without activating or taking focus.
        let report = OverlayWindowEvidence.run(mapping: mapping)
        emit(report)
        if report["passed"] as? Bool != true { exit(2) }
    } else if arguments.contains("--menu-smoke") {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let shell = ProbeMenu(volume: 0.5, sources: try AudioSource.available(root: bundled ? resources : sourceRoot, bundled: bundled), installStatusItem: false)
        var callback: Double = -1
        shell.onVolume = { callback = $0 }
        shell.slider.doubleValue = 0.75
        _ = shell.slider.sendAction(shell.slider.action, to: shell.slider.target)
        var iconRenders: [[String: Any]] = []
        for scale in [1, 2] {
            let size = Int(shell.icon.size.width) * scale
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ProbeError.invalid("图标离屏上下文创建失败") }
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            shell.icon.draw(in: NSRect(origin: .zero, size: shell.icon.size))
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            var edgeAlpha = 0.0, maximumAlpha = 0.0
            for y in 0..<size { for x in 0..<size {
                let alpha = Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
                maximumAlpha = max(maximumAlpha, alpha)
                if x == 0 || y == 0 || x == size - 1 || y == size - 1 { edgeAlpha = max(edgeAlpha, alpha) }
            } }
            iconRenders.append(["scale": scale, "pixels": size, "outerEdgeMaxAlpha": edgeAlpha, "maximumAlpha": maximumAlpha])
            if let index = arguments.firstIndex(of: "--menu-icon-output"), arguments.count > index + 1 {
                let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ProbeError.invalid("图标PNG编码失败") }
                try png.write(to: directory.appendingPathComponent("menu-icon-\(scale)x.png"))
            }
        }
        let passed = callback == 0.75 && shell.percentage.stringValue == "75%" && shell.icon.isTemplate && shell.slider.isContinuous
        emit(["kind": "programmatic native menu control smoke; actual menu tracking/drag not tested", "passed": passed,
            "iconRenders": iconRenders, "iconCanvasWidthPt": shell.icon.size.width,
            "callbackVolume": callback, "percentage": shell.percentage.stringValue, "templateIcon": shell.icon.isTemplate,
            "requestedStatusItemWidthPt": ProbeMenu.statusItemWidth,
            "statusBarThicknessPt": NSStatusBar.system.thickness,
            "nativeContinuousSlider": shell.slider.isContinuous, "menuItems": shell.menu.items.count,
            "audioOutputStarted": false, "systemVolumeChanged": false])
        if !passed { exit(2) }
    } else {
        guard let instanceLease = try PianoSingleInstance.acquireForGUI() else { exit(0) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let legacyRoot = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL.deletingLastPathComponent() : sourceRoot.appendingPathComponent("Code/build")
        let preferenceRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/local.typingpiano.trial")
        let preferenceURL = preferenceRoot.appendingPathComponent("probe-preferences.json")
        _ = try AppPreferences.loadMigrating(to: preferenceURL, legacyURL: legacyRoot.appendingPathComponent("probe-preferences.json"))
        let sources = try AudioSource.available(root: bundled ? resources : sourceRoot, bundled: bundled)
        let dock = DockAdapter(storage: NativeDockStorage(), tickets: FileDockTicketStore(url: legacyRoot.appendingPathComponent("dock-recovery.json")))
        let delegate = try ProbeController(mapping: mapping, sources: sources, preferencesURL: preferenceURL, dockAdapter: dock)
        app.delegate = delegate
        withExtendedLifetime((delegate, instanceLease)) { app.run() }
    }
} catch {
    fputs("C-001 probe failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
