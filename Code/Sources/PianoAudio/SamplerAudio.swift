import AVFoundation
import Foundation

public enum SamplerAudioError: Error, LocalizedError, Equatable {
    case unsupportedBankExtension
    case invalidBankContent
    case notPrepared
    case notOffline
    case invalidRenderDuration
    case renderFailed
    case renderStalled

    public var errorDescription: String? {
        switch self {
        case .unsupportedBankExtension: return "The C-001 probe requires a local .sf2 sound bank."
        case .invalidBankContent: return "The file is not a structurally valid RIFF sfbk sound bank."
        case .notPrepared: return "Prepare the sampler before rendering audio."
        case .notOffline: return "Offline rendering requires prepare(offline: true)."
        case .invalidRenderDuration: return "Render duration must be finite and between 0 and 60 seconds."
        case .renderFailed: return "The audio engine could not render the requested frames."
        case .renderStalled: return "The audio engine made no progress while rendering."
        }
    }
}

/// Minimal C-001 sampler adapter. Call every method from the same serial context.
///
/// `prepare` is a non-realtime operation that validates and loads the bank once.
/// All note calls are memory-only. The coordinator, not this class, owns pressID
/// matching. A new same-MIDI strike first releases the preceding note; Apple
/// sampler voice allocation and overlap remain implementation-dependent.
public final class SamplerAudio {
    /// The offline probe is mono at 48 kHz. Real device output may be resampled.
    public let sampleRate: Double = 48_000
    public private(set) var gain: Float = 0.08
    /// Changes this engine's mixer only. Does not open devices, resume voices, or change the system volume.
    public func setGain(_ value: Float) {
        guard value.isFinite else { return }
        gain = min(0.16, max(0, value))
        engine?.mainMixerNode.outputVolume = gain
        // Mixer parameter changes may ramp across a render quantum. Exact zero
        // clears audio tails and suppresses new audio strikes until volume rises;
        // coordinator input/visual state is untouched and held notes are not replayed.
        if gain == 0 { panic() }
    }
    public var isPrepared: Bool { engine != nil }
    public private(set) var isOffline = false

    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private let maximumFrames: AVAudioFrameCount = 4096

    public init() {}

    /// This probe loads program 0 / melodic MSB 121 / LSB 0 only. Future approved
    /// banks must pass their verified preset parameters through a reviewed API.
    /// `offline: true` enables manual mode before mixer or I/O-node access.
    public func prepare(bankURL: URL, offline: Bool) throws {
        shutdown()
        try Self.validateBank(bankURL)
        let nextEngine = AVAudioEngine()
        let nextSampler = AVAudioUnitSampler()
        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        do {
            // Enabling manual mode first avoids incidental device configuration
            // from accessing the main mixer. No input node or tap is used.
            if offline {
                try nextEngine.enableManualRenderingMode(.offline, format: mono,
                                                         maximumFrameCount: maximumFrames)
            }
            nextEngine.attach(nextSampler)
            nextEngine.connect(nextSampler, to: nextEngine.mainMixerNode, format: stereo)
            nextEngine.mainMixerNode.outputVolume = gain
            try nextSampler.loadSoundBankInstrument(at: bankURL, program: 0,
                                                     bankMSB: 121, bankLSB: 0)
            nextSampler.sendController(64, withValue: 0, onChannel: 0) // sustain off
            nextSampler.sendController(91, withValue: 0, onChannel: 0) // reverb send off
            nextSampler.sendController(93, withValue: 0, onChannel: 0) // chorus send off
            nextEngine.prepare()
            try nextEngine.start()
            engine = nextEngine
            sampler = nextSampler
            isOffline = offline
        } catch {
            nextEngine.stop()
            nextEngine.reset()
            throw error
        }
    }

    public func noteOn(midi: UInt8, velocity: UInt8) {
        guard gain > 0, let sampler, engine?.isRunning == true, (33...96).contains(midi), velocity > 0 else { return }
        sampler.stopNote(midi, onChannel: 0)
        sampler.startNote(midi, withVelocity: min(velocity, 127), onChannel: 0)
    }

