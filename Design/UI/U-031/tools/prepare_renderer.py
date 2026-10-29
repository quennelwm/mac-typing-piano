from pathlib import Path
P=Path(__file__).resolve().parents[1];ROOT=P.parents[2]
s=(ROOT/'Design/UI/U-027/tools/drawing.swift.inc').read_text()
s=s.replace('Design/UI/U-027")','Design/UI/U-031")') # preserve source mapping path separately
s=s.replace('let labelColors = ["white": "#595959", "black": "#CDCDCD"]','let labelColors = ["white": "#969FA9", "black": "#414B55"]\nvar heightScale:CGFloat=1\nvar reduceTransparency=false\nlet recipeURL=ui.appendingPathComponent("reference.json")\nlet config=try JSONSerialization.jsonObject(with:Data(contentsOf:recipeURL)) as! [String:Any]\nlet material=config["material"] as! [String:Any]')
s=s.replace('y: 4, width: slot * 0.59, height: 64','y: 4*heightScale, width: slot * 0.59, height: 64*heightScale').replace('y: 4, width: slot - 0.7, height: 100','y: 4*heightScale, width: slot - 0.7, height: 100*heightScale')
a=s.index('func surface(');b=s.index('func text(',a)
s=s[:a]+'''func alphaColor(_ hex:String,_ alpha:CGFloat)->CGColor {color(hex).copy(alpha:alpha)!}
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
''' +s[b:]
s=s.replace('let mappingURL =', 'let qaCache=URL(fileURLWithPath:ProcessInfo.processInfo.environment["TYPING_PIANO_UI_QA_CACHE"] ?? (NSHomeDirectory()+"/Library/Caches/local.typingpiano.ui/U-031"))\ntry FileManager.default.createDirectory(at:qaCache.appendingPathComponent("qa"),withIntermediateDirectories:true)\ntry FileManager.default.createDirectory(at:qaCache.appendingPathComponent("previews"),withIntermediateDirectories:true)\nlet retainedBodyPreviews:Set<String>=["previews/piano-1496-h50-rest@1x.png","previews/piano-1496-h100-rest@1x.png","previews/piano-1496-h180-rest@1x.png","previews/piano-1264-h50-rest@1x.png","previews/piano-1904-h180-rest@1x.png"]\nlet mappingURL =')
s=s.replace('try rep.representation(using:.png,properties:[:])!.write(to:ui.appendingPathComponent(path))','let cacheOnly=path.hasPrefix("qa/") || (path.hasPrefix("previews/piano-") && !retainedBodyPreviews.contains(path))\n    try rep.representation(using:.png,properties:[:])!.write(to:(cacheOnly ? qaCache:ui).appendingPathComponent(path))')
(P/'tools/drawing.swift.inc').write_text(s)
print('Prepared U-031 procedural translucent drawing functions.')
