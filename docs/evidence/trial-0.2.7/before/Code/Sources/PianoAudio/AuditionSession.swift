import Foundation
import CryptoKit

public struct AudioSource {
    public let id: String
    public let title: String
    public let url: URL
    public let coveredMIDI: Set<Int>
    public let maximumMixerGain: Float
    public let samplerGainDB: Float
    public init(id: String, title: String, url: URL, coveredMIDI: Set<Int>, maximumMixerGain: Float = 0.16, samplerGainDB: Float = 0) {
        self.id = id; self.title = title; self.url = url; self.coveredMIDI = coveredMIDI
        self.maximumMixerGain = maximumMixerGain; self.samplerGainDB = samplerGainDB
    }
    /// Candidate coverage is loaded once from the delivered index, never in a key callback.
    public static func available(root: URL, bundled: Bool) throws -> [AudioSource] {
        struct Index: Decodable {
            struct Trial: Decodable { let id: String; let bankFile: String; let coverageMIDI: [Int] }
            let trials: [Trial]
        }
        let candidateRoot = root.appendingPathComponent(bundled ? "AudioCandidates" : "Design/Audio/probes/A-001B")
        let index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: candidateRoot.appendingPathComponent("trial-index.json")))
        var sources = [try fullTrial(root: root, bundled: bundled), AudioSource(id: "synthetic", title: "合成测试音（64键全覆盖）", url: root.appendingPathComponent(bundled ? "placeholder-original.sf2" : "Code/Assets/placeholder-original.sf2"), coveredMIDI: Set(33...96))]
        for (id, title, count) in [("vcsl-kawai", "Kawai候选", 10), ("vcsl-steinway-b", "Steinway B候选", 11)] {
            guard let trial = index.trials.first(where: { $0.id == id }), trial.bankFile == "\(id)/trial.sf2",
                  Set(trial.coverageMIDI).count == count, trial.coverageMIDI.allSatisfy({ (33...96).contains($0) }) else {
                throw SamplerAudioError.invalidBankContent
            }
            sources.append(AudioSource(id: id, title: "\(title)（仅\(count)/64键有声）", url: candidateRoot.appendingPathComponent(trial.bankFile), coveredMIDI: Set(trial.coverageMIDI)))
        }
        return sources
    }
    private static func fullTrial(root: URL, bundled: Bool) throws -> AudioSource {
        struct Index: Decodable {
            struct Trial: Decodable {
                let id: String; let bankFile: String; let byteSize: Int; let sha256: String
                let coverageMIDI: [Int]; let program: Int; let bankMSB: Int; let bankLSB: Int
            }
            let trialVersion: String; let trials: [Trial]
        }
        let directory = root.appendingPathComponent(bundled ? "AudioTrial" : "Design/Audio/trial/A-002T")
        let index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: directory.appendingPathComponent("trial-index.json")))
        guard index.trialVersion == "a002t-steinway-mono.0.1", index.trials.count == 1,
              let trial = index.trials.first, trial.id == "vcsl-steinway-b",
              trial.bankFile == "vcsl-steinway-b/trial.sf2", trial.coverageMIDI.count == 64,
              Set(trial.coverageMIDI) == Set(33...96), trial.program == 0, trial.bankMSB == 121, trial.bankLSB == 0,
              trial.sha256 == "2819d43506550ece98d80455388c913850acfcdd7ae45ee61908311a52997b5a" else {
            throw SamplerAudioError.invalidBankContent
        }
        let url = directory.appendingPathComponent(trial.bankFile)
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count == trial.byteSize,
              SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == trial.sha256 else {
            throw SamplerAudioError.invalidBankContent
        }
        return AudioSource(id: "steinway-trial-64", title: "Steinway B 试用钢琴（64键）", url: url,
                           coveredMIDI: Set(33...96), maximumMixerGain: 0.75, samplerGainDB: 12)
    }

}
public protocol AuditionEngine: AnyObject {
    func prepare(bankURL: URL, offline: Bool) throws
    func configureGain(maximum: Float, samplerDB: Float)
    func shutdown()
    func setGain(_ gain: Float)
    func noteOn(midi: UInt8, velocity: UInt8)
    func noteOff(midi: UInt8)
    func panic()
    func runtimeDiagnostics() -> [String: Any]
    func isCurrentEngineNotification(_ object: AnyObject?) -> Bool
}
public extension AuditionEngine {
    func configureGain(maximum: Float, samplerDB: Float) {}
    func runtimeDiagnostics() -> [String: Any] { ["diagnosticsSupport": "unsupported"] }
    func isCurrentEngineNotification(_ object: AnyObject?) -> Bool { false }
}
extension SamplerAudio: AuditionEngine {}
/// Starts silent; selection never enables audio. No substitution for missing candidate notes.
public final class AuditionSession {
    public private(set) var source: AudioSource
    public private(set) var enabled = false
    private let engine: AuditionEngine
    private var volume: Double = 0.5
    public init(engine: AuditionEngine = SamplerAudio(), source: AudioSource) { self.engine = engine; self.source = source }
    public func select(_ source: AudioSource, clearState: () -> Void) {
        clearState(); disable(); self.source = source
    }
    public func enable(offline: Bool = false) throws {
        disable()
        do {
            engine.configureGain(maximum: source.maximumMixerGain, samplerDB: source.samplerGainDB)
            engine.setGain(Float(volume) * source.maximumMixerGain)
            try engine.prepare(bankURL: source.url, offline: offline); enabled = true
        }
        catch { engine.shutdown(); enabled = false; throw error }
    }
    public func disable() { engine.shutdown(); enabled = false }
    public func setGain(_ value: Float) { engine.setGain(value) }
    public func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        engine.setGain(Float(volume) * source.maximumMixerGain)
    }
    public func noteOn(midi: UInt8, velocity: UInt8) {
        guard enabled, source.coveredMIDI.contains(Int(midi)) else { return }
        engine.noteOn(midi: midi, velocity: velocity)
    }
    public func noteOff(midi: UInt8) { if enabled { engine.noteOff(midi: midi) } }
    public func panic() { engine.panic() }
    public func isCurrentEngineNotification(_ object: AnyObject?) -> Bool { engine.isCurrentEngineNotification(object) }
    public func runtimeDiagnostics() -> [String: Any] {
        var result = engine.runtimeDiagnostics()
        result["selectedSource"] = source.id; result["selectedSourceTitle"] = source.title
        result["sessionEnabled"] = enabled; result["appVolume"] = volume
        result["configuredMaximumMixerGain"] = source.maximumMixerGain
        result["configuredSamplerGainDB"] = source.samplerGainDB
        return result
    }
}
