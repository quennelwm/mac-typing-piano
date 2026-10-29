import AppKit
import CoreText
import PianoCore

/// Independent native key paths and text, translated from the approved Quiet Ivory renderer.
public final class PianoView: NSView {
    public struct LabelMetric {
        public let midi: Int
        public let insideKey: Bool
        public let missingGlyphs: Int
        public let overlap: Bool
    }
    private struct Label { let line: CTLine; let x: CGFloat; let baseline: CGFloat; let ink: CGRect; let missing: Int; let fonts: [String] }
    private struct Key { let shape: PianoKeyRect; let labels: [Label] }
    private struct Motion {
        var from: Double; var to: Double; var start: Double; var duration: Double
        var precedingStart: Double? = nil
        var precedingFrom: Double = 0
        func value(_ time: Double) -> Double {
            if time < start, let precedingStart {
                return Motion(from: precedingFrom, to: 1, start: precedingStart, duration: 0.045).value(time)
            }
            if time <= start { return from }
            if time >= start + duration { return to }
            let x = (time - start) / duration
            // Invert cubic-bezier(.2,.7,.2,1)'s x, then evaluate y.
            var low = 0.0, high = 1.0
            for _ in 0..<18 {
                let t = (low + high) / 2, u = 1 - t
                let bx = 3*u*u*t*0.2 + 3*u*t*t*0.2 + t*t*t
                if bx < x { low = t } else { high = t }
            }
            let t = (low + high) / 2, u = 1 - t
            return from + (to - from) * (3*u*u*t*0.7 + 3*u*t*t + t*t*t)
        }
    }
    public private(set) var mapping: KeyMapping
    public private(set) var heightScale: Double = 1
    public private(set) var transparency: Double = 0.15
    public var effectiveMaterialOpacity: Double { reducedTransparency ? 1 : 1 - transparency }
    public func setTransparency(_ value: Double) {
        transparency = value.isFinite ? min(1, max(0, value)) : 0.15
        needsDisplay = true
    }
    public var reducedTransparency = false { didSet { if oldValue != reducedTransparency { needsDisplay = true } } }
    public func setHeightScale(_ value: Double) {
        heightScale = PianoHeight.normalized(value)
        setFrameSize(NSSize(width: bounds.width, height: AdaptiveOverlay.height(scale: heightScale)))
        // Preserve held keys, mouse release ownership and all animation/press IDs.
    }
    public var showLabels = true { didSet { if oldValue != showLabels { needsDisplay = true } } }
    public var activeMIDI: Set<Int> = [] { didSet { if oldValue != activeMIDI { updateKeys(from: oldValue, at: clock()) } } }
    public var reducedMotion = false { didSet { if oldValue != reducedMotion { resetEffects(); motions.removeAll(); needsDisplay = true } } }
    public var automaticAnimation = true
    public var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    public var highlightedMIDI: Int? { didSet { if oldValue != highlightedMIDI { needsDisplay = true } } }
    public var onPress: ((String) -> Void)?
    public var onRelease: ((String) -> Void)?
    public private(set) var floatingPresentations: [FloatingPresentation] = []
    public var floatingCount: Int { floating.instances.count }
    public var animationTimerRunning: Bool { animationTimer != nil }
    public var labelMetrics: [LabelMetric] { keys.map { key in
        let box = key.labels.reduce(CGRect.null) { $0.union($1.ink) }
        return LabelMetric(midi: key.shape.midi, insideKey: key.shape.rect.insetBy(dx: 0.5, dy: 0.5).contains(box),
            missingGlyphs: key.labels.reduce(0) { $0 + $1.missing },
            overlap: key.labels.count == 2 && key.labels[0].ink.intersects(key.labels[1].ink))
    } }
    public var renderMetrics: [[String: Any]] { keys.map { key in
        let r = key.shape.rect
        return ["midi": key.shape.midi, "rectBodyPt": [r.minX, r.minY, r.width, r.height],
            "labels": key.labels.map { label in ["baselineBodyY": label.baseline, "x": label.x,
                "inkBodyPt": [label.ink.minX, label.ink.minY, label.ink.width, label.ink.height],
                "resolvedFonts": label.fonts, "missingGlyphs": label.missing] }]
    } }
    /// Actual CoreText ink bounds in canvas coordinates, including a conservative halo margin.
    public var floatingInkBounds: [CGRect] {
        let ink = CTLineGetBoundsWithOptions(floatingLine, .useGlyphPathBounds)
        return floatingPresentations.compactMap { note in
            guard let shape = keys.first(where: { $0.shape.midi == note.midi })?.shape else { return nil }
            return CGRect(x: floatingX(shape, note, ink) + ink.minX,
                y: AdaptiveOverlay.headroom + shape.rect.minY - 4 - note.rise + ink.minY - ink.maxY,
                width: ink.width, height: ink.height).insetBy(dx: -4, dy: -4)
        }
    }
    private func floatingX(_ shape: PianoKeyRect, _ note: FloatingPresentation, _ ink: CGRect) -> CGFloat {
        min(bounds.width - 4 - ink.maxX, max(4 - ink.minX, shape.rect.midX - ink.midX + note.driftX))
    }
    private var keys: [Key] = []
    private var floating = FloatingNotes()
    private var sceneVisible = true
    private var motions: [Int: Motion] = [:]
    private var frozenDepressions: [Int: Double]?
    private var downTimes: [Int: Double] = [:]
    private var sampleTime = 0.0
    private var animationTimer: Timer?
    private var mouseKey: String?
    public static let floatingFontSize: CGFloat = 24
    private let floatingLine: CTLine
    public override var isFlipped: Bool { true }
    public init(mapping: KeyMapping, frame: NSRect) {
        self.mapping = mapping
        floatingLine = Self.line("♪", Self.floatingFontSize, "626C66")
        super.init(frame: frame)
        rebuildKeys()
        setAccessibilityElement(true)
        setAccessibilityLabel("打字钢琴，64键；标签来自映射文件")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    public override func setFrameSize(_ size: NSSize) { guard size != frame.size else { return }; super.setFrameSize(size); rebuildKeys() }
    private static var colorCache: [String: CGColor] = [:]
    private static var gradientCache: [String: CGGradient] = [:]
    private static func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
        let key = hex + String(describing: alpha)
        if let cached = colorCache[key] { return cached }
        let n = UInt32(hex, radix: 16)!
        let color = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [CGFloat((n >> 16)&255)/255, CGFloat((n >> 8)&255)/255, CGFloat(n&255)/255, alpha])!
        if colorCache.count < 64 { colorCache[key] = color }; return color
    }
    private static func line(_ text: String, _ size: CGFloat, _ color: String, alpha: CGFloat = 1) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: NSColor(cgColor: Self.color(color, alpha: alpha))!]))
    }
    private func makeLabel(_ text: String, size: CGFloat, color: String, alpha: CGFloat = 1, x: CGFloat, bottom: CGFloat) -> Label {
        let line = Self.line(text, size, color, alpha: alpha), ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        var missing = 0
        var fonts: [String] = []
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            if let font = attributes[kCTFontAttributeName] { fonts.append(CTFontCopyPostScriptName(font as! CTFont) as String) }
            var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            missing += glyphs.filter { $0 == 0 }.count
        }
        return Label(line: line, x: x, baseline: bottom + ink.minY,
            ink: CGRect(x: x + ink.minX, y: bottom + ink.minY - ink.maxY, width: ink.width, height: ink.height), missing: missing, fonts: fonts)
    }
    private func rebuildKeys() {
        keyBitmap = nil; keyBitmapState = []; materialTiles = [:]; materialTileBytes = 0
        keys = PianoGeometry.quietIvory(mapping: mapping, width: bounds.width, heightScale: heightScale).map { shape in
            let key = mapping.keys.first { $0.midiNote == shape.midi }!, r = shape.rect, black = shape.isBlack
            let color = black ? "68717A" : "969FA9", size: CGFloat = black ? 9.5 : 10
            let alpha: CGFloat = black ? 0.90 : 0.86
            let ink = CTLineGetBoundsWithOptions(Self.line(key.labelParts.main, size, color), .useGlyphPathBounds)
            let main = makeLabel(key.labelParts.main, size: size, color: color, alpha: alpha, x: r.midX - ink.midX - (key.labelParts.side == nil ? 0 : 0.6), bottom: r.maxY - (black ? 3 : 4))
            var labels = [main]
            if let side = key.labelParts.side {
                let ink = CTLineGetBoundsWithOptions(Self.line(side, 6.5, color), .useGlyphPathBounds)
                labels.append(makeLabel(side, size: 6.5, color: color, alpha: alpha, x: r.maxX - 1.1 - ink.maxX, bottom: main.ink.minY + (black ? -0.6 : 2)))
            }
            return Key(shape: shape, labels: labels)
        }
        needsDisplay = true
    }
    public func setMapping(_ mapping: KeyMapping) {
        resetEffects(); mouseKey = nil; activeMIDI = []; motions.removeAll()
        self.mapping = mapping; rebuildKeys()
    }
    public var floatingNotesEnabled = true { didSet { if oldValue != floatingNotesEnabled && !floatingNotesEnabled { floating.setVisible(false); floating.setVisible(sceneVisible); floatingPresentations.removeAll(); needsDisplay = true } } }
    public func strike(_ event: NoteEvent, at time: Double) {
        guard sceneVisible, floatingNotesEnabled else { return }
        floating.strike(event, time: time, generation: floating.sceneGeneration, reducedMotion: reducedMotion)
        advanceAnimations(at: time); startTimerIfNeeded()
    }
    public func setSceneVisible(_ visible: Bool) {
        guard sceneVisible != visible else { return }
        if visible { frozenDepressions = nil }
        else {
            let now = clock()
            frozenDepressions = Dictionary(uniqueKeysWithValues: keys.map { ($0.shape.midi, keyDepression(midi: $0.shape.midi, at: now)) })
        }
        sceneVisible = visible; floating.setVisible(visible)
        motions.removeAll(); downTimes.removeAll(); floatingPresentations.removeAll()
        stopTimer(); needsDisplay = true
    }
    public func resetEffects() {
        frozenDepressions = nil
        floating.setVisible(false); floating.setVisible(sceneVisible)
        floatingPresentations.removeAll(); motions.removeAll(); downTimes.removeAll(); stopTimer(); needsDisplay = true
    }
    private func updateKeys(from old: Set<Int>, at time: Double) {
        sampleTime = time
        guard sceneVisible, !reducedMotion else { motions.removeAll(); needsDisplay = true; return }
        for midi in old.symmetricDifference(activeMIDI) {
            let down = activeMIDI.contains(midi)
            let value = motions[midi]?.value(time) ?? (old.contains(midi) ? 1 : 0)
            if down {
                downTimes[midi] = time
                motions[midi] = Motion(from: value, to: 1, start: time, duration: 0.045)
            } else {
                let releaseAt = max(time, (downTimes.removeValue(forKey: midi) ?? time - 0.045) + 0.045)
                // Short presses finish their 45ms depression before the 100ms release.
                if releaseAt > time {
                    let preceding = motions[midi]
                    motions[midi] = Motion(from: 1, to: 0, start: releaseAt, duration: 0.1,
                        precedingStart: preceding?.start ?? releaseAt - 0.045, precedingFrom: preceding?.from ?? 0)
                }
                else { motions[midi] = Motion(from: value, to: 0, start: releaseAt, duration: 0.1) }
            }
        }
        needsDisplay = true; startTimerIfNeeded()
    }
    public func keyDepression(midi: Int, at time: Double) -> Double {
        frozenDepressions?[midi] ?? motions[midi]?.value(time) ?? (activeMIDI.contains(midi) ? 1 : 0)
    }
    public func advanceAnimations(at time: Double) {
        sampleTime = time
        floating.expire(at: time); floatingPresentations = floating.presentations(at: time)
        motions = motions.filter { time < $0.value.start + $0.value.duration }
        needsDisplay = true
        if floating.instances.isEmpty && motions.isEmpty { stopTimer() }
    }
    private func startTimerIfNeeded() {
        guard automaticAnimation, sceneVisible, animationTimer == nil, !floating.instances.isEmpty || !motions.isEmpty else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }; self.advanceAnimations(at: self.clock())
        }
        animationTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func stopTimer() { animationTimer?.invalidate(); animationTimer = nil }
    private func fill(_ ctx: CGContext, _ r: CGRect, _ hex: String, _ radius: CGFloat = 0) {
        ctx.setFillColor(Self.color(hex)); ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.fillPath()
    }
    private func drawLine(_ ctx: CGContext, _ line: CTLine, x: CGFloat, baseline: CGFloat) {
        ctx.saveGState(); ctx.translateBy(x: x, y: baseline); ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity; ctx.textPosition = .zero; CTLineDraw(line, ctx); ctx.restoreGState()
    }
    private func keyTravel(_ key: Key) -> Double {
        reducedMotion ? 0 : keyDepression(midi: key.shape.midi, at: sampleTime) * (key.shape.isBlack ? 1.5 : 2) * heightScale
    }
    private func keyFace(_ key: Key) -> CGPath {
        CGPath(roundedRect: key.shape.rect.offsetBy(dx: 0, dy: keyTravel(key)), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
    }
    private func drawMaterialVector(_ ctx: CGContext, rect r: CGRect, black: Bool, down: Bool) {
        let path = CGPath(roundedRect: r, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        // Edge-only shadow; no filled dark duplicate underneath a translucent face.
        ctx.saveGState()
        // Narrow vector penumbra retains edge depth without 64 Gaussian filters per frame.
        ctx.setStrokeColor(Self.color("26364A", alpha: down ? 0.025 : 0.04)); ctx.setLineWidth(2.5)
        ctx.addPath(path); ctx.strokePath()
        ctx.setStrokeColor(Self.color("26364A", alpha: down ? 0.10 : 0.16)); ctx.setLineWidth(0.5)
        ctx.addPath(path); ctx.strokePath(); ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        let colors: [CGColor]
        if black {
            // CR-011: black body stays pure black; only the narrow rim carries gloss.
            colors = [Self.color("000000"), Self.color("000000")]
        } else if reducedTransparency {
            colors = ["F4F7FA", "DFE7EF"].map { Self.color($0) }
        } else {
            colors = down ? [Self.color("E9F0F7"), Self.color("CDD9E6")]
                  : [Self.color("FFFFFF"), Self.color("E4ECF4")]
        }
        let gradientKey = "\(black)-\(down)-\(reducedTransparency)"
        let gradient = Self.gradientCache[gradientKey] ?? CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
        if Self.gradientCache.count < 8 { Self.gradientCache[gradientKey] = gradient }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [])
        ctx.setStrokeColor(Self.color(black ? "F3F8FF" : "FFFFFF", alpha: black ? 0.55 : 0.72)); ctx.setLineWidth(0.7)
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 0.35, dy: 0.35), cornerWidth: 2.15, cornerHeight: 2.15, transform: nil)); ctx.strokePath()
        ctx.setStrokeColor(Self.color(black ? "334357" : "788BA2", alpha: black ? 0.30 : 0.22)); ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: r.minX + 2.5, y: r.maxY - 1)); ctx.addLine(to: CGPoint(x: r.maxX - 2.5, y: r.maxY - 1)); ctx.strokePath()
        ctx.restoreGState()
    }
    private var materialTiles: [String: CGImage] = [:]
    private var materialTileBytes = 0
    private func drawMaterial(_ ctx: CGContext, rect r: CGRect, black: Bool, down: Bool) {
        guard cacheKeys else { drawMaterialVector(ctx, rect:r, black:black, down:down); return }
        let key = "\(r.width)-\(r.height)-\(black)-\(down)-\(reducedTransparency)"
        if materialTiles[key] == nil {
            let width = Int(ceil((r.width+8)*2)), height = Int(ceil((r.height+8)*2))
            if materialTileBytes + width*height*4 <= 1024*1024, keyCacheBytes + width*height*4 <= 4*1024*1024,
               let tile = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) {
                tile.scaleBy(x:2,y:2); tile.translateBy(x:0,y:CGFloat(height)/2); tile.scaleBy(x:1,y:-1)
                drawMaterialVector(tile,rect:CGRect(x:4,y:4,width:r.width,height:r.height),black:black,down:down)
                if let image = tile.makeImage() { materialTiles[key] = image; materialTileBytes += image.bytesPerRow*image.height }
            }
        }
        if let image = materialTiles[key] {
            let width = CGFloat(image.width)/2, height = CGFloat(image.height)/2
            ctx.saveGState(); ctx.translateBy(x:r.minX-4,y:r.minY-4+height); ctx.scaleBy(x:1,y:-1)
            ctx.draw(image,in:CGRect(x:0,y:0,width:width,height:height)); ctx.restoreGState()
        } else { drawMaterialVector(ctx,rect:r,black:black,down:down) }
    }
    public private(set) var keyLayerRenders = 0
    public private(set) var floatingLayerRenders = 0
    private func renderKeys(_ ctx: CGContext) {
        keyLayerRenders += 1
        ctx.saveGState(); ctx.translateBy(x: 0, y: AdaptiveOverlay.headroom)
        // Composite material once, so face alpha is exactly 1-transparency, not accumulated layers.
        let body = CGRect(x: 0, y: 0, width: bounds.width, height: PianoHeight.body(heightScale))
        ctx.saveGState(); ctx.setAlpha(effectiveMaterialOpacity); ctx.beginTransparencyLayer(in: body.insetBy(dx: -4, dy: -4), auxiliaryInfo: nil)
        // Bound the intermediate material surface to the body, excluding 144pt headroom.
        ctx.setFillColor(Self.color("526174", alpha: 0.10))
        ctx.addPath(CGPath(roundedRect: body, cornerWidth: 4, cornerHeight: 4, transform: nil)); ctx.fillPath()
        let blackFaces = keys.filter { $0.shape.isBlack }.map { keyFace($0) }
        for black in [false, true] {
            for key in keys where key.shape.isBlack == black {
                let offset = keyTravel(key), r = key.shape.rect.offsetBy(dx: 0, dy: offset)
                let down = activeMIDI.contains(key.shape.midi) || keyDepression(midi: key.shape.midi, at: sampleTime) > 0
                let path = keyFace(key)
                ctx.saveGState()
                if !black {
                    // Subtract transformed black faces before painting white, including pressed black keys.
                    ctx.addRect(key.shape.rect.offsetBy(dx: 0, dy: keyTravel(key)).insetBy(dx: -4, dy: -4))
                    for face in blackFaces where face.boundingBoxOfPath.intersects(key.shape.rect.offsetBy(dx: 0, dy: keyTravel(key)).insetBy(dx: -4, dy: -4)) { ctx.addPath(face) }
                    ctx.clip(using: .evenOdd)
                }
                drawMaterial(ctx, rect: r, black: black, down: down)
                ctx.restoreGState()
            }
        }
        ctx.endTransparencyLayer(); ctx.restoreGState()
        // Labels stay independent of material opacity, including at 100% transparency.
        if showLabels {
            for key in keys {
                ctx.saveGState()
                // Label metrics place white ink below the black-key reach; no full mask is needed.
                for label in key.labels { drawLine(ctx, label.line, x: label.x, baseline: label.baseline + keyTravel(key)) }
                ctx.restoreGState()
            }
        }
        if let highlightedMIDI, let key = keys.first(where: { $0.shape.midi == highlightedMIDI }) { ctx.setStrokeColor(NSColor.controlAccentColor.cgColor); ctx.setLineWidth(2.5); ctx.addPath(keyFace(key)); ctx.strokePath() }
        ctx.restoreGState()
    }
    public var cacheKeys = true
    private var keyBitmap: CGImage?
    private var keyBitmapState: [Double] = []
    public var keyCacheBytes: Int { (keyBitmap?.bytesPerRow ?? 0) * (keyBitmap?.height ?? 0) + materialTileBytes }
    private func render(_ ctx: CGContext) {
        let moving = motions.values.contains { sampleTime < $0.start + $0.duration }
        let state: [Double] = [bounds.width, bounds.height, transparency, showLabels ? 1 : 0, reducedTransparency ? 1 : 0, reducedMotion ? 1 : 0, Double(highlightedMIDI ?? -1)] + keys.flatMap { [keyTravel($0), activeMIDI.contains($0.shape.midi) ? 1.0 : 0.0] }
        let bodyHeight = bounds.height - AdaptiveOverlay.headroom
        let w = Int(ceil(bounds.width * 2)), h = Int(ceil(bodyHeight * 2))
        if cacheKeys && !moving && w*h*4 + materialTileBytes <= 4*1024*1024 {
            if keyBitmapState != state || keyBitmap == nil {
                keyBitmap = nil; keyBitmapState = []
                if let bitmap = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    bitmap.scaleBy(x: 2,y: 2); bitmap.translateBy(x: 0,y: bodyHeight); bitmap.scaleBy(x: 1,y: -1); bitmap.translateBy(x:0,y:-AdaptiveOverlay.headroom)
                    renderKeys(bitmap)
                    if let candidate = bitmap.makeImage(), candidate.bytesPerRow*candidate.height + materialTileBytes <= 4*1024*1024 { keyBitmap = candidate; keyBitmapState = state }
                }
            }
            if let keyBitmap {
                ctx.saveGState(); ctx.translateBy(x: 0,y: bounds.height); ctx.scaleBy(x: 1,y: -1); ctx.draw(keyBitmap, in: CGRect(x:0,y:0,width:bounds.width,height:bodyHeight)); ctx.restoreGState()
            } else { renderKeys(ctx) }
        } else { renderKeys(ctx) }
        ctx.saveGState(); ctx.translateBy(x: 0,y: AdaptiveOverlay.headroom)
        let ink = CTLineGetBoundsWithOptions(floatingLine, .useGlyphPathBounds)
        if !floatingPresentations.isEmpty { floatingLayerRenders += 1 }
        for note in floatingPresentations {
            guard let shape = keys.first(where: { $0.shape.midi == note.midi })?.shape else { continue }
            ctx.saveGState(); ctx.setAlpha(note.opacity); ctx.setShadow(offset: .zero, blur: 1.25, color: CGColor(gray: 1, alpha: 0.9))
            drawLine(ctx, floatingLine, x: floatingX(shape, note, ink), baseline: shape.rect.minY - 4 - note.rise + ink.minY)
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }
    public override func draw(_ dirtyRect: NSRect) { if let ctx = NSGraphicsContext.current?.cgContext { render(ctx) } }
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let physical = physicalKey(atCanvasPoint: point) else { return }
        mouseKey = physical; onPress?(physical)
    }
    func physicalKey(atCanvasPoint point: CGPoint) -> String? {
        let body = CGPoint(x: point.x, y: point.y - AdaptiveOverlay.headroom)
        let key = keys.filter { $0.shape.isBlack }.first { keyFace($0).contains(body) } ?? keys.filter { !$0.shape.isBlack }.first { keyFace($0).contains(body) }
        guard let key else { return nil }
        return mapping.keys.first(where: { $0.midiNote == key.shape.midi })?.physicalKeyID
    }
    public override func mouseUp(with event: NSEvent) { if let mouseKey { onRelease?(mouseKey) }; mouseKey = nil }
    public func renderedImage(scale: Int = 2, syntheticBackground: String? = nil) throws -> CGImage {
        guard (1...2).contains(scale) else { throw ProbeError.invalid("预览倍率必须为1或2") }
        let w = Int(ceil(bounds.width * CGFloat(scale))), h = Int(ceil(bounds.height * CGFloat(scale)))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ProbeError.invalid("无法建立预览位图") }
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale)); ctx.translateBy(x: 0, y: bounds.height); ctx.scaleBy(x: 1, y: -1)
        if let syntheticBackground {
            let colors = syntheticBackground == "color" ? ["B9D9DC", "D8BBD0", "D7DDBA"] : [syntheticBackground == "dark" ? "202733" : "FFFFFF"]
            for (i, color) in colors.enumerated() {
                fill(ctx, CGRect(x: CGFloat(i) * bounds.width / CGFloat(colors.count), y: 0, width: bounds.width / CGFloat(colors.count), height: bounds.height), color)
            }
        }
        render(ctx)
        guard let image = ctx.makeImage() else { throw ProbeError.invalid("无法建立预览图像") }
        return image
    }
    public func savePNG(to url: URL, scale: Int = 2, syntheticBackground: String? = nil) throws {
        let image = try renderedImage(scale: scale, syntheticBackground: syntheticBackground)
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw ProbeError.invalid("无法编码预览PNG") }
        try png.write(to: url)
    }
    deinit { animationTimer?.invalidate() }
}
public final class ProbePanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    public init(content: PianoView) {
        super.init(contentRect: content.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear; isOpaque = false; hasShadow = false
        // Stay above ordinary work windows without competing with Dock, menus or modal panels.
        level = .floating; ignoresMouseEvents = true; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
        isReleasedWhenClosed = false; contentView = content
    }
}
