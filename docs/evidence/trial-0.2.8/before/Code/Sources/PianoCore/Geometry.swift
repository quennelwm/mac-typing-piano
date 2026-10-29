import Foundation
import CoreGraphics
public struct PianoKeyRect {
    public let midi: Int
    public let isBlack: Bool
    public let rect: CGRect
}
public enum PianoGeometry {
    public static func layout(mapping: KeyMapping, width: Double, height: Double) -> [PianoKeyRect] {
        guard width > 0, height > 0 else { return [] }
        let whiteWidth: CGFloat = CGFloat(width) / 38.0
        let blackWidth: CGFloat = whiteWidth * 0.59
        let blackHeight: CGFloat = CGFloat(height) * 0.64
        var whitesBefore = 0
        var output: [PianoKeyRect] = []
        for key in mapping.keys.sorted(by: { $0.midiNote < $1.midiNote }) {
            let isBlack = key.pianoKeyColor == "black"
            let boundary: CGFloat = CGFloat(whitesBefore) * whiteWidth
            let x: CGFloat = isBlack ? boundary - blackWidth / 2.0 : boundary
            let keyWidth: CGFloat = isBlack ? blackWidth : whiteWidth
            let keyHeight: CGFloat = isBlack ? blackHeight : CGFloat(height)
            let rect = CGRect(x: x, y: CGFloat.zero, width: keyWidth, height: keyHeight)
            output.append(PianoKeyRect(midi: key.midiNote, isBlack: isBlack, rect: rect))
            if !isBlack { whitesBefore += 1 }
        }
        return output
    }
}

extension PianoGeometry {
    /// CR-006 Quiet Ivory 112pt body, top-left coordinates; headroom belongs to the view.
    public static func quietIvory(mapping: KeyMapping, width: Double) -> [PianoKeyRect] {
        guard width > 4 else { return [] }
        let slot = (width - 4) / 38
        var white = 0
        return mapping.keys.sorted { $0.midiNote < $1.midiNote }.map { key in
            let black = key.pianoKeyColor == "black"
            let x = 2 + Double(white) * slot + (black ? -slot * 0.59 / 2 : 0.35)
            if !black { white += 1 }
            return PianoKeyRect(midi: key.midiNote, isBlack: black,
                rect: CGRect(x: x, y: 4, width: black ? slot * 0.59 : slot - 0.7, height: black ? 64 : 100))
        }
    }
}
