import XCTest
@testable import PianoCore

final class HeightPreferencesTests: XCTestCase {
    func testOldAndInvalidHeightJSONRetainOtherSettings() throws {
        for field in ["", ",\"heightScale\":\"bad\"", ",\"heightScale\":null"] {
            let p = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"volume\":0.8,\"showKeyLabels\":false\(field)}".utf8))
            XCTAssertEqual(p.heightScale, 1); XCTAssertEqual(p.volume, 0.8); XCTAssertFalse(p.showKeyLabels)
        }
        for (value, expected) in [(-4.0, 0.5), (4.0, 1.8), (1.35, 1.35)] {
            let p = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"volume\":0.8,\"showKeyLabels\":false,\"heightScale\":\(value)}".utf8))
            XCTAssertEqual(p.heightScale, expected)
        }
    }
    func testHeightRoundTripAndNonfiniteIgnored() throws {
        var p = AppPreferences(); p.setHeightScale(1.8); p.setHeightScale(.nan); p.setHeightScale(.infinity)
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(restored.heightScale, 1.8); XCTAssertEqual(restored.volume, 0.5)
    }
}
