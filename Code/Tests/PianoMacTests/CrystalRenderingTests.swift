import XCTest
import AppKit
import PianoCore
@testable import PianoMac

final class CrystalRenderingTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    func testHitTestingUsesPressedRoundedBlackFaceAfterHeightChange() throws {
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        view.automaticAnimation = false; view.clock = { 0 }
        let key = try XCTUnwrap(mapping.keys.first { $0.midiNote == 61 })
        view.activeMIDI = [61]; view.advanceAnimations(at: 0.1); view.setHeightScale(1.8)
        let shape = try XCTUnwrap(PianoGeometry.quietIvory(mapping: mapping, width: 1264, heightScale: 1.8).first { $0.midi == 61 })
        let point = CGPoint(x: shape.rect.midX + 2, y: 144 + shape.rect.maxY + 1)
        XCTAssertEqual(view.physicalKey(atCanvasPoint: point), key.physicalKeyID)
        XCTAssertNotEqual(view.physicalKey(atCanvasPoint: CGPoint(x: shape.rect.minX + 0.01, y: 144 + shape.rect.minY + 2.7 + 0.01)), key.physicalKeyID)
        view.activeMIDI = []; view.advanceAnimations(at: 1)
        XCTAssertNotEqual(view.physicalKey(atCanvasPoint: point), key.physicalKeyID)
    }
    func testFinalCompositedFacesAreTranslucentWithNoWhiteUnderBlackAndOpaqueFallback() throws {
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        for scale in [0.5, 1, 1.8] {
            let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
            view.automaticAnimation = false; view.setHeightScale(scale); view.showLabels = false
            let shapes = PianoGeometry.quietIvory(mapping: mapping, width: 1264, heightScale: scale)
            for pressed in [false, true] {
                view.activeMIDI = pressed ? Set(33...96) : []; view.advanceAnimations(at: ProcessInfo.processInfo.systemUptime + 1)
                for opaque in [false, true] {
                    view.reducedTransparency = opaque
                    let image = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
                    XCTAssertEqual(image.pixelsHigh, Int(ceil((144 + 112 * scale) * 2)))
                    XCTAssertEqual(image.colorAt(x: 100, y: 100)?.alphaComponent, 0)
                    for shape in shapes {
                        let travel = pressed ? (shape.isBlack ? 1.5 : 2) * scale : 0
                        let y = 144 + shape.rect.minY + travel + shape.rect.height * (shape.isBlack ? 0.5 : 0.85)
                        let color = try XCTUnwrap(image.colorAt(x: Int(shape.rect.midX * 2), y: Int(y * 2)))
                        if opaque { XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.005) }
                        else {
                            XCTAssertGreaterThan(color.alphaComponent, 0.75)
                            XCTAssertLessThan(color.alphaComponent, 0.94, "white under black would accumulate near-opaque alpha")
                        }
                    }
                }
            }
            for shape in shapes {
                let point = CGPoint(x: shape.rect.midX, y: 144 + shape.rect.minY + shape.rect.height * (shape.isBlack ? 0.5 : 0.85))
                XCTAssertEqual(view.physicalKey(atCanvasPoint: point), mapping.keys.first { $0.midiNote == shape.midi }?.physicalKeyID)
            }
            XCTAssertNil(view.physicalKey(atCanvasPoint: CGPoint(x: 100, y: 100)))
        }
    }
}
