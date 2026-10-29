// U-027 design renderer, derived from frozen U-001 native vector functions only. No input capture, window, audio or external dependency.
import AppKit
import CoreText
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let ui = root.appendingPathComponent("Design/UI/U-027")
let mappingURL = root.appendingPathComponent("Design/UI/U-027/mapping.preview.json")
let mapping = try JSONSerialization.jsonObject(with: Data(contentsOf: mappingURL)) as! [String: Any]
let mappedKeys = (mapping["keys"] as! [[String: Any]]).sorted { ($0["midiNote"] as! Int) < ($1["midiNote"] as! Int) }
let blackPC: Set<Int> = [1, 3, 6, 8, 10]
let scenarios: [String: Set<String>] = ["rest": [], "single": ["keyA"], "multi": ["commandLeft", "commandRight", "optionLeft", "optionRight", "shiftLeft", "shiftRight", "keyA", "keyS", "keyD", "space", "digit1", "digit8", "arrowRight"]]
let widths: [CGFloat] = [1264, 1496, 1904]

func color(_ hex: String) -> CGColor {
    let h = hex.replacingOccurrences(of: "#", with: "")
    let n = UInt32(h, radix: 16)!
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [CGFloat((n >> 16) & 255)/255, CGFloat((n >> 8) & 255)/255, CGFloat(n & 255)/255, 1])!
}
let palette: [String: [String]] = ["white.rest": ["#FEFDFB", "#EEEDE9"], "white.pressed": ["#E7E5DF", "#D8D6D1"], "black.rest": ["#424346", "#242528"], "black.pressed": ["#303134", "#1B1C1F"]]
let labelColors = ["white": "#595959", "black": "#CDCDCD"]

