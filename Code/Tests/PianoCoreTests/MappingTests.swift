import XCTest
@testable import PianoCore
final class MappingTests: XCTestCase {
    func testPlayableMappingPreservesPhysicalContractAndCoreTwentyNotes() throws {
        let old = try fixtureMapping()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let new = try KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.playable.v0.2.json"))
        try new.validate()
        XCTAssertEqual(new.keys.filter { $0.pianoKeyColor == "white" }.count, 38)
        for key in old.keys {
            let other = try XCTUnwrap(new.key(key.physicalKeyID))
            XCTAssertEqual(other.sdkConstantCandidate, key.sdkConstantCandidate)
            XCTAssertEqual(other.eventSemantics, key.eventSemantics)
            XCTAssertEqual(other.labelParts.main, key.labelParts.main)
        }
        let white = ["keyA", "keyS", "keyD", "keyF", "keyG", "keyH", "keyJ", "keyK", "keyL", "semicolon", "quote", "return"]
        XCTAssertEqual(white.compactMap { new.key($0)?.midiNote }, [53,55,57,59,60,62,64,65,67,69,71,72])
        let black = ["keyW","keyE","keyR","keyY","keyU","keyO","keyP","bracketLeft"]
        XCTAssertEqual(black.compactMap { new.key($0)?.midiNote }, [54,56,58,61,63,66,68,70])
    }
    func testRejectsUnknownSchemaAndDuplicateNotes() throws {
        let mapping = try fixtureMapping()
        let data = try JSONEncoder().encode(mapping)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = "99"
        var invalid = try JSONDecoder().decode(KeyMapping.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try invalid.validate())
        object["schemaVersion"] = "1.0.0"
        var keys = object["keys"] as! [[String: Any]]
        keys[1]["midiNote"] = keys[0]["midiNote"]
        object["keys"] = keys
        invalid = try JSONDecoder().decode(KeyMapping.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try invalid.validate())
    }
}
