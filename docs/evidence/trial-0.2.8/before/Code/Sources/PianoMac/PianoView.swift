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
    public var showLabels = true { didSet { if oldValue != showLabels { needsDisplay = true } } }
    public var activeMIDI: Set<Int> = [] { didSet { if oldValue != activeMIDI { updateKeys(from: oldValue, at: clock()) } } }
    public var reducedMotion = false { didSet { if oldValue != reducedMotion { resetEffects(); motions.removeAll(); needsDisplay = true } } }
    public var automaticAnimation = true
    public var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
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
            return CGRect(x: shape.rect.midX - ink.midX + note.driftX + ink.minX,
                y: AdaptiveOverlay.headroom + shape.rect.minY - 4 - note.rise + ink.minY - ink.maxY,
                width: ink.width, height: ink.height).insetBy(dx: -4, dy: -4)
        }
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
    public override func setFrameSize(_ size: NSSize) { super.setFrameSize(size); rebuildKeys() }
    private static func color(_ hex: String) -> CGColor {
        let n = UInt32(hex, radix: 16)!
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [CGFloat((n >> 16)&255)/255, CGFloat((n >> 8)&255)/255, CGFloat(n&255)/255, 1])!
    }
    private static func line(_ text: String, _ size: CGFloat, _ color: String) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: NSColor(cgColor: Self.color(color))!]))
    }
    private func makeLabel(_ text: String, size: CGFloat, color: String, x: CGFloat, bottom: CGFloat) -> Label {
        let line = Self.line(text, size, color), ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
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
        keys = PianoGeometry.quietIvory(mapping: mapping, width: bounds.width).map { shape in
            let key = mapping.keys.first { $0.midiNote == shape.midi }!, r = shape.rect, black = shape.isBlack
            let color = black ? "CDCDCD" : "595959", size: CGFloat = black ? 9.5 : 10
            let ink = CTLineGetBoundsWithOptions(Self.line(key.labelParts.main, size, color), .useGlyphPathBounds)
            let main = makeLabel(key.labelParts.main, size: size, color: color, x: r.midX - ink.midX - (key.labelParts.side == nil ? 0 : 0.6), bottom: r.maxY - (black ? 3 : 4))
            var labels = [main]
            if let side = key.labelParts.side {
                let ink = CTLineGetBoundsWithOptions(Self.line(side, 6.5, color), .useGlyphPathBounds)
                labels.append(makeLabel(side, size: 6.5, color: color, x: r.maxX - 1.1 - ink.maxX, bottom: main.ink.minY + (black ? -0.6 : 2)))
            }
            return Key(shape: shape, labels: labels)
        }
        needsDisplay = true
    }
    public func setMapping(_ mapping: KeyMapping) {
        resetEffects(); mouseKey = nil; activeMIDI = []; motions.removeAll()
        self.mapping = mapping; rebuildKeys()
    }
    public func strike(_ event: NoteEvent, at time: Double) {
        guard sceneVisible else { return }
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
    private func render(_ ctx: CGContext) {
        ctx.saveGState(); ctx.translateBy(x: 0, y: AdaptiveOverlay.headroom)
        fill(ctx, CGRect(x: 0, y: 0, width: bounds.width, height: AdaptiveOverlay.bodyHeight), "353638", 3)
        fill(ctx, CGRect(x: 1, y: 2, width: bounds.width - 2, height: 106), "71716E", 2)
        for black in [false, true] {
            for key in keys where key.shape.isBlack == black {
                let midi = key.shape.midi, r = key.shape.rect
                let amount = keyDepression(midi: midi, at: sampleTime)
                let down = activeMIDI.contains(midi) || amount > 0
                ctx.saveGState(); ctx.translateBy(x: 0, y: reducedMotion ? 0 : amount * (black ? 1.5 : 2))
                if black {
                    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: down ? 0.5 : 1), blur: down ? 0.5 : 1.5, color: CGColor(gray: 0, alpha: down ? 0.18 : 0.3))
                    fill(ctx, r, "242528", 1.2); ctx.restoreGState()
                }
                ctx.saveGState(); ctx.addPath(CGPath(roundedRect: r, cornerWidth: black ? 1.2 : 1, cornerHeight: black ? 1.2 : 1, transform: nil)); ctx.clip()
                let colors = black ? (down ? ["303134", "1B1C1F"] : ["424346", "242528"]) : (down ? ["E7E5DF", "D8D6D1"] : ["FEFDFB", "EEEDE9"])
                let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(Self.color) as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(gradient, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [])
                fill(ctx, CGRect(x: r.minX, y: r.maxY - (black ? 2 : 2.5), width: r.width, height: black ? 2 : 2.5), black ? (down ? "141518" : "17181B") : (down ? "C3C1BC" : "D5D3CE"))
                ctx.setStrokeColor(Self.color(black ? "58595C" : "FFFFFF")); ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: r.minX + 1, y: r.minY + 0.5)); ctx.addLine(to: CGPoint(x: r.maxX - 1, y: r.minY + 0.5)); ctx.strokePath(); ctx.restoreGState()
                if showLabels { for label in key.labels { drawLine(ctx, label.line, x: label.x, baseline: label.baseline) } }
                ctx.restoreGState()
            }
        }
        let ink = CTLineGetBoundsWithOptions(floatingLine, .useGlyphPathBounds)
        for note in floatingPresentations {
            guard let shape = keys.first(where: { $0.shape.midi == note.midi })?.shape else { continue }
            ctx.saveGState(); ctx.setAlpha(note.opacity); ctx.setShadow(offset: .zero, blur: 1.25, color: CGColor(gray: 1, alpha: 0.9))
            drawLine(ctx, floatingLine, x: shape.rect.midX - ink.midX + note.driftX, baseline: shape.rect.minY - 4 - note.rise + ink.minY)
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }
    public override func draw(_ dirtyRect: NSRect) { if let ctx = NSGraphicsContext.current?.cgContext { render(ctx) } }
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil); let body = CGPoint(x: point.x, y: point.y - AdaptiveOverlay.headroom)
        let key = keys.filter { $0.shape.isBlack }.first { $0.shape.rect.contains(body) } ?? keys.filter { !$0.shape.isBlack }.first { $0.shape.rect.contains(body) }
        guard let key, let physical = mapping.keys.first(where: { $0.midiNote == key.shape.midi }) else { return }
        mouseKey = physical.physicalKeyID; onPress?(physical.physicalKeyID)
    }
    public override func mouseUp(with event: NSEvent) { if let mouseKey { onRelease?(mouseKey) }; mouseKey = nil }
    public func savePNG(to url: URL, scale: Int = 2) throws {
        let w = Int(bounds.width) * scale, h = Int(bounds.height) * scale
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ProbeError.invalid("无法建立预览位图") }
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale)); ctx.translateBy(x: 0, y: bounds.height); ctx.scaleBy(x: 1, y: -1); render(ctx)
        guard let image = ctx.makeImage(), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw ProbeError.invalid("无法编码预览PNG") }
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
