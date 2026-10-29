import Foundation
/// App-owned presentation/audio preferences; no input history or system settings.
public enum PianoLayer: String, Codable { case top, bottom }
public struct AppPreferences: Codable {
    public var floatingNotesEnabled = true
    public var soundEnabled = true
    public var pianoLayer: PianoLayer = .top
    public private(set) var volume: Double = 0.5
    public var showKeyLabels = true
    public private(set) var heightScale: Double = 1
    public private(set) var transparency: Double = 0.15
    public var outputGain: Float { Float(volume * 0.16) }
    public init() {}
    private enum CodingKeys: String, CodingKey { case volume, showKeyLabels, heightScale, transparency, floatingNotesEnabled, soundEnabled, pianoLayer }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        floatingNotesEnabled = (try? values.decode(Bool.self, forKey: .floatingNotesEnabled)) ?? true
        soundEnabled = (try? values.decode(Bool.self, forKey: .soundEnabled)) ?? true
        pianoLayer = (try? values.decode(PianoLayer.self, forKey: .pianoLayer)) ?? .top
        setVolume((try? values.decode(Double.self, forKey: .volume)) ?? 0.5)
        showKeyLabels = (try? values.decode(Bool.self, forKey: .showKeyLabels)) ?? true
        setHeightScale((try? values.decode(Double.self, forKey: .heightScale)) ?? 1)
        setTransparency((try? values.decode(Double.self, forKey: .transparency)) ?? 0.15)
    }
    public mutating func setTransparency(_ value: Double) {
        guard value.isFinite else { return }
        transparency = (min(1, max(0, value)) * 100).rounded() / 100
    }
    public mutating func setHeightScale(_ value: Double) {
        guard value.isFinite else { return }
        heightScale = (PianoHeight.normalized(value) * 100).rounded() / 100
    }
    public mutating func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
    }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        var value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        value.setVolume(value.volume)
        return value
    }
    /// Existing destination wins; a successful first load also saves defaults to finish migration.
    /// The only legacy candidate is supplied by the current app, and is never edited/deleted.
    public static func loadMigrating(to url: URL, legacyURL: URL) throws -> Self {
        if FileManager.default.fileExists(atPath: url.path) { return try load(from: url) }
        let value = try load(from: legacyURL)
        try value.save(to: url)
        return value
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
