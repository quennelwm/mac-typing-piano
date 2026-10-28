import Foundation
/// Only app-owned volume and label visibility; contains no input history or system settings.
public struct AppPreferences: Codable {
    public private(set) var volume: Double = 0.5
    public var showKeyLabels = true
    public var outputGain: Float { Float(volume * 0.16) }
    public init() {}
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
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
