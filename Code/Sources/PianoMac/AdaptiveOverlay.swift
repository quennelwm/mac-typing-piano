import Foundation
import PianoCore

public enum AdaptiveOverlay {
    public static let bodyHeight: CGFloat = 112
    public static let headroom: CGFloat = 144
    public static var canvasHeight: CGFloat { height(scale: 1) }
    public static func height(scale: Double) -> CGFloat { headroom + PianoHeight.body(scale) }
    public static func frame(screen: CGRect, heightScale: Double = 1) -> CGRect {
        CGRect(x: screen.minX + 8, y: screen.minY,
               width: max(1, screen.width - 16), height: height(scale: heightScale))
    }
}
