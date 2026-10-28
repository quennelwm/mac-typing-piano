import XCTest
@testable import PianoCore
final class MappingTests: XCTestCase {
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
