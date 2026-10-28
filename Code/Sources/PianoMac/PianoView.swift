import AppKit
import PianoCore

/// Plain procedural M0 surface; not the final UI design or CR-002 animated renderer.
public final class PianoView: NSView {
    public let mapping: KeyMapping
    public var showLabels = true { didSet { if oldValue != showLabels { needsDisplay = true } } }
    public var activeMIDI: Set<Int> = [] { didSet { if oldValue != activeMIDI { needsDisplay = true } } }
    public var onPress: ((String) -> Void)?
    public var onRelease: ((String) -> Void)?
    private var mouseKey: String?
    public override var isFlipped: Bool { true }
    public init(mapping: KeyMapping, frame: NSRect) {
        self.mapping = mapping
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityLabel("M0 占位琴键预览，64键；标签来自映射文件")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    public override func draw(_ dirtyRect: NSRect) {
        let geometry = PianoGeometry.layout(mapping: mapping, width: bounds.width, height: bounds.height)
        for black in [false, true] {
            for shape in geometry where shape.isBlack == black {
                guard let key = mapping.keys.first(where: { $0.midiNote == shape.midi }) else { continue }
                let pressed = activeMIDI.contains(shape.midi)
                let rect = shape.rect.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: pressed ? 1 : 0)
                (black ? NSColor(calibratedWhite: pressed ? 0.30 : 0.16, alpha: 1) : NSColor(calibratedWhite: pressed ? 0.82 : 0.96, alpha: 1)).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
                guard showLabels else { continue }
                let color = NSColor(calibratedWhite: black ? 0.78 : 0.40, alpha: 1)
                let font = NSFont.systemFont(ofSize: black ? 9.5 : 10)
                let main = NSAttributedString(string: key.labelParts.main, attributes: [.font: font, .foregroundColor: color])
                let side = NSAttributedString(string: key.labelParts.side ?? "", attributes: [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: color])
                // Independent superscript, overlapping horizontally but above the main glyph.
                // Keeps a 7pt side marker inside narrow black keys without shrinking the main label.
                let sideWidth = key.labelParts.side == nil ? 0 : (black ? side.size().width * 0.5 + 0.25 : side.size().width + 0.5)
                let x = rect.midX - (main.size().width + sideWidth) / 2
                let y = rect.maxY - main.size().height - 3
                main.draw(at: NSPoint(x: x, y: y))
                let sideX = black ? x + main.size().width - side.size().width * 0.5 + 0.25 : x + main.size().width + 0.5
                let sideY = black ? y - side.size().height * 0.85 : y + main.size().height - side.size().height
                side.draw(at: NSPoint(x: sideX, y: sideY))
            }
        }
    }
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let geometry = PianoGeometry.layout(mapping: mapping, width: bounds.width, height: bounds.height)
        let candidate = geometry.filter(\.isBlack).first { $0.rect.contains(point) }
            ?? geometry.filter { !$0.isBlack }.first { $0.rect.contains(point) }
        guard let midi = candidate?.midi, let key = mapping.keys.first(where: { $0.midiNote == midi }) else { return }
        mouseKey = key.physicalKeyID; onPress?(key.physicalKeyID)
    }
    public override func mouseUp(with event: NSEvent) {
        if let key = mouseKey { onRelease?(key) }; mouseKey = nil
    }
    public func savePNG(to url: URL) throws {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { throw ProbeError.invalid("无法建立预览位图") }
        cacheDisplay(in: bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw ProbeError.invalid("无法编码预览PNG") }
        try png.write(to: url)
    }
}
public final class ProbePanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    public init(content: PianoView) {
        super.init(contentRect: content.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear; isOpaque = false; hasShadow = false
        level = .normal; ignoresMouseEvents = true; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
        isReleasedWhenClosed = false; contentView = content
    }
}
