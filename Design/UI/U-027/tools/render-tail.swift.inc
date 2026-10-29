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