struct Label {
    let text: String
    let size: CGFloat
    let x: CGFloat
    let baseline: CGFloat
    let bounds: CGRect
    let line: CTLine
    let fonts: [String]
    let missing: Int
    var json: [String: Any] { ["text": text, "fontSizePt": size, "x": x, "baselineY": baseline, "inkBoundsPt": [bounds.minX, bounds.minY, bounds.width, bounds.height], "resolvedFonts": fonts, "missingGlyphs": missing] }
}
func lineFor(_ text: String, _ size: CGFloat, _ hex: String) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: NSColor(cgColor: color(hex))!]))
}
func label(_ text: String, size: CGFloat, color: String, x: CGFloat, bottom: CGFloat) -> Label {
    let line = lineFor(text, size, color)
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let baseline = bottom + ink.minY
    var fonts: [String] = []
    var missing = 0
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let font = attrs[kCTFontAttributeName] as! CTFont
        fonts.append(CTFontCopyPostScriptName(font) as String)
        var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        missing += glyphs.filter { $0 == 0 }.count
    }
    return Label(text: text, size: size, x: x, baseline: baseline, bounds: CGRect(x: x + ink.minX, y: baseline - ink.maxY, width: ink.width, height: ink.height), line: line, fonts: fonts, missing: missing)
}
struct Key {
    let data: [String: Any]
    let rect: CGRect
    let isBlack: Bool
    let labels: [Label]
    var id: String { data["physicalKeyID"] as! String }
    var midi: Int { data["midiNote"] as! Int }
    var json: [String: Any] { ["physicalKeyID": id, "midiNote": midi, "color": isBlack ? "black" : "white", "accessibleName": data["accessibleName"]!, "displayLabel": data["displayLabel"]!, "labelParts": data["labelParts"]!, "rectPt": [rect.minX, rect.minY, rect.width, rect.height], "labels": labels.map(\.json)] }
}
func geometry(_ width: CGFloat) -> [Key] {
    let slot = (width - 4) / 38
    var whiteIndex = 0
    return mappedKeys.map { data in
        let midi = data["midiNote"] as! Int
        let black = blackPC.contains(midi % 12)
        let r: CGRect
        if black {
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot - slot * 0.59 / 2, y: 4, width: slot * 0.59, height: 64)
        } else {
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot + 0.35, y: 4, width: slot - 0.7, height: 100)
            whiteIndex += 1
        }
        let parts = data["labelParts"] as! [String: Any]
        let main = parts["main"] as! String
        let side = parts["side"] as? String
        let size: CGFloat = black ? 9.5 : 10
        let ink = CTLineGetBoundsWithOptions(lineFor(main, size, labelColors[black ? "black" : "white"]!), .useGlyphPathBounds)
        let mainLabel = label(main, size: size, color: labelColors[black ? "black" : "white"]!, x: r.midX - ink.midX - (side == nil ? 0 : 0.6), bottom: r.maxY - (black ? 3 : 4))
        var labels = [mainLabel]
        if let side {
            let sideInk = CTLineGetBoundsWithOptions(lineFor(side, 6.5, labelColors[black ? "black" : "white"]!), .useGlyphPathBounds)
            let sideLabel = label(side, size: 6.5, color: labelColors[black ? "black" : "white"]!, x: r.maxX - 1.1 - sideInk.maxX, bottom: mainLabel.bounds.minY + (black ? -0.6 : 2))
            labels.append(sideLabel)
        }
        return Key(data: data, rect: r, isBlack: black, labels: labels)
    }
}
func rounded(_ r: CGRect, radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil) }
func fill(_ ctx: CGContext, _ r: CGRect, _ hex: String, _ radius: CGFloat = 0) {
    ctx.setFillColor(color(hex)); ctx.addPath(rounded(r, radius: radius)); ctx.fillPath()
}
func surface(_ ctx: CGContext, _ r: CGRect, black: Bool, pressed: Bool) {
    let colors = palette["\(black ? "black" : "white").\(pressed ? "pressed" : "rest")"]!
    let radius: CGFloat = black ? 1.2 : 1
    ctx.saveGState()
    ctx.addPath(rounded(r, radius: radius)); ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(color) as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x:r.midX,y:r.minY), end: CGPoint(x:r.midX,y:r.maxY), options: [])
    fill(ctx, CGRect(x:r.minX,y:r.maxY-(black ? 2 : 2.5),width:r.width,height:black ? 2 : 2.5), black ? (pressed ? "#141518" : "#17181B") : (pressed ? "#C3C1BC" : "#D5D3CE"))
    ctx.setStrokeColor(color(black ? "#58595C" : "#FFFFFF")); ctx.setLineWidth(0.5)
    ctx.move(to: CGPoint(x:r.minX+1,y:r.minY+0.5)); ctx.addLine(to: CGPoint(x:r.maxX-1,y:r.minY+0.5)); ctx.strokePath()
    ctx.restoreGState()
}
func drawPiano(_ ctx: CGContext, width: CGFloat, pressed: Set<String>, labels: Bool = true, keys: [Key]? = nil) {
    fill(ctx, CGRect(x:0,y:0,width:width,height:112), "#353638", 3)
    fill(ctx, CGRect(x:1,y:2,width:width-2,height:106), "#71716E", 2)
    let keys = keys ?? geometry(width)
    for black in [false, true] {
        for key in keys where key.isBlack == black {
            ctx.saveGState()
            let down = pressed.contains(key.id)
            ctx.translateBy(x:0,y:down ? (black ? 1.5 : 2) : 0)
            if black {
                ctx.saveGState()
                ctx.setShadow(offset:CGSize(width:0,height:down ? 0.5 : 1), blur:down ? 0.5 : 1.5, color:CGColor(gray:0,alpha:down ? 0.18 : 0.3))
                fill(ctx,key.rect,"#242528",1.2)
                ctx.restoreGState()
            }
            surface(ctx, key.rect, black:black, pressed:down)
            if labels {
                for l in key.labels {
                    ctx.saveGState(); ctx.translateBy(x:l.x,y:l.baseline); ctx.scaleBy(x:1,y:-1)
                    ctx.textMatrix = .identity; ctx.textPosition = .zero
                    CTLineDraw(l.line,ctx); ctx.restoreGState()
                }
            }
            ctx.restoreGState()
        }
    }
}
func text(_ ctx: CGContext, _ text: String, x: CGFloat, baseline: CGFloat, size: CGFloat, color hex: String = "#303235", bold: Bool = false) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:[.font:NSFont.systemFont(ofSize:size,weight:bold ? .semibold : .regular),.foregroundColor:NSColor(cgColor:color(hex))!]))
    ctx.saveGState();ctx.translateBy(x:x,y:baseline);ctx.scaleBy(x:1,y:-1);ctx.textMatrix = .identity;ctx.textPosition = .zero;CTLineDraw(line,ctx);ctx.restoreGState()
}
func png(_ path: String, width: Int, height: Int, scale: Int, draw: (CGContext)->Void) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data:nil,width:width*scale,height:height*scale,bitsPerComponent:8,bytesPerRow:width*scale*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x:CGFloat(scale),y:CGFloat(scale));ctx.translateBy(x:0,y:CGFloat(height));ctx.scaleBy(x:1,y:-1)
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage:ctx.makeImage()!)
    try rep.representation(using:.png,properties:[:])!.write(to:ui.appendingPathComponent(path))
}
func writeJSON(_ value: Any, _ path: String) throws {
    try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to:ui.appendingPathComponent(path))
}

