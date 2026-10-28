// U-001 design renderer only. No input capture, window, audio or external dependency.
import AppKit
import CoreText
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let ui = root.appendingPathComponent("Design/UI")
let mappingURL = root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json")
let mapping = try JSONSerialization.jsonObject(with: Data(contentsOf: mappingURL)) as! [String: Any]
let mappedKeys = (mapping["keys"] as! [[String: Any]]).sorted { ($0["midiNote"] as! Int) < ($1["midiNote"] as! Int) }
let blackPC: Set<Int> = [1, 3, 6, 8, 10]
let scenarios: [String: Set<String>] = ["rest": [], "single": ["keyA"], "multi": ["commandLeft", "commandRight", "optionLeft", "optionRight", "shiftLeft", "shiftRight", "keyA", "keyS", "keyD", "space", "digit1", "digit8", "arrowRight"]]
let widths: [CGFloat] = [900, 1000, 1100]

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
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot - slot * 0.59 / 2, y: 2, width: slot * 0.59, height: 32)
        } else {
            r = CGRect(x: 2 + CGFloat(whiteIndex) * slot + 0.35, y: 2, width: slot - 0.7, height: 50)
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
    fill(ctx, CGRect(x:0,y:0,width:width,height:56), "#353638", 3)
    fill(ctx, CGRect(x:1,y:1,width:width-2,height:53), "#71716E", 2)
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

var allLayouts: [[String:Any]] = []
var checks: [[String:Any]] = []
for w in widths {
    let keys = geometry(w)
    allLayouts.append(["widthPt":w,"heightPt":56,"whiteSlotPt":(w-4)/38,"keys":keys.map(\.json)])
    for key in keys {
        let labelBox = key.labels.reduce(CGRect.null) { $0.union($1.bounds) }
        let inside = key.rect.insetBy(dx:0.5,dy:0.5).contains(labelBox)
        let intersect = key.labels.count == 2 && key.labels[0].bounds.intersects(key.labels[1].bounds)
        checks.append(["widthPt":w,"physicalKeyID":key.id,"midiNote":key.midi,"insideOwnKey":inside,"labelOverlap":intersect,"missingGlyphs":key.labels.reduce(0){$0+$1.missing},"minimumHorizontalMarginPt":min(labelBox.minX-key.rect.minX,key.rect.maxX-labelBox.maxX),"mainBottomInsetPt":key.rect.maxY-key.labels[0].bounds.maxY,"labelBoundsPt":[labelBox.minX,labelBox.minY,labelBox.width,labelBox.height]])
    }
    for state in ["rest","single","multi"] {
        for s in [1,2] {
            try png("previews/piano-\(Int(w))-\(state)@\(s)x.png",width:Int(w),height:56,scale:s) { drawPiano($0,width:w,pressed:scenarios[state]!,keys:keys) }
        }
    }
    for state in ["rest", "single", "multi"] {
        for s in [1, 2] {
            try png("previews/piano-\(Int(w))-\(state)-labels-off@\(s)x.png",width:Int(w),height:56,scale:s) { drawPiano($0,width:w,pressed:scenarios[state]!,labels:false,keys:keys) }
        }
    }
    // Complete piano crops, drawn at 4x; includes every key, with overlap between crops.
    let region = w / 4
    for part in 0..<4 {
        for state in ["rest","multi"] {
            let start = max(0,CGFloat(part)*region-10)
            let end = min(w,CGFloat(part+1)*region+10)
            try png("previews/labels-\(Int(w))-\(state)-part\(part+1)@4x.png",width:Int(ceil(end-start)),height:56,scale:4) { ctx in
                ctx.translateBy(x:-start,y:0);drawPiano(ctx,width:w,pressed:scenarios[state]!,keys:keys)
            }
        }
    }
}
try writeJSON(["schemaVersion":"u001-preview.1","mappingVersion":mapping["mappingVersion"]!,"layouts":allLayouts,"scenarios":scenarios.mapValues { $0.sorted() }],"qa/layouts.json")
let failed = checks.filter { !($0["insideOwnKey"] as! Bool) || ($0["labelOverlap"] as! Bool) || ($0["missingGlyphs"] as! Int)>0 }
try writeJSON(["renderer":"native AppKit + CoreText; sRGB","date":"2026-10-28 Asia/Shanghai","status":failed.isEmpty ? "pass" : "fail","checks":checks,"failed":failed,"scope":"Native font and geometric evidence only. Not on-screen human legibility, capture or product integration."],"qa/native-labels.json")

// Neutral presentation background, not a desktop, not a runtime asset.
try png("previews/overview@2x.png",width:1200,height:1130,scale:2) { ctx in
    fill(ctx,CGRect(x:0,y:0,width:1200,height:1130),"#F3F2EE")
    text(ctx,"Typing Piano",x:48,baseline:62,size:28,bold:true)
    text(ctx,"U-001 · 原生 Mac 打字钢琴 / 视觉候选",x:48,baseline:91,size:13,color:"#686862")
    text(ctx,"64 键  ·  A1—C7  ·  标签默认显示，可关闭  ·  仅合成视觉预览",x:48,baseline:121,size:12,color:"#686862")
    var y: CGFloat = 163
    for w in widths {
        text(ctx,"\(Int(w)) × 56 pt\(w == 1000 ? "  / 推荐候选" : "")",x:48,baseline:y,size:17,bold:true)
        y += 22
        for state in ["rest","single","multi"] {
            let name = ["rest":"静止", "single":"单键 · A", "multi":"多键 · 含左右修饰键与数字"][state]!
            text(ctx,name,x:48,baseline:y+9,size:10,color:"#686862")
            ctx.saveGState();ctx.translateBy(x:(1200-w)/2,y:y+19);drawPiano(ctx,width:w,pressed:scenarios[state]!);ctx.restoreGState()
            y += 91
        }
        y += 21
    }
    text(ctx,"原生 CoreText 栅格输出 · 1x/2x 独立文件及全标签 4x 放大图见 previews/",x:48,baseline:1102,size:11,color:"#686862")
}
// Each label specimen is shown on its original-width key face at 4x magnification.
for state in ["rest","pressed"] {
    let w: CGFloat = 900
    let keys = geometry(w)
    try png("previews/all-labels-900-\(state)@2x.png",width:1200,height:840,scale:2) { ctx in
        fill(ctx,CGRect(x:0,y:0,width:1200,height:840),"#F3F2EE")
        text(ctx,"64 个标签 / 900pt 最窄候选 · \(state == "rest" ? "静止" : "全部按下")",x:32,baseline:42,size:23,bold:true)
        text(ctx,"黑键放大 4 倍，白键放大 2.4 倍；文字独立绘制。L/R 为 6.5pt 上角标。",x:32,baseline:69,size:12,color:"#686862")
        for (index,key) in keys.enumerated() {
            let x = CGFloat(index % 16)*73+18
            let y = CGFloat(index / 16)*183+94
            text(ctx,"\(key.midi) · \(key.data["displayLabel"]!)",x:x+3,baseline:y+13,size:10)
            let factor:CGFloat = key.isBlack ? 4 : 2.4
            // White keys use 2.4x to preserve the specimen grid; black keys use 4x.
            ctx.saveGState();ctx.translateBy(x:x+7,y:y+24);ctx.scaleBy(x:factor,y:factor)
            ctx.translateBy(x:-key.rect.minX,y:-key.rect.minY)
            surface(ctx,key.rect,black:key.isBlack,pressed:state == "pressed")
            for l in key.labels {
                ctx.saveGState();ctx.translateBy(x:l.x,y:l.baseline);ctx.scaleBy(x:1,y:-1);ctx.textMatrix = .identity;ctx.textPosition = .zero;CTLineDraw(l.line,ctx);ctx.restoreGState()
            }
            ctx.restoreGState()
        }
    }
}
print("Rendered 18 labeled + 18 labels-off size/state/scale PNGs, 24 full-label crops, 2 specimen sheets and overview; \(checks.count) native label checks; failures: \(failed.count).")
if !failed.isEmpty { exit(1) }

// CR-002: body stays 56pt, transparent effect headroom is 48pt.
let floatingLine = lineFor("♪", 12, "#626C66")
let floatingInk = CTLineGetBoundsWithOptions(floatingLine, .useGlyphPathBounds)
let floatIDs: [String: Set<String>] = ["single":["keyA"], "multi":["keyA","commandLeft","space","digit8","shiftRight"], "labels-off":["keyA","commandLeft","space","digit8","shiftRight"], "reduced":["keyA","commandLeft"]]
func drawFloating(_ ctx: CGContext, width: CGFloat, ids: Set<String>, time: CGFloat, reduced: Bool = false) {
    let duration: CGFloat = reduced ? 200 : 700
    guard time >= 0 && time < duration else { return }
    let fraction = time/duration
    let rise: CGFloat = reduced ? 0 : 24*(1-pow(1-fraction,3))
    let alpha: CGFloat = reduced ? 1-fraction : min(1,time/60,(700-time)/400)
    for k in geometry(width) where ids.contains(k.id) {
        let x = k.rect.midX - floatingInk.midX
        let baseline = k.rect.minY - 4 - rise + floatingInk.minY
        ctx.saveGState();ctx.setAlpha(alpha);ctx.translateBy(x:x,y:baseline);ctx.scaleBy(x:1,y:-1)
        ctx.textMatrix = .identity;ctx.textPosition = .zero
        // Thin light halo separates the charcoal glyph from dark desktop backgrounds.
        ctx.setShadow(offset:.zero,blur:1.25,color:CGColor(gray:1,alpha:0.9));CTLineDraw(floatingLine,ctx);ctx.restoreGState()
    }
}
var floatChecks:[[String:Any]] = []
for w in widths {
    for k in geometry(w) {
        for t:CGFloat in [0,100,350,699] {
            let rise = 24*(1-pow(1-t/700,3))
            let bottom = k.rect.minY - 4 - rise
            let bounds = CGRect(x:k.rect.midX-floatingInk.width/2-1.25,y:bottom-floatingInk.height-1.25,width:floatingInk.width+2.5,height:floatingInk.height+2.5)
            floatChecks.append(["widthPt":w,"midiNote":k.midi,"timeMs":t,"boundsIncludingHaloPt":[bounds.minX,bounds.minY,bounds.width,bounds.height],"insideHeadroom":CGRect(x:0,y:-48,width:w,height:48).contains(bounds)])
        }
    }
}
try writeJSON(["glyph":"♪","fontSizePt":12,"resolvedFonts":label("♪",size:12,color:"#626C66",x:0,bottom:0).fonts,"missingGlyphs":label("♪",size:12,color:"#626C66",x:0,bottom:0).missing,"glyphInkBoundsPt":[floatingInk.minX,floatingInk.minY,floatingInk.width,floatingInk.height],"effectHeadroomPt":48,"bodyHeightPt":56,"totalHeightPt":104,"checks":floatChecks,"status":floatChecks.allSatisfy{$0["insideHeadroom"] as! Bool} ? "pass":"fail"],"qa/floating-bounds.json")
for (name,ids) in floatIDs {
    let reduced = name == "reduced"
    let times: [CGFloat] = reduced ? [0,100,200,700] : [0,100,350,700]
    for t in times {
        for scale in [1,2] {
            try png("previews/floating-\(name)-\(Int(t))ms@\(scale)x.png",width:1000,height:104,scale:scale) { ctx in
                ctx.translateBy(x:0,y:48)
                drawPiano(ctx,width:1000,pressed:t<180 ? ids:[],labels:name != "labels-off")
                drawFloating(ctx,width:1000,ids:ids,time:t,reduced:reduced)
            }
        }
    }
}
try FileManager.default.createDirectory(at:ui.appendingPathComponent("qa/frames"),withIntermediateDirectories:true)
for (name,ids) in floatIDs {
    for t in stride(from:0,through:700,by:20) {
        try png("qa/frames/\(name)-\(t).png",width:1000,height:104,scale:2) { ctx in
            fill(ctx,CGRect(x:0,y:0,width:1000,height:104),"#E7EAE3") // GIF presentation only, not an asset.
            ctx.translateBy(x:0,y:48)
            drawPiano(ctx,width:1000,pressed:t<180 ? ids:[],labels:name != "labels-off")
            drawFloating(ctx,width:1000,ids:ids,time:CGFloat(t),reduced:name == "reduced")
        }
    }
}
try png("previews/floating-keyframes@2x.png",width:1120,height:650,scale:2) { ctx in
    fill(ctx,CGRect(x:0,y:0,width:1120,height:650),"#F3F2EE")
    text(ctx,"每次击发，一枚小音符",x:40,baseline:46,size:25,bold:true)
    text(ctx,"CR-002 · 700ms / 上升24pt / 48pt透明留白；琴键主体仍为56pt",x:40,baseline:73,size:12,color:"#686862")
    for (index,t) in [0,100,350,700].enumerated() {
        let y:CGFloat = 104+CGFloat(index)*133
        text(ctx,"\(t)ms\(t == 0 ? " · 淡入起点，透明度0" : (t == 700 ? " · 已回收" : ""))",x:40,baseline:y+12,size:12,bold:true)
        ctx.saveGState();ctx.translateBy(x:60,y:y+64)
        drawPiano(ctx,width:1000,pressed:t<180 ? floatIDs["multi"]!:[])
        drawFloating(ctx,width:1000,ids:floatIDs["multi"]!,time:CGFloat(t));ctx.restoreGState()
    }
}
// Native-font mockups, not an actual NSMenu/NSAlert or a system screenshot.
try png("previews/menu-and-warning@2x.png",width:1000,height:620,scale:2) { ctx in
    fill(ctx,CGRect(x:0,y:0,width:1000,height:620),"#F3F2EE")
    text(ctx,"日常入口，只需菜单栏",x:40,baseline:48,size:25,bold:true)
    text(ctx,"CR-001 · 设计示意；未更改系统 Dock。标签和 Dock 自动隐藏的候选默认均开启。",x:40,baseline:77,size:12,color:"#686862")
    fill(ctx,CGRect(x:40,y:108,width:310,height:30),"#DBE0D6",5)
    text(ctx,"菜单栏",x:52,baseline:128,size:11,color:"#626D5D")
    text(ctx,"♪",x:309,baseline:128,size:18)
    fill(ctx,CGRect(x:66,y:142,width:284,height:440),"#FAFAF7",8)
    text(ctx,"打字钢琴",x:86,baseline:165,size:11,color:"#70776A",bold:true)
    let entries = ["暂停全部", "—", "✓   声音", "VOLUME", "✓   显示钢琴", "✓   显示按键标签", "—", "✓   自动隐藏 Dock", "     钢琴宽度              1000pt  ›", "—", "帮助 / 关于", "退出打字钢琴"]
    var y:CGFloat = 192
    for entry in entries {
        if entry == "—" {fill(ctx,CGRect(x:77,y:y-5,width:262,height:1),"#D5D9CF");y+=14}
        else if entry == "VOLUME" {
            text(ctx,"音量",x:106,baseline:y,size:12);text(ctx,"50%",x:294,baseline:y,size:11,color:"#67735D")
            fill(ctx,CGRect(x:106,y:y+14,width:220,height:3),"#D6DCCF",1.5)
            fill(ctx,CGRect(x:106,y:y+14,width:110,height:3),"#6D8360",1.5)
            fill(ctx,CGRect(x:210,y:y+8,width:12,height:15),"#FFFFFF",6)
            y+=53
        }
        else {text(ctx,entry,x:86,baseline:y,size:13);y+=30}
    }
    fill(ctx,CGRect(x:414,y:186,width:526,height:270),"#FAFAF7",14)
    text(ctx,"关闭 Dock 自动隐藏？",x:571,baseline:230,size:17,bold:true)
    text(ctx,"关闭自动隐藏后，Dock 可能与底部钢琴重叠或遮挡。",x:456,baseline:276,size:13)
    text(ctx,"仍要关闭吗？",x:634,baseline:302,size:13)
    text(ctx,"视觉示意 · 不代表已检测到实际重叠",x:564,baseline:335,size:11,color:"#747B6D")
    fill(ctx,CGRect(x:458,y:370,width:208,height:36),"#DCE7D5",7)
    fill(ctx,CGRect(x:678,y:370,width:208,height:36),"#ECEEE7",7)
    text(ctx,"保持自动隐藏",x:518,baseline:393,size:13,bold:true)
    text(ctx,"仍然关闭",x:754,baseline:393,size:13)
    text(ctx,"默认 / 取消：保留原值",x:463,baseline:490,size:11,color:"#686862")
    text(ctx,"确认后交给代码层提交并读回；失败不能显示成功。",x:463,baseline:515,size:11,color:"#686862")
    text(ctx,"系统 Dock 自动隐藏与钢琴自身避让分别管理。",x:463,baseline:540,size:11,color:"#686862")
}
print("CR-001 menu mock and CR-002 keyframes/animation frames exported; floating headroom checks: \(floatChecks.count).")
// QA: every combination of white/black held state, without labels, for pixel-background sampling.
for w in widths {
    for whiteDown in [false,true] {
        for blackDown in [false,true] {
            let keys = geometry(w)
            let ids = Set(keys.filter { $0.isBlack ? blackDown : whiteDown }.map(\.id))
            for scale in [1,2] {
                try png("qa/surface-\(Int(w))-\(whiteDown ? 1:0)-\(blackDown ? 1:0)@\(scale)x.png",width:Int(w),height:56,scale:scale) { drawPiano($0,width:w,pressed:ids,labels:false,keys:keys) }
            }
        }
    }
}

// CR-003: single note status item, with template-alpha exports and light/dark specimens.
try FileManager.default.createDirectory(at:ui.appendingPathComponent("components/icons"),withIntermediateDirectories:true)
func drawStatusIcon(_ ctx: CGContext, size:CGFloat, hex:String) {
    let l = lineFor("♪",size,hex)
    let b = CTLineGetBoundsWithOptions(l,.useGlyphPathBounds)
    let scale=min((size-3)/b.width,(size-3)/b.height)
    ctx.saveGState();ctx.translateBy(x:size/2,y:size/2);ctx.scaleBy(x:scale,y:-scale)
    ctx.textMatrix = .identity;ctx.textPosition=CGPoint(x:-b.midX,y:-b.midY);CTLineDraw(l,ctx);ctx.restoreGState()
}
var iconChecks:[[String:Any]]=[]
for size in [16,18] {
    for scale in [1,2] {
        try png("components/icons/menu-note-\(size)@\(scale)x.png",width:size,height:size,scale:scale) { drawStatusIcon($0,size:CGFloat(size),hex:"#000000") }
        for appearance in ["light","dark"] {
            try png("previews/menu-note-\(size)-\(appearance)@\(scale)x.png",width:size+8,height:size+8,scale:scale) { ctx in
                fill(ctx,CGRect(x:0,y:0,width:size+8,height:size+8),appearance == "light" ? "#F3F2EE":"#24282A")
                ctx.translateBy(x:4,y:4);drawStatusIcon(ctx,size:CGFloat(size),hex:appearance == "light" ? "#252A25":"#F1F3EF")
            }
            iconChecks.append(["sizePt":size,"scale":scale,"appearance":appearance,"glyph":"♪","missingGlyphs":label("♪",size:CGFloat(size),color:"#000000",x:0,bottom:0).missing,"resolvedFonts":label("♪",size:CGFloat(size),color:"#000000",x:0,bottom:0).fonts,"nominalInkMarginPt":1.5])
        }
    }
}
try writeJSON(["status":iconChecks.allSatisfy{($0["missingGlyphs"] as! Int)==0} ? "pass":"fail","checks":iconChecks,"scope":"CoreText rendering and export only; actual macOS status-bar selection/accessibility/automatic tint not tested."],"qa/menu-icons.json")
func drawPNG(_ ctx:CGContext, path:String, rect:CGRect) {
    let source=CGImageSourceCreateWithURL(ui.appendingPathComponent(path) as CFURL,nil)!
    let img=CGImageSourceCreateImageAtIndex(source,0,nil)!
    ctx.saveGState();ctx.interpolationQuality = .none
    ctx.translateBy(x:rect.minX,y:rect.maxY);ctx.scaleBy(x:1,y:-1)
    ctx.draw(img,in:CGRect(x:0,y:0,width:rect.width,height:rect.height));ctx.restoreGState()
}
try png("previews/menu-icon-scales@2x.png",width:1040,height:440,scale:2) { ctx in
    fill(ctx,CGRect(x:0,y:0,width:1040,height:440),"#F3F2EE")
    text(ctx,"单音符 ♪ / 菜单栏模板图标",x:32,baseline:43,size:23,bold:true)
    text(ctx,"16 / 18pt × 1x / 2x × 浅 / 深色；每格左侧为逻辑大小，右侧放大4倍。图标不随击键闪烁。",x:32,baseline:71,size:12,color:"#686862")
    for (row,size) in [16,18].enumerated() {
        for (col,entry) in [(1,"light"),(2,"light"),(1,"dark"),(2,"dark")].enumerated() {
            let x=CGFloat(col)*250+20,y=CGFloat(row)*159+94,dark=entry.1 == "dark"
            fill(ctx,CGRect(x:x,y:y,width:240,height:145),dark ? "#24282A":"#E5E8E0",10)
            text(ctx,"\(size)pt · \(entry.0)x · \(dark ? "深色":"浅色")",x:x+14,baseline:y+26,size:11,color:dark ? "#D2D8CE":"#606B58")
            drawPNG(ctx,path:"previews/menu-note-\(size)-\(entry.1)@\(entry.0)x.png",rect:CGRect(x:x+31,y:y+66,width:CGFloat(size+8),height:CGFloat(size+8)))
            drawPNG(ctx,path:"previews/menu-note-\(size)-\(entry.1)@\(entry.0)x.png",rect:CGRect(x:x+117,y:y+32,width:CGFloat(size+8)*4,height:CGFloat(size+8)*4))
        }
    }
}
print("CR-003: 4 transparent template icons, 8 appearance/scale previews and icon sheet exported.")
