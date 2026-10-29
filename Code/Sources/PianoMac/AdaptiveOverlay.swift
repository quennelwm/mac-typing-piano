import Foundation

public enum AdaptiveOverlay {
    public static let bodyHeight: CGFloat = 112
    public static let headroom: CGFloat = 96
    public static let canvasHeight: CGFloat = 208
    public static func frame(screen: CGRect) -> CGRect {
        CGRect(x: screen.minX + 8, y: screen.minY,
               width: max(1, screen.width - 16), height: canvasHeight)
    }
}
