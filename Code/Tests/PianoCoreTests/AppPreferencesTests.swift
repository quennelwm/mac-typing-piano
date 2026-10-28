import XCTest
@testable import PianoCore
final class AppPreferencesTests: XCTestCase {
    func testVolumeClampsPersistsAndDoesNotControlSoundSwitch() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/preference-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        var p = AppPreferences()
        XCTAssertEqual(p.volume, 0.5)
        p.setVolume(2); XCTAssertEqual(p.volume, 1)
        p.setVolume(-1); XCTAssertEqual(p.volume, 0)
        p.setVolume(.nan); XCTAssertEqual(p.volume, 0)
        p.setVolume(0.75); p.showKeyLabels = false
        try p.save(to: url)
        let saved = try AppPreferences.load(from: url)
        XCTAssertEqual(saved.volume, 0.75)
        XCTAssertEqual(saved.outputGain, 0.12, accuracy: 0.00001)
        XCTAssertFalse(saved.showKeyLabels)
        var c = NoteCoordinator(mapping: try fixtureMapping())
        _ = c.setSoundEnabled(false)
        p.setVolume(0); p.setVolume(1)
        XCTAssertFalse(c.soundEnabled)
        _ = c.consume(.init("keyA", .down))
        XCTAssertNotNil(c.lastStrike)
    }
}
