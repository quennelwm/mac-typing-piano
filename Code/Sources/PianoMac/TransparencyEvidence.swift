import AppKit
import PianoCore

public enum TransparencyEvidence {
    /// Three representative images; all other combinations are numeric, never desktop capture.
    public static func render(mapping: KeyMapping, directory: URL) throws -> [String: Any] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: AdaptiveOverlay.canvasHeight))
        view.automaticAnimation = false; view.clock = { 0 }; view.showLabels = false
        var rows: [[String: Any]] = []
        for value in [0.0, 0.15, 0.5, 1] {
            view.setTransparency(value)
            for reduced in [false, true] {
                view.reducedTransparency = reduced
                let bitmap = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
                let samples = PianoGeometry.quietIvory(mapping: mapping, width: 1264).compactMap { key -> CGFloat? in
                    let y = 144 + key.rect.minY + key.rect.height * (key.isBlack ? 0.5 : 0.8)
                    return bitmap.colorAt(x: Int(key.rect.midX * 2), y: Int(y * 2))?.alphaComponent
                }
                let bytes = bitmap.bitmapData!
                let clear = (0..<(bitmap.pixelsWide * bitmap.pixelsHigh)).allSatisfy { bytes[$0 * 4 + 3] == 0 }
                rows.append(["transparency": value, "reducedTransparency": reduced,
                             "storedViewSetting": view.transparency, "effectiveOpacity": view.effectiveMaterialOpacity,
                             "sampleCount": samples.count, "minFaceAlpha": samples.min() ?? -1,
                             "maxFaceAlpha": samples.max() ?? -1, "wholeMaterialBitmapClear": clear])
            }
        }
        view.reducedTransparency = false; view.showLabels = true
        var coordinator = NoteCoordinator(mapping: mapping)
        _ = coordinator.consume(.init("keyG", .down))
        if let event = coordinator.lastStrike { view.strike(event, at: 0) }
        view.advanceAnimations(at: 0.475)
        var captures: [String] = []
        for value in [0.0, 0.5, 1] {
            view.setTransparency(value)
            let name = "transparency-\(Int(value * 100)).png"
            try view.savePNG(to: directory.appendingPathComponent(name), scale: 2, syntheticBackground: "color")
            captures.append(name)
        }
        let passed = rows.allSatisfy { row in
            let target = row["effectiveOpacity"] as! Double
            return abs((row["minFaceAlpha"] as! CGFloat) - target) < 0.006
                && abs((row["maxFaceAlpha"] as! CGFloat) - target) < 0.006
                && (target != 0 || row["wholeMaterialBitmapClear"] as? Bool == true)
        }
        let report: [String: Any] = ["passed": passed, "samples": rows, "images": captures,
                                    "kind": "offscreen production rendering on synthetic backgrounds; no App GUI",
                                    "labelPolicy": "independent white #969FA9/0.86 and black #414B55/0.84",
                                    "listenerStarted": false, "audioOutputStarted": false, "systemSettingsWritten": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
        return ["passed": passed, "imageCount": captures.count, "sampleRows": rows.count, "outputDirectory": directory.path]
    }
}
