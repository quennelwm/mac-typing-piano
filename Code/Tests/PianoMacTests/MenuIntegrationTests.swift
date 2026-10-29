import XCTest
import AppKit
import PianoAudio
@testable import PianoMac

final class MenuIntegrationTests: XCTestCase {
    func testDailyMenuAndTestSourceCallbacksStaySeparated() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = try AudioSource.available(root: root, bundled: false)
        let menu = ProbeMenu(volume: 0.5, sources: sources, installStatusItem: false)
        XCTAssertFalse(menu.menu.items.contains { $0.title.contains("C-001") || $0.title.contains("M1") || $0.title.contains("60秒") })
        let test = try XCTUnwrap(menu.menu.items.first { $0.title == "帮助与测试" }?.submenu)
        let banks = try XCTUnwrap(test.items.first { $0.title == "试听音源" }?.submenu)
        XCTAssertEqual(banks.items.filter { $0.representedObject != nil }.count, 4)
        var selected = ""
        menu.onSource = { selected = $0 }
        let item = banks.items[2]
        NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item)
        XCTAssertEqual(selected, "vcsl-kawai")
        menu.update(soundEnabled: false, showLabels: false, showOverlay: true, sourceID: selected)
        XCTAssertEqual(item.state, .on)
        XCTAssertEqual(menu.menu.items.first { $0.title == "声音" }?.state, .off)
    }
    func testQuietIvoryProvenanceIsPinnedToApprovedMappingAndTheme() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let provenance = try QuietIvoryProvenance(themeURL: root.appendingPathComponent("Design/UI/theme.candidate.json"), mappingURL: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json"))
        XCTAssertEqual(provenance.themeVersion, "quiet-ivory-u001.0.3")
        let wrong = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: wrong) }
        try Data("{}".utf8).write(to: wrong)
        XCTAssertThrowsError(try QuietIvoryProvenance(themeURL: wrong, mappingURL: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")))
    }
}
