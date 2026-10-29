import Foundation

public struct CustomKeymap: Codable, Equatable {
    public var schemaVersion: Int = 1
    public var baseMappingVersion: String
    public var notes: [String: Int]
    public init(defaultMapping: KeyMapping) {
        baseMappingVersion = defaultMapping.mappingVersion
        notes = Dictionary(uniqueKeysWithValues: defaultMapping.keys.map { ($0.physicalKeyID, $0.midiNote) })
    }
    public func validate(against base: KeyMapping) throws {
        guard schemaVersion == 1, baseMappingVersion == base.mappingVersion,
              notes.count == 64, Set(notes.keys) == Set(base.keys.map(\.physicalKeyID)),
              Set(notes.values) == Set(33...96) else {
            throw ProbeError.invalid("自定义键位无效：必须是当前版本的64个实体键和MIDI33–96的一一对应")
        }
    }
    @discardableResult public mutating func swap(key: String, to midi: Int) throws -> String {
        guard let old = notes[key], let other = notes.first(where: { $0.value == midi })?.key else {
            throw ProbeError.invalid("未知实体键或音高超出A1–C7")
        }
        notes[key] = midi; notes[other] = old
        return other
    }
    public func mapping(from base: KeyMapping) throws -> KeyMapping {
        try validate(against: base)
        let unchanged = self == CustomKeymap(defaultMapping: base)
        let keys = base.keys.map { key -> KeyMapping.Key in
            let midi = notes[key.physicalKeyID]!
            return KeyMapping.Key(physicalKeyID: key.physicalKeyID, physicalRow: key.physicalRow,
                positionInRow: key.positionInRow, sdkConstantCandidate: key.sdkConstantCandidate,
                eventSemantics: key.eventSemantics, midiNote: midi,
                pianoKeyColor: [1,3,6,8,10].contains(midi % 12) ? "black" : "white",
                displayLabel: key.displayLabel, labelParts: key.labelParts, accessibleName: key.accessibleName, velocity: key.velocity)
        }
        let result = KeyMapping(schemaVersion: base.schemaVersion, mappingVersion: unchanged ? base.mappingVersion : "custom.1", keys: keys)
        try result.validate(); return result
    }
    public static func noteName(_ midi: Int) -> String {
        guard (33...96).contains(midi) else { return "未知" }
        return ["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"][midi % 12] + String(midi / 12 - 1)
    }
}

public final class CustomKeymapStore {
    public struct Loaded {
        public let configuration: CustomKeymap
        public let warning: String?
    }
    public let url: URL
    private let base: KeyMapping
    public init(url: URL, defaultMapping: KeyMapping) { self.url = url; base = defaultMapping }
    private func read() throws -> CustomKeymap {
        let data = try Data(contentsOf: url)
        guard data.count <= 32_768 else { throw ProbeError.invalid("自定义配置过大") }
        let value = try JSONDecoder().decode(CustomKeymap.self, from: data)
        try value.validate(against: base)
        return value
    }
    public func load() -> Loaded {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Loaded(configuration: CustomKeymap(defaultMapping: base), warning: nil)
        }
        do { return Loaded(configuration: try read(), warning: nil) }
        catch { return Loaded(configuration: CustomKeymap(defaultMapping: base), warning: "自定义键位读取失败，已使用新默认；原文件保留。\(error.localizedDescription)") }
    }
    public func save(_ configuration: CustomKeymap) throws {
        try configuration.validate(against: base)
        let data = try JSONEncoder().encode(configuration)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Explicit Save may repair a damaged file; retain its original bytes before replacing it.
        if FileManager.default.fileExists(atPath: url.path), (try? read()) == nil,
           let original = try? Data(contentsOf: url) {
            let backup = url.deletingLastPathComponent().appendingPathComponent("custom-keymap-invalid-\(UUID().uuidString).json")
            try original.write(to: backup, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}

public struct KeymapDraft {
    public let baseline: CustomKeymap
    public private(set) var working: CustomKeymap
    public private(set) var selectedKey: String
    public var targetMIDI: Int { working.notes[selectedKey]! }
    public init(configuration: CustomKeymap, selectedKey: String) throws {
        guard configuration.notes[selectedKey] != nil else { throw ProbeError.invalid("未知实体键") }
        baseline = configuration; working = configuration; self.selectedKey = selectedKey
    }
    public var candidate: CustomKeymap { working }
    public var dirty: Bool { working != baseline }
    public mutating func selectKey(_ id: String) throws {
        guard working.notes[id] != nil else { throw ProbeError.invalid("未知实体键") }
        selectedKey = id
    }
    public mutating func selectPitch(_ midi: Int) throws { try working.swap(key: selectedKey, to: midi) }
    public mutating func restoreDefault(_ mapping: KeyMapping) { working = CustomKeymap(defaultMapping: mapping) }
}
