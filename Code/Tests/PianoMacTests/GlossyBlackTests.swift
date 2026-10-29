import XCTest
import AppKit
import PianoCore
@testable import PianoMac

final class GlossyBlackTests: XCTestCase {
    func testBlackBodyGlossAndTransparencyPreserveWhiteFaces() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        view.automaticAnimation = false; view.clock = { 0 }; view.showLabels = false
        let shapes = PianoGeometry.quietIvory(mapping: mapping, width: 1264)
        XCTAssertEqual(shapes.filter(\.isBlack).count, 26)
        var rows: [[String: Any]] = []
        for pressed in [false, true] {
            view.activeMIDI = pressed ? Set(33...96) : []; view.advanceAnimations(at: 1)
            for reduced in [false, true] { for transparency in [0.0, 0.5, 1] {
                view.reducedTransparency = reduced; view.setTransparency(transparency)
                let image = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
                func color(_ x: Double, _ y: Double) -> NSColor {
                    image.colorAt(x: Int(x * 2), y: Int(y * 2))!.usingColorSpace(.sRGB)!
                }
                var maxRGB = 0.0, gloss = 0.0, minAlpha = 1.0, maxAlpha = 0.0
                var whites: [[Double]] = []
                for key in shapes {
                    let travel = pressed ? (key.isBlack ? 1.5 : 2.0) : 0
                    if key.isBlack {
                        for x in [0.25, 0.5, 0.75] { for y in [0.2, 0.4, 0.6] {
                            let c = color(key.rect.minX + key.rect.width * x, 144 + key.rect.minY + travel + key.rect.height * y)
                            maxRGB = max(maxRGB, c.redComponent, c.greenComponent, c.blueComponent)
                            minAlpha = min(minAlpha, c.alphaComponent); maxAlpha = max(maxAlpha, c.alphaComponent)
                        } }
                        for y in [0.5, 1.0, 1.5] {
                            let c = color(key.rect.midX, 144 + key.rect.minY + travel + y)
                            gloss = max(gloss, c.redComponent, c.greenComponent, c.blueComponent)
                        }
                    } else {
                        let c = color(key.rect.midX, 144 + key.rect.minY + travel + key.rect.height * 0.85)
                        whites.append([c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent])
                    }
                }
                XCTAssertLessThanOrEqual(maxRGB, 0.005, "black body must remain #000000")
                XCTAssertEqual(minAlpha, view.effectiveMaterialOpacity, accuracy: 0.006)
                XCTAssertEqual(maxAlpha, view.effectiveMaterialOpacity, accuracy: 0.006)
                if view.effectiveMaterialOpacity > 0 { XCTAssertGreaterThan(gloss, 0.05) }
                rows.append(["pressed": pressed, "reduced": reduced, "transparency": transparency, "blackBodyMaxRGB": maxRGB, "alphaMin": minAlpha, "alphaMax": maxAlpha, "localGlossMaxRGB": gloss, "whiteSamples": whites])
            } }
        }
        if let path = ProcessInfo.processInfo.environment["TYPING_PIANO_BLACK_EVIDENCE"] {
            try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
        }
    }
}
