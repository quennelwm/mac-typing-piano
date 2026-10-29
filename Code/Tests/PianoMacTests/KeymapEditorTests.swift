import XCTest
import AppKit
import PianoCore
@testable import PianoMac

final class KeymapEditorTests: XCTestCase {
    private func base() throws -> KeyMapping {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
    }
    func testNativeSelectorsDraftCancelAndRestoreDoNotWriteUntilSave() throws {
        let base = try base(); var current = CustomKeymap(defaultMapping: base); var writes = 0
        let editor = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, baseline in
            XCTAssertEqual(current, baseline); current = next; writes += 1
        }
        editor.pitchPopup.selectItem(at: 53 - 33); editor.pitchChanged()
        XCTAssertEqual(editor.draft.candidate.notes["keyG"], 53); XCTAssertEqual(writes, 0)
        editor.keyPopup.selectItem(at: base.keys.firstIndex { $0.physicalKeyID == "keyS" }!); editor.keyChanged()
        XCTAssertEqual(editor.draft.candidate.notes["keyG"], 53)
        editor.pitchPopup.selectItem(at: 60 - 33); editor.pitchChanged()
        editor.saveDraft(); XCTAssertEqual(writes, 1); XCTAssertEqual(current.notes["keyS"], 60)
        let restore = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in current = next; writes += 1 }
        restore.restoreDefault(); XCTAssertTrue(restore.draft.dirty); XCTAssertEqual(writes, 1)
        restore.cancel(); XCTAssertEqual(current.notes["keyS"], 60); XCTAssertEqual(writes, 1)
        let savedRestore = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in current = next; writes += 1 }
        savedRestore.restoreDefault(); savedRestore.saveDraft()
        XCTAssertEqual(current, CustomKeymap(defaultMapping: base)); XCTAssertEqual(writes, 2)
    }
    func testSaveFailureRetainsRetryableDraftAndConcurrentChangeRequiresReload() throws {
        let base = try base(); var current = CustomKeymap(defaultMapping: base); var fail = true; var writes = 0
        let editor = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in
            if fail { throw ProbeError.invalid("test write error") }
            current = next; writes += 1
        }
        editor.pitchPopup.selectItem(at: 53 - 33); editor.pitchChanged(); editor.saveDraft()
        XCTAssertEqual(writes, 0); XCTAssertTrue(editor.draft.dirty); XCTAssertTrue(editor.saveButton.isEnabled)
        fail = false; editor.saveDraft(); XCTAssertEqual(writes, 1)
        let second = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in current = next; writes += 1 }
        second.restoreDefault()
        try current.swap(key: "keyS", to: 61)
        second.saveDraft(); XCTAssertEqual(writes, 1); XCTAssertFalse(second.saveButton.isEnabled)
        second.reloadDraft(); XCTAssertFalse(second.draft.dirty); XCTAssertEqual(second.draft.baseline, current)
    }
    func testMenuOnlyExposesCustomEditorAndShowsFallbackReason() throws {
        _ = NSApplication.shared
        let menu = ProbeMenu(volume: 0.5, installStatusItem: false)
        XCTAssertFalse(menu.menu.items.contains { $0.title.contains("预设") || $0.title.contains("旧") })
        let item = try XCTUnwrap(menu.menu.items.first { $0.title == "自定义键位…" })
        var calls = 0; menu.onCustomize = { calls += 1 }
        NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item); XCTAssertEqual(calls, 1)
        menu.updateKeymap(custom: false, warning: "损坏文件已保留")
        XCTAssertTrue(menu.menu.items.contains { $0.title == "键位读取失败" })
    }
}