    public func noteOff(midi: UInt8) {
        guard (33...96).contains(midi) else { return }
        sampler?.stopNote(midi, onChannel: 0)
    }

    /// Silences held notes and release/effect tails while keeping the prepared
    /// engine usable. Manual rendering's timeline restarts at zero after reset.
    /// No bank reload or file access occurs here.
    public func panic() {
        guard let engine, let sampler else { return }
        sampler.sendController(64, withValue: 0, onChannel: 0)
        sampler.sendController(120, withValue: 0, onChannel: 0) // all sound off
        sampler.sendController(123, withValue: 0, onChannel: 0) // all notes off
        engine.reset()
    }

    public func shutdown() {
        panic()
        engine?.stop()
        engine = nil
        sampler = nil
        isOffline = false
    }

    /// Returns mono sample frames. Only manual/offline mode is accepted; this
    /// method never switches mode or starts hardware playback.
    public func render(seconds: Double) throws -> [Float] {
        guard let engine, engine.isRunning else { throw SamplerAudioError.notPrepared }
        guard isOffline else { throw SamplerAudioError.notOffline }
        guard seconds.isFinite, (0...60).contains(seconds) else { throw SamplerAudioError.invalidRenderDuration }
        let frameCount = Int((seconds * sampleRate).rounded())
        guard frameCount > 0 else { return [] }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                           frameCapacity: maximumFrames) else {
            throw SamplerAudioError.renderFailed
        }
        var output: [Float] = []
        output.reserveCapacity(frameCount)
        var stalledAttempts = 0
        while output.count < frameCount {
            let count = AVAudioFrameCount(min(Int(maximumFrames), frameCount - output.count))
            let status = try engine.renderOffline(count, to: buffer)
            switch status {
            case .success, .cannotDoInCurrentContext:
                let rendered = Int(buffer.frameLength)
                if rendered > 0, let channel = buffer.floatChannelData?[0] {
                    output.append(contentsOf: UnsafeBufferPointer(start: channel, count: rendered))
                    stalledAttempts = 0
                } else {
                    stalledAttempts += 1
                    guard stalledAttempts < 16 else { throw SamplerAudioError.renderStalled }
                }
            case .error, .insufficientDataFromInputNode:
                throw SamplerAudioError.renderFailed
            @unknown default:
                throw SamplerAudioError.renderFailed
            }
        }
        return output
    }

    private static func validateBank(_ url: URL) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "sf2" else {
            throw SamplerAudioError.unsupportedBankExtension
        }
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        func uint32(at offset: Int) -> Int {
            (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
        }
        func fourCC(at offset: Int) -> String {
            String(decoding: bytes[offset..<(offset + 4)], as: UTF8.self)
        }
        guard bytes.count >= 12, fourCC(at: 0) == "RIFF", fourCC(at: 8) == "sfbk",
              uint32(at: 4) == bytes.count - 8 else { throw SamplerAudioError.invalidBankContent }
        var offset = 12
        var lists: Set<String> = []
        while offset < bytes.count {
            guard offset + 8 <= bytes.count else { throw SamplerAudioError.invalidBankContent }
            let size = uint32(at: offset + 4)
            guard size <= bytes.count - offset - 8 else { throw SamplerAudioError.invalidBankContent }
            if fourCC(at: offset) == "LIST" {
                guard size >= 4 else { throw SamplerAudioError.invalidBankContent }
                lists.insert(fourCC(at: offset + 8))
            }
            offset += 8 + size + size % 2
        }
        guard offset == bytes.count, ["INFO", "sdta", "pdta"].allSatisfy(lists.contains) else {
            throw SamplerAudioError.invalidBankContent
        }
        // The sampler validates the instrument/sample tables during load.
    }

    deinit { shutdown() }
}
