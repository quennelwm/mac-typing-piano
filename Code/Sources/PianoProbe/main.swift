import AppKit
import CryptoKit
import Foundation
import PianoCore
import PianoMac

func emit(_ object: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
}
let arguments = CommandLine.arguments
let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let resources = Bundle.main.resourceURL ?? sourceRoot
let bundleMap = resources.appendingPathComponent("keymap.ansi64.v0.1.json")
let bundled = FileManager.default.fileExists(atPath: bundleMap.path)
let mappingURL = bundled ? bundleMap : sourceRoot.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")
let bankURL = bundled ? resources.appendingPathComponent("placeholder-original.sf2") : sourceRoot.appendingPathComponent("Code/Assets/placeholder-original.sf2")
do {
    let mapping = try KeyMapping.load(url: mappingURL)
    _ = try SDKKeys.resolve(mapping)
    if arguments.contains("--self-check") {
        emit(["mappingVersion": mapping.mappingVersion, "keyCount": mapping.keys.count,
            "mappingSHA256": SHA256.hash(data: try Data(contentsOf: mappingURL)).map { String(format: "%02x", $0) }.joined(),
            "existingInputPermissionForThisProcess": InputMonitor.hasExistingPermission,
            "secureInputEnabled": InputMonitor.secureInput,
            "listenerStarted": false, "permissionRequested": false, "audioOutputStarted": false,
            "dockSettingWritten": false, "realKeysTested": false])
    } else if let index = arguments.firstIndex(of: "--snapshot"), arguments.count > index + 1 {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for width in [900, 1000, 1100] {
            for labels in [true, false] {
                let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: width, height: 56))
                view.appearance = NSAppearance(named: .aqua); view.showLabels = labels
                try view.savePNG(to: directory.appendingPathComponent("m0-\(width)-labels-\(labels).png"))
            }
        }
        emit(["kind": "offscreen AppKit M0 snapshot", "images": 6, "hardwareInput": false, "outputDirectory": directory.path])
    } else if arguments.contains("--window-smoke") {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let before = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 900, height: 56))
        let panel = ProbePanel(content: view)
        if let screen = NSScreen.main { panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 450, y: screen.visibleFrame.minY + 8)) }
        panel.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
        let after = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -2
        let passed = before == after && !panel.isKeyWindow && !panel.isMainWindow && panel.ignoresMouseEvents && panel.level == .normal && panel.isVisible
        emit(["kind": "programmatic window smoke, not click/Dock acceptance", "passed": passed,
            "frontmostPIDUnchanged": before == after, "isKeyWindow": panel.isKeyWindow, "isMainWindow": panel.isMainWindow,
            "ignoresMouseEvents": panel.ignoresMouseEvents, "windowLevel": panel.level.rawValue,
            "visible": panel.isVisible, "opaque": panel.isOpaque, "screenCount": NSScreen.screens.count,
            "existingInputPermissionForThisProcess": InputMonitor.hasExistingPermission,
            "listenerStarted": false, "audioOutputStarted": false, "dockSettingWritten": false])
        panel.orderOut(nil); panel.close()
        if !passed { exit(2) }
    } else if arguments.contains("--menu-smoke") {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let shell = ProbeMenu(volume: 0.5, installStatusItem: false)
        var callback: Double = -1
        shell.onVolume = { callback = $0 }
        shell.slider.doubleValue = 0.75
        _ = shell.slider.sendAction(shell.slider.action, to: shell.slider.target)
        let passed = callback == 0.75 && shell.percentage.stringValue == "75%" && shell.icon.isTemplate && shell.slider.isContinuous
        emit(["kind": "programmatic native menu control smoke; actual menu tracking/drag not tested", "passed": passed,
            "callbackVolume": callback, "percentage": shell.percentage.stringValue, "templateIcon": shell.icon.isTemplate,
            "nativeContinuousSlider": shell.slider.isContinuous, "menuItems": shell.menu.items.count,
            "audioOutputStarted": false, "systemVolumeChanged": false])
        if !passed { exit(2) }
    } else {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let preferenceRoot = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL.deletingLastPathComponent() : sourceRoot.appendingPathComponent("Code/build")
        let delegate = try ProbeController(mapping: mapping, bankURL: bankURL, preferencesURL: preferenceRoot.appendingPathComponent("probe-preferences.json"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
} catch {
    fputs("C-001 probe failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
