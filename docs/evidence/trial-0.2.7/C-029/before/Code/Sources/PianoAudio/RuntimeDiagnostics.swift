import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

/// Main/serial control context only. Never accepts a retired or unrelated engine notification.
public final class EngineNotificationIdentity {
    private weak var current: AnyObject?
    public init() {}
    public func set(_ object: AnyObject?) { current = object }
    public func matches(_ object: AnyObject?) -> Bool {
        guard let current, let object else { return false }
        return current === object
    }
}

/// Only aggregate statistics from this engine's main mixer, never the microphone or other apps.
/// The tap does bounded work and uses try-lock: it never waits for a UI snapshot.
final class OutputMeter {
    private let lock = NSLock()
    private var callbacks = 0
    private var frames: UInt64 = 0
    private var inspectedSamples: UInt64 = 0
    private var peak: Float = 0
    private var lastPeak: Float = 0
    private var lastCallback: Double?
    func consume(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData, lock.try() else { return }
        defer { lock.unlock() }
        var value: Float = 0
        let channelCount = min(Int(buffer.format.channelCount), 8)
        let count = min(Int(buffer.frameLength), 8192)
        let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
        for channel in 0..<channelCount {
            let pointer = buffer.format.isInterleaved ? channels[0].advanced(by: channel) : channels[channel]
            for frame in 0..<count { value = max(value, abs(pointer[frame * stride])) }
        }
        callbacks += 1; frames += UInt64(buffer.frameLength)
        inspectedSamples += UInt64(count * channelCount)
        lastPeak = value; peak = max(peak, value)
        lastCallback = ProcessInfo.processInfo.systemUptime
    }
    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return ["outputTapCallbackCount": callbacks, "outputTapFrameCount": frames,
                "outputTapInspectedSamples": inspectedSamples, "outputTapPeak": peak,
                "outputTapLastBufferPeak": lastPeak,
                "outputTapLastCallbackUptime": lastCallback.map { $0 as Any } ?? NSNull(),
                "outputTapCallbackAgeSeconds": lastCallback.map { max(0, ProcessInfo.processInfo.systemUptime - $0) as Any } ?? NSNull(),
                "outputTapScope": "this-engine-main-mixer-only", "acousticProof": false,
                "meterLimits": "At most 8192 frames x 8 channels per callback; try-lock may skip a callback. No samples retained."]
    }
}

func currentOutputDevice(_ engine: AVAudioEngine?) -> [String: Any] {
    guard let engine, let unit = engine.outputNode.audioUnit else {
        return ["currentOutputDeviceID": NSNull(), "currentOutputDeviceName": NSNull(), "outputDeviceStatus": "unavailable-no-live-engine"]
    }
    var device = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, &size)
    guard status == noErr, device != 0 else {
        return ["currentOutputDeviceID": NSNull(), "currentOutputDeviceName": NSNull(), "outputDeviceStatus": "unknown", "outputDeviceOSStatus": status]
    }
    var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var name: CFString = "" as CFString
    size = UInt32(MemoryLayout<CFString>.size)
    let nameStatus = withUnsafeMutablePointer(to: &name) { pointer in
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
    }
    return ["currentOutputDeviceID": device, "currentOutputDeviceName": nameStatus == noErr ? name as String as Any : NSNull(),
            "outputDeviceStatus": "queried-engine-output-AudioUnit-current-device", "outputDeviceNameOSStatus": nameStatus]
}
