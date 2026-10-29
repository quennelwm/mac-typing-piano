import Foundation
public struct KeyMapping: Codable {
    public struct Key: Codable {
        public struct Label: Codable { public let main: String; public let side: String? }
        public let physicalKeyID: String
        public let physicalRow: Int
        public let positionInRow: Int
        public let sdkConstantCandidate: String
        public let eventSemantics: String
        public let midiNote: Int
        public let pianoKeyColor: String
        public let displayLabel: String
        public let labelParts: Label
        public let accessibleName: String
        public let velocity: Int
    }
    public let schemaVersion: String
    public let mappingVersion: String
    public let keys: [Key]
    public static func load(url: URL) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try value.validate()
        return value
    }
    public func validate() throws {
        guard schemaVersion == "1.0.0", !mappingVersion.isEmpty else { throw ProbeError.invalid("Unsupported mapping schema/version") }
        guard keys.count == 64, Set(keys.map(\.physicalKeyID)).count == 64,
              Set(keys.map(\.midiNote)) == Set(33...96) else { throw ProbeError.invalid("Mapping must be a 64-key MIDI 33–96 bijection") }
        let rows = (1...5).map { row in keys.filter { $0.physicalRow == row }.count }
        guard rows == [14, 14, 13, 12, 11] else { throw ProbeError.invalid("Unexpected physical rows") }
        let black = Set([1, 3, 6, 8, 10])
        for key in keys {
            let color = black.contains(key.midiNote % 12) ? "black" : "white"
            guard key.pianoKeyColor == color, !key.displayLabel.isEmpty, !key.labelParts.main.isEmpty,
                  (1...127).contains(key.velocity) else { throw ProbeError.invalid("Invalid mapping key metadata") }
            if key.physicalKeyID.hasSuffix("Right") && ["modifier"].contains(key.eventSemantics) {
                guard key.labelParts.side == "R" else { throw ProbeError.invalid("Missing right-side label") }
            }
        }
    }
    public func key(_ id: String) -> Key? { keys.first { $0.physicalKeyID == id } }
}
public enum ProbeError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
