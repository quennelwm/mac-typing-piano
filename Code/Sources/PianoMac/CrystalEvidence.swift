import AppKit
import PianoCore

/// Bounded production offscreen evidence: seven images, all other combinations use geometry metrics.
public enum CrystalEvidence {
    public static func render(mapping: KeyMapping, directory: URL) throws -> [String: Any] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var layouts: [[String: Any]] = [], motion: [[String: Any]] = [], captures: [[String: Any]] = []
        for width in [1264.0, 1496, 1904] {
            for scale in [0.5, 1, 1.8] {
                let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: width, height: 256))
                view.automaticAnimation = false; view.clock = { 0 }; view.setHeightScale(scale)
                let labelsOK = view.labelMetrics.allSatisfy { $0.insideKey && !$0.overlap && $0.missingGlyphs == 0 }
                var alpha: [[String: Any]] = []
                for opaque in [false, true] {
                    view.reducedTransparency = opaque
                    let bitmap = NSBitmapImageRep(cgImage: try view.renderedImage(scale: 2))
                    let keys = PianoGeometry.quietIvory(mapping: mapping, width: width, heightScale: scale)
                    for black in [false, true] {
                        let values = keys.filter { $0.isBlack == black }.compactMap { shape -> CGFloat? in
                            let y = 144 + shape.rect.minY + shape.rect.height * (black ? 0.5 : 0.85)
                            return bitmap.colorAt(x: Int(shape.rect.midX * 2), y: Int(y * 2))?.alphaComponent
                        }
                        alpha.append(["black": black, "reducedTransparency": opaque, "count": values.count,
                                      "minAlpha": values.min() ?? -1, "maxAlpha": values.max() ?? -1])
                    }
                }
                layouts.append(["widthPt": width, "heightScale": scale, "bodyHeightPt": PianoHeight.body(scale),
                                "canvasHeightPt": view.bounds.height, "headroomPt": 144, "keyCount": view.labelMetrics.count,
                                "allLabelsInsideNoOverlapNoMissingGlyphs": labelsOK, "faceAlpha": alpha])
                for reduced in [false, true] {
                    view.resetEffects(); view.reducedMotion = reduced
                    var coordinator = NoteCoordinator(mapping: mapping)
                    for key in mapping.keys {
                        _ = coordinator.consume(.init(key.physicalKeyID, .down))
                        if let event = coordinator.lastStrike { view.strike(event, at: 0) }
                    }
                    for time in [0.0, 0.475, 0.949, 0.95] {
                        view.advanceAnimations(at: time)
                        let boxes = view.floatingInkBounds
                        motion.append(["widthPt": width, "heightScale": scale, "reducedMotion": reduced,
                                       "timeMs": Int((time * 1000).rounded()), "instances": view.floatingCount,
                                       "allInkAndHaloInsideCanvas": boxes.allSatisfy { view.bounds.contains($0) },
                                       "minX": boxes.map(\.minX).min() ?? 0, "maxX": boxes.map(\.maxX).max() ?? 0,
                                       "minY": boxes.map(\.minY).min() ?? 0, "maxY": boxes.map(\.maxY).max() ?? 0])
                    }
                }
            }
        }
        let view = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        view.automaticAnimation = false; view.clock = { 0 }
        func capture(_ name: String, background: String? = nil) throws {
            try view.savePNG(to: directory.appendingPathComponent(name), scale: 2, syntheticBackground: background)
            captures.append(["file": name, "heightScale": view.heightScale, "canvasHeightPt": view.bounds.height,
                             "syntheticBackground": background ?? "transparent", "reducedTransparency": view.reducedTransparency])
        }
        for scale in [0.5, 1, 1.8] {
            view.setHeightScale(scale); try capture("crystal-\(Int(scale * 100)).png")
        }
        view.setHeightScale(1)
        try capture("crystal-white.png", background: "white")
        try capture("crystal-dark.png", background: "dark")
        var coordinator = NoteCoordinator(mapping: mapping)
        for key in ["keyG", "space", "arrowRight"] {
            _ = coordinator.consume(.init(key, .down))
            if let event = coordinator.lastStrike { view.strike(event, at: 0) }
        }
        view.activeMIDI = Set(coordinator.active.values.map { $0.key.midiNote })
        view.advanceAnimations(at: 0.475)
        try capture("crystal-color-pressed-475ms.png", background: "color")
        view.resetEffects(); view.activeMIDI = []; view.advanceAnimations(at: 1)
        view.reducedTransparency = true
        try capture("crystal-reduced-transparency.png")
        let passed = layouts.allSatisfy { $0["allLabelsInsideNoOverlapNoMissingGlyphs"] as? Bool == true }
            && motion.allSatisfy { $0["allInkAndHaloInsideCanvas"] as? Bool == true }
        let report: [String: Any] = ["passed": passed, "kind": "production offscreen vectors; synthetic backgrounds, no desktop capture",
                                    "materialVersion": "u031.1", "images": captures, "layouts": layouts, "motion": motion,
                                    "hardwareInput": false, "hardwareAudio": false, "systemSettingsWritten": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
        return ["passed": passed, "imageCount": captures.count, "layoutCount": layouts.count, "motionSamples": motion.count,
                "outputDirectory": directory.path, "appGUIStarted": false, "screenCaptured": false]
    }
}
