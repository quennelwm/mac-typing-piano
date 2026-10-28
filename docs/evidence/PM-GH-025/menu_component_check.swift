import AppKit
import Foundation

// Compile with the production ProbeMenu.swift and the built PianoAudio objects.
// Bounded component check: no ProbeController, input, audio, preferences or Dock writes.
@main
struct MenuComponentCheck {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        var menu: ProbeMenu? = ProbeMenu(volume: 0.5, installStatusItem: true)
        defer { menu = nil }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
        let actual = menu!.actualStatusButtonWidth ?? -1
        var images: [[String: Any]] = []
        for scale in [1, 2] {
            let pixels = 16 * scale
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = NSSize(width: 16, height: 16)
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            menu!.icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
            NSGraphicsContext.restoreGraphicsState()
            let filename = "menu-icon@\(scale)x.png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
            var bounds = [pixels, pixels, -1, -1]
            var edgeAlpha = 0
            for y in 0..<pixels {
                for x in 0..<pixels {
                    let alpha = Int((bitmap.colorAt(x: x, y: y)!.alphaComponent * 255).rounded())
                    if alpha > 8 {
                        bounds[0] = min(bounds[0], x); bounds[1] = min(bounds[1], y)
                        bounds[2] = max(bounds[2], x); bounds[3] = max(bounds[3], y)
                    }
                    if x == 0 || x == pixels - 1 || y == 0 || y == pixels - 1 { edgeAlpha = max(edgeAlpha, alpha) }
                }
            }
            images.append(["file": filename, "scale": scale, "inkBoundsPixelsAlphaOver8": bounds, "maximumOuterEdgeAlpha": edgeAlpha])
        }
        let passed = actual == 16 && menu!.icon.size == NSSize(width: 16, height: 16)
        let record: [String: Any] = ["passed": passed, "actualStatusButtonWidthPt": actual,
            "iconCanvasPt": [16, 16], "renders": images, "kind": "production ProbeMenu component in temporary process; not full candidate App GUI acceptance",
            "inputStarted": false, "audioStarted": false, "systemDockWritten": false]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("menu-component-check.json"))
        print("Menu component actual button width: \(actual)pt; passed: \(passed)")
        if !passed { exit(1) }
    }
}
