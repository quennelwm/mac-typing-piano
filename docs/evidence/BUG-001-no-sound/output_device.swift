import CoreAudio
import Foundation
var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var device: AudioDeviceID = 0
var size = UInt32(MemoryLayout<AudioDeviceID>.size)
let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &device)
var result: [String: Any] = ["defaultDeviceStatus": status, "defaultDeviceID": device, "readOnly": true]
if status == noErr {
    var name: CFString = "" as CFString
    a = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    size = UInt32(MemoryLayout<CFString>.size)
    if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &name) == noErr { result["deviceName"] = name as String }
    var channels: [[String: Any]] = []
    for ch: UInt32 in [0,1,2] {
        var row: [String: Any] = ["element": ch]
        a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: ch)
        var scalar: Float32 = 0; size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &scalar) == noErr { row["volumeScalar"] = scalar }
        a.mSelector = kAudioDevicePropertyMute
        var muted: UInt32 = 0; size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &muted) == noErr { row["muted"] = muted != 0 }
        channels.append(row)
    }
    result["outputControls"] = channels
}
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys])
print(String(decoding:data,as:UTF8.self))
