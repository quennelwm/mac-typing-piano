import XCTest
@testable import PianoCore

final class CustomKeymapTests: XCTestCase {
    private func base() throws -> KeyMapping {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
    }
    private func file() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("custom-keymap.json")
    }
    func testImmediateDraftSwapsAccumulateAcrossKeySelectionWithoutChangingBaseline() throws {
        let base = try base(), initial = CustomKeymap(defaultMapping: base)
        var draft = try KeymapDraft(configuration: initial, selectedKey: "keyG")
        try draft.selectPitch(53)
        XCTAssertEqual(draft.candidate.notes["keyG"], 53); XCTAssertEqual(draft.candidate.notes["keyA"], 60)
        try draft.selectKey("keyS"); try draft.selectPitch(60)
        XCTAssertEqual(draft.candidate.notes["keyS"], 60); XCTAssertEqual(draft.candidate.notes["keyA"], 55)
        XCTAssertEqual(draft.baseline, initial); XCTAssertTrue(draft.dirty)
        try draft.candidate.validate(against: base)
        draft.restoreDefault(base); XCTAssertFalse(draft.dirty); XCTAssertEqual(draft.candidate, initial)
    }
    func testSaveRelaunchRestoreAndNoFileDefault() throws {
        let base = try base(), path = file(), store = CustomKeymapStore(url: path, defaultMapping: base)
        XCTAssertNil(store.load().warning); XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
        var custom = CustomKeymap(defaultMapping: base); try custom.swap(key: "keyG", to: 53)
        try store.save(custom)
        XCTAssertEqual(CustomKeymapStore(url: path, defaultMapping: base).load().configuration, custom)
        let mapping = try custom.mapping(from: base)
        XCTAssertEqual(mapping.key("keyG")?.midiNote, 53); XCTAssertEqual(mapping.key("keyG")?.labelParts.main, "G")
        try store.save(CustomKeymap(defaultMapping: base))
        XCTAssertEqual(store.load().configuration, CustomKeymap(defaultMapping: base))
    }
    func testMalformedConfigurationsPreserveOriginalBytesAndFallback() throws {
        let base = try base(), path = file(), store = CustomKeymapStore(url: path, defaultMapping: base)
        let valid = CustomKeymap(defaultMapping: base)
        var duplicate = valid; duplicate.notes["keyG"] = 53
        var outside = valid; outside.notes["keyG"] = 200
        var unknown = valid; unknown.notes["escape"] = unknown.notes.removeValue(forKey: "keyG")
        var version = valid; version.schemaVersion = 0
        var incompatible = valid; incompatible.baseMappingVersion = "old"
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        for data in try [Data("{broken".utf8)] + [duplicate, outside, unknown, version, incompatible].map({ try JSONEncoder().encode($0) }) {
            try data.write(to: path)
            let result = store.load(); XCTAssertNotNil(result.warning); XCTAssertEqual(result.configuration, valid)
            XCTAssertEqual(try Data(contentsOf: path), data)
        }
        let damaged = try Data(contentsOf: path)
        try store.save(valid)
        let backups = try FileManager.default.contentsOfDirectory(at: path.deletingLastPathComponent(), includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("custom-keymap-invalid-") }
        XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), damaged)
    }
    func testInvalidSaveCannotReplaceExistingFileAndWriteErrorIsReported() throws {
        let base = try base(), path = file(), store = CustomKeymapStore(url: path, defaultMapping: base)
        var valid = CustomKeymap(defaultMapping: base); try store.save(valid)
        let bytes = try Data(contentsOf: path)
        valid.notes["keyG"] = 900
        XCTAssertThrowsError(try store.save(valid)); XCTAssertEqual(try Data(contentsOf: path), bytes)
        try FileManager.default.removeItem(at: path); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.save(CustomKeymap(defaultMapping: base)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
    }
}
