import Foundation

public enum AdaptiveOverlay {
    public static func frame(screen: CGRect) -> CGRect {
        CGRect(x: screen.minX + 8, y: screen.minY,
               width: max(1, screen.width - 16), height: 104)
    }
}
