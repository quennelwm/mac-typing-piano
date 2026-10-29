import XCTest
@testable import PianoCore

final class PreferencesMigrationTests: XCTestCase {
    func testLegacyIsCopiedOnceAndOriginalRemainsUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old.json"), new = root.appendingPathComponent("support/preferences.json")
        var legacy = AppPreferences(); legacy.setVolume(0.84); legacy.showKeyLabels = false; try legacy.save(to: old)
        let original = try Data(contentsOf: old)
        let migrated = try AppPreferences.loadMigrating(to: new, legacyURL: old)
        XCTAssertEqual(migrated.volume, 0.84); XCTAssertFalse(migrated.showKeyLabels)
        XCTAssertEqual(try Data(contentsOf: old), original)
        legacy.setVolume(0.1); try legacy.save(to: old)
        XCTAssertEqual(try AppPreferences.loadMigrating(to: new, legacyURL: old).volume, 0.84)
    }
    func testExistingPreferencesWinEvenIfLegacyIsInvalid() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old.json"), new = root.appendingPathComponent("new.json")
        var saved = AppPreferences(); saved.setVolume(0.25); try saved.save(to: new)
        try Data("invalid".utf8).write(to: old)
        XCTAssertEqual(try AppPreferences.loadMigrating(to: new, legacyURL: old).volume, 0.25)
    }
    func testMissingLegacyCreatesDefaultsAndDoesNotImportLater() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old.json"), new = root.appendingPathComponent("new.json")
        XCTAssertEqual(try AppPreferences.loadMigrating(to: new, legacyURL: old).volume, 0.5)
        var legacy = AppPreferences(); legacy.setVolume(0.9); try legacy.save(to: old)
        XCTAssertEqual(try AppPreferences.loadMigrating(to: new, legacyURL: old).volume, 0.5)
    }
    func testInvalidExistingDataIsNotSilentlyReplaced() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let new = root.appendingPathComponent("new.json"), old = root.appendingPathComponent("old.json")
        let invalid = Data("invalid".utf8); try invalid.write(to: new); try AppPreferences().save(to: old)
        XCTAssertThrowsError(try AppPreferences.loadMigrating(to: new, legacyURL: old))
        XCTAssertEqual(try Data(contentsOf: new), invalid)
    }
}