let floatingLine = lineFor("♪",24,"#626C66")
let floatingInk = CTLineGetBoundsWithOptions(floatingLine,.useGlyphPathBounds)
let ids:Set<String> = ["fn","space","keyA","keyG","keyY","keyT"]
func drawFloating(_ ctx:CGContext,width:CGFloat,time:CGFloat,reduced:Bool=false,all:Bool=false) {
 let duration:CGFloat = reduced ? 200:900
 guard time>=0 && time<duration else{return}
 let e=1-pow(1-time/duration,3),rise:CGFloat = reduced ? 0:48*e,dx:CGFloat = reduced ? 0:4*e
 let alpha:CGFloat = reduced ? 1-time/200:min(1,time/80,(900-time)/500)
 for k in geometry(width) where all || ids.contains(k.id) {
  ctx.saveGState();ctx.setAlpha(alpha);ctx.translateBy(x:k.rect.midX+dx-floatingInk.midX,y:k.rect.minY-4-rise+floatingInk.minY);ctx.scaleBy(x:1,y:-1)
  ctx.textMatrix = .identity;ctx.textPosition = .zero
  ctx.setShadow(offset:.zero,blur:1.25,color:CGColor(gray:1,alpha:0.9));CTLineDraw(floatingLine,ctx);ctx.restoreGState()
 }
}
var layouts:[[String:Any]]=[],checks:[[String:Any]]=[],bounds:[[String:Any]]=[]
for w in widths {
 let keys=geometry(w)
 layouts.append(["screenWidthPt":w+16,"widthPt":w,"heightPt":112,"headroomPt":96,"whiteSlotPt":(w-4)/38,"keys":keys.map(\.json)])
 for k in keys {
  let ink=k.labels.reduce(CGRect.null){$0.union($1.bounds)}
  checks.append(["widthPt":w,"physicalKeyID":k.id,"insideOwnKey":k.rect.insetBy(dx:0.5,dy:0.5).contains(ink),"missingGlyphs":k.labels.reduce(0){$0+$1.missing},"labelOverlap":k.labels.count>1 && k.labels[0].bounds.intersects(k.labels[1].bounds)])
  for reduced in [false,true] {
   for t:CGFloat in reduced ? [0,100,199] : [0,80,100,450,899] {
    let e=1-pow(1-t/900,3),rise:CGFloat = reduced ? 0:48*e,dx:CGFloat = reduced ? 0:4*e
    let b=CGRect(x:k.rect.midX+dx-floatingInk.width/2-4,y:k.rect.minY-4-rise-floatingInk.height-4,width:floatingInk.width+8,height:floatingInk.height+8)
    // The 4pt halo overlaps the transparent body top margin; all pixels must fit the full canvas.
    bounds.append(["widthPt":w,"midiNote":k.midi,"timeMs":t,"reduced":reduced,"boundsIncludingHaloPt":[b.minX,b.minY,b.width,b.height],"insideCanvas":CGRect(x:0,y:-96,width:w,height:208).contains(b)])
   }
  }
 }
 for state in ["rest","single","multi"] {
  for scale in [1,2] {for labels in [true,false] {
   let suffix=labels ? "":"-labels-off"
   try png("previews/piano-\(Int(w))-\(state)\(suffix)@\(scale)x.png",width:Int(w),height:112,scale:scale){drawPiano($0,width:w,pressed:scenarios[state]!,labels:labels)}
  }}
 }
 for wd in [false,true] {for bd in [false,true] {
  let held=Set(keys.filter{$0.isBlack ? bd:wd}.map(\.id))
  for scale in [1,2] {
   try png("qa/surface-\(Int(w))-\(wd ? 1:0)-\(bd ? 1:0)@\(scale)x.png",width:Int(w),height:112,scale:scale){drawPiano($0,width:w,pressed:held,labels:false)}
  }
 }}
 for reduced in [false,true] {
  for t:CGFloat in reduced ? [0,100,200] : [0,100,450,900] {
   for scale in [1,2] {
    try png("previews/floating-\(Int(w))-\(reduced ? "reduced":"normal")-\(Int(t))ms@\(scale)x.png",width:Int(w),height:208,scale:scale){ctx in
     ctx.translateBy(x:0,y:96);drawPiano(ctx,width:w,pressed:t<180 ? ids:[]);drawFloating(ctx,width:w,time:t,reduced:reduced)
    }
   }
  }
 }
}
try writeJSON(["mappingVersion":mapping["mappingVersion"]!,"layouts":layouts,"scenarios":scenarios.mapValues{$0.sorted()},"labelCoordinates":"rest local body coordinates; add white2/black1.5 y for held state"],"qa/layouts.json")
let failed=checks.filter{!($0["insideOwnKey"] as! Bool) || ($0["labelOverlap"] as! Bool) || ($0["missingGlyphs"] as! Int)>0}
try writeJSON(["status":failed.isEmpty ? "pass":"fail","renderer":"native AppKit/CoreText, offscreen sRGB","checks":checks,"failed":failed],"qa/native-labels.json")
let note=label("♪",size:24,color:"#626C66",x:0,bottom:0)
try writeJSON(["status":bounds.allSatisfy{$0["insideCanvas"] as! Bool} ? "pass":"fail","glyphInkBoundsPt":[floatingInk.minX,floatingInk.minY,floatingInk.width,floatingInk.height],"resolvedFonts":note.fonts,"missingGlyphs":note.missing,"boundsPaddingPt":4,"headroomPt":96,"checks":bounds],"qa/floating-bounds.json")
try png("previews/overview@1x.png",width:1960,height:830,scale:1){ctx in
 fill(ctx,CGRect(x:0,y:0,width:1960,height:830),"#F3F2EE")
 text(ctx,"U-027 · 112pt 琴键主体 / 24pt 漂浮音符 / 用户 v0.2 映射",x:28,baseline:40,size:24,bold:true)
 text(ctx,"原生离屏设计预览；各行保持1pt=1px，界面查看器可能缩放。白键100pt、黑键64pt；透明留白96pt。",x:28,baseline:69,size:13)
 for (i,w) in widths.enumerated() {
  let y:CGFloat=100+CGFloat(i)*240
  text(ctx,"屏幕 \(Int(w+16))pt → 钢琴 \(Int(w))pt · 左右各8pt · 100ms音符",x:28,baseline:y,size:15,bold:true)
  ctx.saveGState();ctx.translateBy(x:(1960-w)/2,y:y+110);drawPiano(ctx,width:w,pressed:ids);drawFloating(ctx,width:w,time:100);ctx.restoreGState()
 }
}
// Unlooped demonstration frames; discrete key release at180ms is not a 45/100ms key-motion test.
for t in stride(from:0,through:900,by:20) {
 try png("qa/frames/normal-\(t).png",width:1496,height:208,scale:1){ctx in
  fill(ctx,CGRect(x:0,y:0,width:1496,height:208),"#E7EAE3");ctx.translateBy(x:0,y:96)
  drawPiano(ctx,width:1496,pressed:t<180 ? ids:[]);drawFloating(ctx,width:1496,time:CGFloat(t))
 }
}
print("U-027: 36 body previews, 42 floating keyframes; \(checks.count) label checks, \(bounds.count) glyph bounds; failed labels \(failed.count).")
if !failed.isEmpty || !bounds.allSatisfy({$0["insideCanvas"] as! Bool}) || note.missing>0 {exit(1)}
