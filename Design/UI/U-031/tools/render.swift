// U-027 design renderer, derived from frozen U-001 native vector functions only. No input capture, window, audio or external dependency.
import AppKit
import CoreText
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let ui = root.appendingPathComponent("Design/UI/U-031")
let qaCache=URL(fileURLWithPath:ProcessInfo.processInfo.environment["TYPING_PIANO_UI_QA_CACHE"] ?? (NSHomeDirectory()+"/Library/Caches/local.typingpiano.ui/U-031"))
try FileManager.default.createDirectory(at:qaCache.appendingPathComponent("qa"),withIntermediateDirectories:true)
try FileManager.default.createDirectory(at:qaCache.appendingPathComponent("previews"),withIntermediateDirectories:true)
let retainedBodyPreviews:Set<String>=["previews/piano-1496-h50-rest@1x.png","previews/piano-1496-h100-rest@1x.png","previews/piano-1496-h180-rest@1x.png","previews/piano-1264-h50-rest@1x.png","previews/piano-1904-h180-rest@1x.png"]
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
let labelColors = ["white": "#969FA9", "black": "#414B55"]
var heightScale:CGFloat=1
var reduceTransparency=false
let recipeURL=ui.appendingPathComponent("reference.json")
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:recipeURL)) as! [String:Any]
let material=config["material"] as! [String:Any]

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
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot - slot * 0.59 / 2, y: 4*heightScale, width: slot * 0.59, height: 64*heightScale)
        } else {
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot + 0.35, y: 4*heightScale, width: slot - 0.7, height: 100*heightScale)
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
func alphaColor(_ hex:String,_ alpha:CGFloat)->CGColor {color(hex).copy(alpha:alpha)!}
func surface(_ ctx:CGContext,_ r:CGRect,black:Bool,pressed:Bool) {
 let m=material[black ? "black":"white"] as! [String:Any]
 let radius=m["radiusPt"] as! CGFloat
 let stops=m[pressed ? "pressedGradient":"restGradient"] as! [[String:Any]]
 let fallback=m["opaqueFallback"] as! [String]
 let colors=reduceTransparency ? fallback.map{color($0)} : stops.map{alphaColor($0["hex"] as! String,$0["alpha"] as! CGFloat)}
 ctx.saveGState();ctx.addPath(rounded(r,radius:radius));ctx.clip()
 let grad=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:colors as CFArray,locations:[0,1])!
 ctx.drawLinearGradient(grad,start:CGPoint(x:r.midX,y:r.minY),end:CGPoint(x:r.midX,y:r.maxY),options:[])
 // Highlights are perimeter strokes, never a full-face opaque pass.
 let edge=m["edgeLight"] as! [String:Any]
 ctx.setStrokeColor(alphaColor(edge["hex"] as! String,edge["alpha"] as! CGFloat));ctx.setLineWidth(edge["widthPt"] as! CGFloat)
 ctx.move(to:CGPoint(x:r.minX+2,y:r.minY+0.5));ctx.addLine(to:CGPoint(x:r.maxX-2,y:r.minY+0.5));ctx.strokePath()
 ctx.setStrokeColor(alphaColor(edge["hex"] as! String,(edge["alpha"] as! CGFloat)*0.38));ctx.setLineWidth(0.5)
 ctx.move(to:CGPoint(x:r.minX+0.5,y:r.minY+2));ctx.addLine(to:CGPoint(x:r.minX+0.5,y:r.maxY-2));ctx.strokePath()
 let bottom=m["innerBottom"] as! [String:Any]
 ctx.setStrokeColor(alphaColor(bottom["hex"] as! String,bottom["alpha"] as! CGFloat));ctx.setLineWidth(bottom["widthPt"] as! CGFloat)
 ctx.move(to:CGPoint(x:r.minX+2,y:r.maxY-0.5));ctx.addLine(to:CGPoint(x:r.maxX-2,y:r.maxY-0.5));ctx.strokePath()
 ctx.restoreGState()
}
func drawPiano(_ ctx:CGContext,width:CGFloat,pressed:Set<String>,labels:Bool=true,keys:[Key]?=nil) {
 let keys=keys ?? geometry(width);let h=112*heightScale
 let base=material["base"] as! [String:Any]
 ctx.setFillColor(alphaColor(base["fillHex"] as! String,base["alpha"] as! CGFloat));ctx.addPath(rounded(CGRect(x:0,y:0,width:width,height:h),radius:4));ctx.fillPath()
 let blacks=keys.filter{$0.isBlack}.map{k in k.rect.offsetBy(dx:0,dy:pressed.contains(k.id) ? 1.5*heightScale:0)}
 for black in [false,true] {for key in keys where key.isBlack==black {
  let down=pressed.contains(key.id),dy:CGFloat=down ? (black ? 1.5:2)*heightScale:0
  ctx.saveGState()
  if !black { // White is absent beneath CURRENT black faces, including their displacement.
   let clip=CGMutablePath();clip.addRect(CGRect(x:-10,y:-10,width:width+20,height:h+20));for r in blacks {clip.addPath(rounded(r,radius:2.5))};ctx.addPath(clip);ctx.clip(using:.evenOdd)
  }
  ctx.translateBy(x:0,y:dy)
  if black {
   ctx.saveGState()
   let clip=CGMutablePath();clip.addRect(CGRect(x:-10,y:-10,width:width+20,height:h+20));clip.addPath(rounded(key.rect,radius:2.5));ctx.addPath(clip);ctx.clip(using:.evenOdd)
   ctx.setShadow(offset:CGSize(width:0,height:1),blur:1.5,color:alphaColor("#26364A",down ? 0.10:0.16))
   ctx.setFillColor(color("#26364A"));ctx.addPath(rounded(key.rect,radius:2.5));ctx.fillPath();ctx.restoreGState()
  }
  surface(ctx,key.rect,black:black,pressed:down)
  if labels {
   ctx.setAlpha(black ? 0.84:0.86)
   for l in key.labels {ctx.saveGState();ctx.translateBy(x:l.x,y:l.baseline);ctx.scaleBy(x:1,y:-1);ctx.textMatrix = .identity;ctx.textPosition = .zero;CTLineDraw(l.line,ctx);ctx.restoreGState()}
  }
  ctx.restoreGState()
 }}
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
    let cacheOnly=path.hasPrefix("qa/") || (path.hasPrefix("previews/piano-") && !retainedBodyPreviews.contains(path))
    try rep.representation(using:.png,properties:[:])!.write(to:(cacheOnly ? qaCache:ui).appendingPathComponent(path))
}
func writeJSON(_ value: Any, _ path: String) throws {
    try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to:ui.appendingPathComponent(path))
}

