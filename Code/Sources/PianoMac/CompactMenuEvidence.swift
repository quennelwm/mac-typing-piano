import AppKit
import PianoCore

public enum CompactMenuEvidence {
    public static func render(mapping: KeyMapping, directory: URL) throws -> [String: Any] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let shell = ProbeMenu(volume: 1, heightScale: 1.8, installStatusItem: false)
        var states: [[String: Any]] = []
        for state in ["运行中：持续全局打字", "已暂停：尚未获得输入监控授权", "已暂停：安全输入阻断", "已暂停：开始状态保存失败"] {
            shell.update(soundEnabled: true, showLabels: true, showOverlay: true, paused: state.hasPrefix("已暂停"), sessionStatus: state)
            shell.updatePermission(granted: !state.contains("授权"))
            shell.updateKeymap(custom: false, warning: "配置读取失败；详细说明不会撑宽根菜单。")
            shell.setPreferencesSaveError(state.contains("失败") ? "写入失败；关闭菜单或退出时重试。" : nil)
            shell.setTransparency(1, reduced: state.contains("安全"))
            states.append(["state": state, "width": shell.menu.size.width, "height": shell.menu.size.height, "visibleRootCount": shell.menu.items.filter { !$0.isHidden }.count])
        }
        shell.update(soundEnabled: true, showLabels: true, showOverlay: true, sessionStatus: "运行中：持续全局打字")
        shell.updatePermission(granted: true); shell.updateKeymap(custom: false, warning: nil)
        shell.setPreferencesSaveError(nil); shell.setTransparency(1, reduced: false)
        let size = shell.menu.size
        func tree(_ menu: NSMenu) -> [[String: Any]] {
            menu.items.map { item in
                var row: [String: Any] = ["title": item.title, "hidden": item.isHidden, "enabled": item.isEnabled, "state": item.state.rawValue, "separator": item.isSeparatorItem, "tooltip": item.toolTip ?? ""]
                if let child = item.submenu { row["submenu"] = tree(child) }
                if let view = item.view {
                    row["viewWidth"] = view.bounds.width; row["viewHeight"] = view.bounds.height
                    row["labels"] = view.subviews.compactMap { $0 as? NSTextField }.map { ["text": $0.stringValue, "frameWidth": $0.frame.width, "fittingWidth": $0.fittingSize.width] as [String: Any] }
                }
                return row
            }
        }
        // Reconstruct the root arrangement using its real native slider views. This is NOT a menu screenshot.
        let items = shell.menu.items.filter { !$0.isHidden }
        let height = items.reduce(CGFloat(12)) { $0 + ($1.view?.bounds.height ?? ($1.isSeparatorItem ? 12 : 24)) }
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width * 2)), pixelsHigh: Int(ceil(height * 2)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ProbeError.invalid("菜单预览上下文失败") }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: 2, y: 2)
        NSColor.windowBackgroundColor.setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size.width, height: height), xRadius: 8, yRadius: 8).fill()
        var top = height - 6
        for item in items {
            let rowHeight = item.view?.bounds.height ?? (item.isSeparatorItem ? 12 : 24)
            top -= rowHeight
            if let view = item.view {
                if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    let image = NSImage(size: view.bounds.size); image.addRepresentation(rep)
                    image.draw(in: NSRect(x: (size.width - view.bounds.width) / 2, y: top, width: view.bounds.width, height: rowHeight), from: .zero, operation: .sourceOver, fraction: 1)
                }
            } else if item.isSeparatorItem {
                NSColor.separatorColor.setFill(); NSRect(x: 10, y: top + 6, width: size.width - 20, height: 0.5).fill()
            } else {
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 13), .foregroundColor: item.isEnabled ? NSColor.labelColor : NSColor.secondaryLabelColor]
                (item.title as NSString).draw(at: NSPoint(x: 24, y: top + 4), withAttributes: attributes)
                if item.state == .on { ("✓" as NSString).draw(at: NSPoint(x: 7, y: top + 4), withAttributes: attributes) }
                if item.submenu != nil { ("›" as NSString).draw(at: NSPoint(x: size.width - 16, y: top + 4), withAttributes: attributes) }
                if !item.keyEquivalent.isEmpty { ("⌘Q" as NSString).draw(at: NSPoint(x: size.width - 32, y: top + 4), withAttributes: attributes) }
            }
        }
        context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("menu-layout.png"))
        let piano = PianoView(mapping: mapping, frame: NSRect(x: 0, y: 0, width: 1264, height: 256))
        piano.automaticAnimation = false; piano.clock = { 0 }; piano.setTransparency(0)
        piano.activeMIDI = [34]; piano.advanceAnimations(at: 1)
        let full = try piano.renderedImage(scale: 2, syntheticBackground: "color")
        guard let crop = full.cropping(to: CGRect(x: 0, y: 288, width: 672, height: 224)) else { throw ProbeError.invalid("黑键局部预览失败") }
        try NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("black-opaque-detail.png"))
        let passed = states.allSatisfy { (170...195).contains($0["width"] as! CGFloat) }
        let report: [String: Any] = ["passed": passed, "measurement": "NSMenu.size native logical layout, not custom view width", "states": states, "normalWidth": size.width, "normalHeight": size.height, "normalVisibleRootCount": items.count, "tree": tree(shell.menu), "menuPreview": "offscreen reconstructed root layout using actual native slider views; NOT a system menu screenshot", "blackPreview": "production PianoView crop; opacity 1, MIDI34 pressed, synthetic background", "images": ["menu-layout.png", "black-opaque-detail.png"], "realClicksTested": false, "candidateGUIStarted": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
        return ["passed": passed, "width": size.width, "imageCount": 2, "outputDirectory": directory.path]
    }
}
