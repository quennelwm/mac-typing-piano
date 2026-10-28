import CoreAudio
import Foundation
var addr = AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDevices,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
var sz: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz)
var ids=[AudioDeviceID](repeating:0,count:Int(sz)/MemoryLayout<AudioDeviceID>.size)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz, &ids)
var rows:[[String:Any]]=[]
for id in ids {
 addr=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyStreams,mScope:kAudioDevicePropertyScopeOutput,mElement:0)
 var count: UInt32=0
 guard AudioObjectGetPropertyDataSize(id,&addr,0,nil,&count)==noErr,count>0 else {continue}
 var name: CFString="" as CFString;sz=UInt32(MemoryLayout<CFString>.size)
 addr=AudioObjectPropertyAddress(mSelector:kAudioObjectPropertyName,mScope:kAudioObjectPropertyScopeGlobal,mElement:0)
 AudioObjectGetPropertyData(id,&addr,0,nil,&sz,&name)
 addr.mSelector=kAudioDevicePropertyTransportType
 var transport:UInt32=0;sz=4;AudioObjectGetPropertyData(id,&addr,0,nil,&sz,&transport)
 let chars=(0..<4).reversed().map{UInt8((transport >> ($0*8)) & 0xff)}
 rows.append(["id":id,"name":name as String,"transport":String(bytes:chars,encoding:.ascii) ?? "unknown"])
}
print(String(decoding:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