let noteLine=lineFor("♪",24,"#626C66")
let noteInk=CTLineGetBoundsWithOptions(noteLine,.useGlyphPathBounds)
let noteIDs:Set<String>=["fn","keyG","keyY","keyT"]
func drawNotes(_ c:CGContext,width:CGFloat,ms:CGFloat,reduced:Bool=false){
 let duration:CGFloat=reduced ? 200:950
 guard ms>=0 && ms<duration else{return}
 let e=1-pow(1-ms/duration,3),rise:CGFloat=reduced ? 0:100*e,dx:CGFloat=reduced ? 0:8*e
 c.saveGState();c.setAlpha(reduced ? 1-ms/200:min(1,ms/80,(950-ms)/500))
 for k in geometry(width) where noteIDs.contains(k.id){c.saveGState();c.translateBy(x:k.rect.midX+dx-noteInk.midX,y:k.rect.minY-4-rise+noteInk.minY);c.scaleBy(x:1,y:-1);c.textMatrix = .identity;c.textPosition = .zero;c.setShadow(offset:.zero,blur:1.25,color:CGColor(gray:1,alpha:0.9));CTLineDraw(noteLine,c);c.restoreGState()};c.restoreGState()
}
func background(_ c:CGContext,width:CGFloat,height:CGFloat,mode:String){
 fill(c,CGRect(x:0,y:0,width:width,height:height),mode=="dark" ? "#18212E":"#F4F5F7")
 if mode=="color" {
  let colors=["#A27688","#7FA2B8","#A8AD7E","#A27688","#7FA2B8","#A8AD7E"]
  for (i,col) in colors.enumerated(){fill(c,CGRect(x:CGFloat(i)*width/6,y:0,width:width/6+1,height:height),col)}
  c.setFillColor(CGColor(gray:1,alpha:0.15));c.fill(CGRect(x:0,y:height*0.30,width:width,height:height*0.18))
 }
}
var layouts:[[String:Any]]=[],labelChecks:[[String:Any]]=[],envelopes:[[String:Any]]=[]
for percent in [50,100,180] {
 heightScale=CGFloat(percent)/100
 for w in widths {
  let keys=geometry(w),body=112*heightScale
  layouts.append(["widthPt":w,"heightPercent":percent,"bodyHeightPt":body,"canvasHeightPt":body+144,"keys":keys.map(\.json)])
  for k in keys {
   let b=k.labels.reduce(CGRect.null){$0.union($1.bounds)}
   labelChecks.append(["widthPt":w,"heightPercent":percent,"physicalKeyID":k.id,"insideOwnFace":k.rect.insetBy(dx:0.5,dy:0.5).contains(b),"missingGlyphs":k.labels.reduce(0){$0+$1.missing},"labelOverlap":k.labels.count>1 && k.labels[0].bounds.intersects(k.labels[1].bounds)])
   for reduced in [false,true] {
    let rise:CGFloat=reduced ? 0:100,dx:CGFloat=reduced ? 0:8
    let box=CGRect(x:k.rect.midX-noteInk.width/2-4,y:k.rect.minY-4-rise-noteInk.height-4,width:noteInk.width+8+dx,height:noteInk.height+8+rise)
    envelopes.append(["widthPt":w,"heightPercent":percent,"midi":k.midi,"reduced":reduced,"boundsBodyPt":[box.minX,box.minY,box.width,box.height],"insideCanvas":CGRect(x:0,y:-144,width:w,height:body+144).contains(box),"marginsPt":[box.minX,w-box.maxX,144+box.minY,body-box.maxY]])
   }
  }
  for state in ["rest","multi"] {
   try png("previews/piano-\(Int(w))-h\(percent)-\(state)@1x.png",width:Int(w),height:Int(ceil(body)),scale:1){drawPiano($0,width:w,pressed:scenarios[state]!)}
  }
  for wd in [false,true] {for bd in [false,true] {
   let held=Set(keys.filter{$0.isBlack ? bd:wd}.map(\.id))
   try png("qa/surface-\(Int(w))-h\(percent)-\(wd ? 1:0)-\(bd ? 1:0).png",width:Int(w),height:Int(ceil(body)),scale:1){drawPiano($0,width:w,pressed:held,labels:false)}
  }}
 }
}
let badLabels=labelChecks.filter{!($0["insideOwnFace"] as! Bool) || ($0["missingGlyphs"] as! Int)>0 || ($0["labelOverlap"] as! Bool)}
try writeJSON(["layouts":layouts,"mappingSource":"U-027/mapping.preview.json unchanged","coordinateSpace":"body-local top-left y-down pt; height-scale applied only to geometry/travel, ink measured at fixed font sizes","scenarios":scenarios.mapValues{$0.sorted()}],"qa/layouts.json")
try writeJSON(["status":badLabels.isEmpty ? "pass":"fail","checks":labelChecks,"failed":badLabels],"qa/labels.json")
try writeJSON(["status":envelopes.allSatisfy{$0["insideCanvas"] as! Bool} ? "pass":"fail","glyph":"♪","fontSizePt":24,"inkBoundsPt":[noteInk.minX,noteInk.minY,noteInk.width,noteInk.height],"proof":"Rise/drift are monotone: envelope of t=0 and t=950 limit contains full trajectory; reduced mode stationary.4pt conservative halo pad.","records":envelopes],"qa/note-lifetime.json")
heightScale=1
for mode in ["light","dark","color"] {
 try png("previews/background-\(mode).png",width:1496,height:112,scale:1){c in background(c,width:1496,height:112,mode:mode);drawPiano(c,width:1496,pressed:[])}
}
for reduced in [false,true] {for t:CGFloat in reduced ? [0,100,200] : [0,475,949,950] {
 try png("previews/notes-\(reduced ? "reduced":"normal")-\(Int(t))ms.png",width:1496,height:256,scale:1){c in c.translateBy(x:0,y:144);drawPiano(c,width:1496,pressed:[]);drawNotes(c,width:1496,ms:t,reduced:reduced)}
}}
reduceTransparency=true
try png("previews/reduced-transparency.png",width:1496,height:112,scale:1){c in background(c,width:1496,height:112,mode:"color");drawPiano(c,width:1496,pressed:[])}
try png("qa/reduced-transparency-alpha.png",width:1496,height:112,scale:1){drawPiano($0,width:1496,pressed:[],labels:false)}
reduceTransparency=false
try png("previews/overview.png",width:1544,height:790,scale:1){c in
 fill(c,CGRect(x:0,y:0,width:1544,height:790),"#ECEFF3")
 text(c,"U-031 · 轻透明水晶琴键",x:24,baseline:40,size:24,bold:true)
 text(c,"白键浅灰字 / 黑键深灰字 · 模拟背景，非桌面截图 · 程序化alpha，不是原生Liquid Glass",x:24,baseline:70,size:13)
 for (i,p) in [50,100,180].enumerated(){
  heightScale=CGFloat(p)/100
  let y:CGFloat=[115,280,510][i],m=["light","dark","color"][i]
  text(c,"\(p)% · 主体 \(112*heightScale)pt · \(m) 模拟背景",x:24,baseline:y,size:15,bold:true)
  c.saveGState();c.translateBy(x:24,y:y+20);background(c,width:1496,height:112*heightScale+24,mode:m);c.translateBy(x:0,y:12);drawPiano(c,width:1496,pressed:scenarios["multi"]!);c.restoreGState()
 }
}
for p in [50,180] {
 heightScale=CGFloat(p)/100
 try png("previews/edge-detail-h\(p)@2x.png",width:330,height:Int(ceil(112*heightScale))+16,scale:2){c in background(c,width:330,height:112*heightScale+16,mode:"color");c.translateBy(x:0,y:8);drawPiano(c,width:1264,pressed:scenarios["multi"]!)}
}
print("U-031:9 layouts,18 transparent keyboard previews,3 backgrounds,7 note frames,2 edge details; \(labelChecks.count) labels, \(envelopes.count) full-life bounds. Failed labels:\(badLabels.count)")
if !badLabels.isEmpty || !envelopes.allSatisfy({$0["insideCanvas"] as! Bool}){exit(1)}
