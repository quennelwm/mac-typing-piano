import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class CompactMenuTests: XCTestCase {
    func testFinalNativeMenuWidthAndRootContentsAcrossStates() throws {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 1, heightScale: 1.8, installStatusItem: false)
        var rows: [[String: Any]] = [["state": "initial", "width": menu.menu.size.width, "height": menu.menu.size.height, "visibleRootCount": menu.menu.items.filter { !$0.isHidden }.count]]
        for state in ["运行中：持续全局打字", "已暂停：尚未获得输入监控授权", "已暂停：安全输入阻断", "已暂停：开始状态保存失败"] {
            menu.update(soundEnabled: true, showLabels: true, showOverlay: true, overlayStatus: "安全输入阻断，结束后仅恢复静态显示", paused: state.hasPrefix("已暂停"), sessionStatus: state)
            menu.setPreferencesSaveError(state.contains("失败") ? String(repeating: "磁盘写入失败", count: 30) : nil)
            menu.setTransparency(1, reduced: state.contains("安全"))
            menu.updateKeymap(custom: false, warning: "配置读取失败")
            menu.updatePermission(granted: !state.contains("授权"))
            let size = menu.menu.size
            rows.append(["state": state, "width": size.width, "height": size.height, "visibleRootCount": menu.menu.items.filter { !$0.isHidden }.count, "titles": menu.menu.items.filter { !$0.isHidden }.map(\.title)])
            XCTAssertGreaterThanOrEqual(size.width, 170)
            XCTAssertLessThanOrEqual(size.width, 195)
        }
        if let path = ProcessInfo.processInfo.environment["TYPING_PIANO_MENU_EVIDENCE"] {
            try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
        }
        XCTAssertNotNil(menu.menu.items.first { $0.title == "输入监控授权…" })
        XCTAssertNotNil(menu.menu.items.first { $0.title == "系统选项" }?.submenu)
        XCTAssertNotNil(menu.menu.items.first { $0.title == "帮助与测试" }?.submenu)
        XCTAssertEqual(menu.menu.items.filter { $0.view != nil }.count, 3)
    }

    func testRootCallbacksSlidersAndTextBounds() throws {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 1, heightScale: 1.8, installStatusItem: false)
        menu.setTransparency(1, reduced: false)
        var opens = 0, closes = 0
        menu.onWillOpen = { opens += 1 }; menu.onDidClose = { closes += 1 }
        let child = try XCTUnwrap(menu.menu.items.first { $0.submenu != nil }?.submenu)
        menu.menuWillOpen(child); menu.menuDidClose(child)
        XCTAssertEqual(opens, 0); XCTAssertEqual(closes, 0)
        menu.menuWillOpen(menu.menu); menu.menuDidClose(menu.menu)
        XCTAssertEqual(opens, 1); XCTAssertEqual(closes, 1)
        var values: [Double] = []
        menu.onVolume = { values.append($0) }; menu.onHeight = { values.append($0) }; menu.onTransparency = { values.append($0) }
        for slider in [menu.slider, menu.heightSlider, menu.transparencySlider] {
            XCTAssertTrue(slider.isContinuous)
            XCTAssertTrue(slider.sendAction(slider.action, to: slider.target))
        }
        XCTAssertEqual(values, [1, 1.8, 1])
        for view in menu.menu.items.compactMap(\.view) {
            for label in view.subviews.compactMap({ $0 as? NSTextField }) {
                XCTAssertLessThanOrEqual(label.fittingSize.width, label.frame.width, label.stringValue)
                XCTAssertTrue(view.bounds.contains(label.frame))
            }
        }
    }
    func testPermissionMenuOnlyReadsUntilExplicitClickAndPreservesHeldAudio() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = ControllerIntegrationTests.Input(), engine = ControllerIntegrationTests.Engine()
        var secure = false
        var granted = false, checks = 0, reveals = 0, settings = 0, requests = 0
        let controller = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.playable.v0.2.json")), sources: AudioSource.available(root: root, bundled: false), preferencesURL: folder.appendingPathComponent("preferences.json"), input: input, audioEngine: engine, installStatusItem: false, startupWindowPresenter: { reveals += 1 }, secureInputCheck: { secure }, permissionCheck: { checks += 1; return granted }, authorizationRequester: { requests += 1; return false }, inputSettingsOpener: { settings += 1; return true })
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        let menu = try XCTUnwrap(controller.statusMenu)
        let item = try XCTUnwrap(menu.menu.items.first { $0.title == "输入监控授权…" })
        let beforeChecks = checks
        menu.menuWillOpen(menu.menu); menu.menuDidClose(menu.menu)
        XCTAssertGreaterThan(checks, beforeChecks)
        XCTAssertEqual(item.state, .off); XCTAssertEqual(reveals, 0); XCTAssertEqual(settings, 0); XCTAssertEqual(requests, 0)
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("authorization-start.json").path))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        XCTAssertEqual(reveals, 1); XCTAssertEqual(settings, 1); XCTAssertEqual(requests, 1)
        XCTAssertEqual(input.mode, .stopped)
        granted = true
        controller.start(global: true); controller.toggleSound()
        input.onEvent?(.init("keyG", .down))
        let held = controller.integrationState.activeKeys, panic = engine.panics, shutdown = engine.shutdowns
        menu.menuWillOpen(menu.menu)
        XCTAssertEqual(item.state, .on)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        menu.menuDidClose(menu.menu)
        XCTAssertEqual(settings, 2); XCTAssertEqual(reveals, 1); XCTAssertEqual(requests, 1)
        XCTAssertEqual(input.mode, .global); XCTAssertTrue(engine.prepared)
        XCTAssertEqual(controller.integrationState.activeKeys, held)
        XCTAssertEqual(engine.panics, panic); XCTAssertEqual(engine.shutdowns, shutdown)
        input.onEvent?(.init("keyG", .up))
        XCTAssertEqual(controller.integrationState.activeKeys, 0)
        granted = false; secure = true
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        XCTAssertEqual(requests, 1); XCTAssertEqual(settings, 2)
        XCTAssertEqual(input.mode, .stopped)
        XCTAssertEqual(menu.menu.items.first?.title, "安全输入已暂停")
    }
}
