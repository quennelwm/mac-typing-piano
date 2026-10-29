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
