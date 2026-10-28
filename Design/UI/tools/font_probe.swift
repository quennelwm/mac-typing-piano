import AppKit
import CoreText
let glyphs = ["⌘", "⌥", "⇧", "⌃", "⇪", "↵", "⌫", "␣", "fn", "←", "L", "R"]
for size: CGFloat in [9.5, 10, 6, 6.5] {
  let font = NSFont.systemFont(ofSize: size, weight: .medium)
  for s in glyphs {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:[.font:font]))
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    let names = runs.map { String(describing: (CTRunGetAttributes($0) as NSDictionary)[kCTFontAttributeName]!) }
    print("\(size) \(s) \(CTLineGetTypographicBounds(line,nil,nil,nil)) \(names)")
  }
}
