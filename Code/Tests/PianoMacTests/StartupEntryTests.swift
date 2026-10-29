import XCTest
import AppKit
import PianoCore
import PianoAudio
@testable import PianoMac

final class StartupEntryTests: XCTestCase {
    func testReopenAndDuplicateLaunchRevealEntryWithoutStartingInput() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = LocalTrialStartTests.Input(), engine = LocalTrialStartTests.Engine()
        var reveals = 0
        let controller = try ProbeController(mapping: KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")),
            sources: [AudioSource(id: "test", title: "test", url: URL(fileURLWithPath: "/unused.sf2"), coveredMIDI: [60])],
            preferencesURL: folder.appendingPathComponent("preferences.json"), input: input, audioEngine: engine,
            installStatusItem: false, startupWindowPresenter: { reveals += 1 })
        XCTAssertFalse(controller.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
        controller.handleDuplicateLaunch()
        XCTAssertEqual(reveals, 2)
        XCTAssertEqual(input.mode, .stopped); XCTAssertFalse(engine.prepared)
    }
    func testMenuEntryDownloadAndPausedReasonUseNativeActions() throws {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 0.5, installStatusItem: false)
        var opens = 0, downloads = 0, muteClicks = 0, settingsClicks = 0
        menu.onStartup = { opens += 1 }; menu.onDownload = { downloads += 1 }
        menu.onMuteAlerts = { muteClicks += 1 }; menu.onSoundSettings = { settingsClicks += 1 }
        for title in ["打开启动窗口…", "下载新版…", "静音系统提示音", "系统声音设置…"] {
            let items = menu.menu.items + menu.menu.items.compactMap(\.submenu).flatMap(\.items)
            let item = try XCTUnwrap(items.first { $0.title == title })
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        }
        menu.update(soundEnabled: false, showLabels: true, showOverlay: false, paused: true, sessionStatus: "已暂停：安全输入阻断")
        XCTAssertEqual(menu.menu.items.first?.title, "安全输入已暂停")
        XCTAssertEqual(menu.menu.items.first?.toolTip, "已暂停：安全输入阻断")
        XCTAssertFalse(try XCTUnwrap(menu.menu.items.first).isEnabled)
        XCTAssertEqual(opens, 1); XCTAssertEqual(downloads, 1)
        XCTAssertEqual(muteClicks, 1); XCTAssertEqual(settingsClicks, 1)
        menu.updateAlertVolume(muted: nil, detail: "读取失败，未确认静音")
        XCTAssertEqual(menu.menu.items.compactMap(\.submenu).flatMap(\.items).first { $0.title == "静音系统提示音" }?.state, .mixed)
    }
}
