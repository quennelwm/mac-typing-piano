// Static UI design specimens only. No window, capture, input, audio or preferences.
import AppKit
import CoreText
let out=URL(fileURLWithPath:CommandLine.arguments[1])
func color(_ n:UInt32)->NSColor {NSColor(srgbRed:CGFloat(n>>16&255)/255,green:CGFloat(n>>8&255)/255,blue:CGFloat(n&255)/255,alpha:1)}
func box(_ c:CGContext,_ r:CGRect,_ hex:UInt32,_ radius:CGFloat=6){c.setFillColor(color(hex).cgColor);c.addPath(CGPath(roundedRect:r,cornerWidth:radius,cornerHeight:radius,transform:nil));c.fillPath()}
func text(_ c:CGContext,_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=13,_ hex:UInt32=0x252525,_ bold:Bool=false){let l=CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:[.font:NSFont.systemFont(ofSize:size,weight:bold ? .semibold:.regular),.foregroundColor:color(hex)]));c.saveGState();c.translateBy(x:x,y:y);c.scaleBy(x:1,y:-1);c.textPosition = .zero;CTLineDraw(l,c);c.restoreGState()}
func button(_ c:CGContext,_ s:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ primary:Bool=false){box(c,CGRect(x:x,y:y,width:w,height:30),primary ? 0x007AFF:0xFFFFFF);text(c,s,x+12,y+20,13,primary ? 0xFFFFFF:0x252525)}
for state in ["swap","restore"] {
 let restore=state=="restore",scale=2,w=560,h=440
 let c=CGContext(data:nil,width:w*scale,height:h*scale,bitsPerComponent:8,bytesPerRow:w*scale*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 c.scaleBy(x:2,y:2);c.translateBy(x:0,y:440);c.scaleBy(x:1,y:-1)
 box(c,CGRect(x:0,y:0,width:560,height:440),0xF4F4F4,10)
 text(c,"自定义键位",24,36,18,0x252525,true);text(c,"U-028 · 静态设计示意",390,34,11,0x777777)
 text(c,restore ? "当前使用：自定义键位":"当前使用：新表默认",24,66,13,0x555555)
 text(c,restore ? "草稿：恢复新表默认 · 2 项待保存":"草稿：2 项待保存",24,91,13,0x9C5A16,true)
 text(c,"实体键",24,128);box(c,CGRect(x:132,y:108,width:400,height:32),0xFFFFFF)
 text(c,"G",144,129);text(c,restore ? "草稿 C4":"草稿 F3",213,129,12,0x777777);text(c,"⌄",510,128)
 text(c,"目标音高",24,172);box(c,CGRect(x:132,y:152,width:400,height:32),0xFFFFFF)
 text(c,restore ? "C4 · MIDI 60 · 已是此音高":"F3 · MIDI 53",144,173);text(c,"⌄",510,172)
 text(c,"保存后变更",24,214,13,0x252525,true)
 text(c,restore ? "恢复为新表默认，保存前当前配置保持不变。":"本次交换：G C4→F3；A F3→C4（仅草稿）。",24,237,12,0x666666)
 box(c,CGRect(x:24,y:250,width:512,height:116),0xFFFFFF)
 text(c,"实体键",40,273,12,0x777777);text(c,"当前生效",205,273,12,0x777777);text(c,"保存后",388,273,12,0x777777)
 box(c,CGRect(x:36,y:282,width:488,height:1),0xEEEEEE,0)
 text(c,"G",40,307);text(c,restore ? "F3":"C4",205,307);text(c,"→",310,307,13,0x777777);text(c,restore ? "C4":"F3",388,307,13,0x252525,true)
 text(c,"A",40,343);text(c,restore ? "C4":"F3",205,343);text(c,"→",310,343,13,0x777777);text(c,restore ? "F3":"C4",388,343,13,0x252525,true)
 box(c,CGRect(x:0,y:372,width:560,height:1),0xDDDDDD,0)
 button(c,"恢复新表默认",24,391,128);button(c,"取消",380,391,64);button(c,"保存",460,391,76,true)
 let rep=NSBitmapImageRep(cgImage:c.makeImage()!);try rep.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("previews/\(state).png"))
}
print("Two 560x440pt @2x design specimens rendered.")
