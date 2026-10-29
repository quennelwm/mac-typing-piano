import AppKit
import PianoCore

/// Explicit diagnostic: orders only its own temporary windows; no activation, capture or input.
public enum OverlayWindowEvidence {
    public static func run(mapping: KeyMapping) -> [String: Any] {
        let before = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let frame = NSRect(x: NSScreen.main?.visibleFrame.midX ?? 400,
                           y: NSScreen.main?.visibleFrame.midY ?? 400, width: 360, height: AdaptiveOverlay.canvasHeight)
        let panel = ProbePanel(content: PianoView(mapping: mapping, frame: NSRect(origin: .zero, size: frame.size)))
        panel.setFrame(frame, display: false)
        func window(_ level: NSWindow.Level) -> NSWindow {
            let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = level; w.backgroundColor = .windowBackgroundColor
            w.ignoresMouseEvents = true; w.isReleasedWhenClosed = false
            return w
        }
        let a = window(.normal), b = window(.normal), modal = window(.modalPanel)
        defer { for w in [panel, a, b, modal] { w.orderOut(nil); w.close() } }
        func onscreen(_ windows: [NSWindow]) -> [[String: Any]] {
            let deadline = Date(timeIntervalSinceNow: 1)
            var rows: [[String: Any]] = []
            repeat {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
                rows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
                let ids = Set(rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue })
                if windows.allSatisfy({ ids.contains($0.windowNumber) }) { break }
            } while Date() < deadline
            return rows
        }
        panel.orderFrontRegardless()
        _ = onscreen([panel]) // WindowServer registration is asynchronous; never reorder to force a passing result.
        var samples: [[String: Any]] = []
        for (step, front, back) in [("A", a, b), ("B", b, a), ("A-again", a, b)] {
            back.orderFrontRegardless(); front.orderFrontRegardless()
            let rows = onscreen([panel, a, b])
            func rank(_ w: NSWindow) -> Int { rows.firstIndex { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == w.windowNumber } ?? -1 }
            let p = rank(panel), f = rank(front), other = rank(back)
            samples.append(["step": step, "overlayRank": p, "frontNormalRank": f, "backNormalRank": other,
                            "overlayWindowID": panel.windowNumber, "frontNormalWindowID": front.windowNumber,
                            "backNormalWindowID": back.windowNumber,
                            "passed": p >= 0 && f > p && other > f && panel.frame.intersects(front.frame),
                            "overlayLayer": p >= 0 ? (rows[p][kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1 : -1])
        }
        modal.orderFrontRegardless()
        let rows = onscreen([panel, modal])
        let p = rows.firstIndex { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == panel.windowNumber }
        let m = rows.firstIndex { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == modal.windowNumber }
        let belowModal = p != nil && m != nil && m! < p!
        let focusUnchanged = before == NSWorkspace.shared.frontmostApplication?.processIdentifier
        let all = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let serverPanel = all.first { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == panel.windowNumber }
        let safeLevels = panel.level.rawValue < CGWindowLevelForKey(.dockWindow)
            && panel.level.rawValue < CGWindowLevelForKey(.mainMenuWindow)
            && panel.level.rawValue < NSWindow.Level.modalPanel.rawValue
        let passed = samples.allSatisfy { $0["passed"] as? Bool == true } && belowModal && safeLevels
            && focusUnchanged && !panel.isKeyWindow && !panel.isMainWindow && panel.ignoresMouseEvents
            && panel.collectionBehavior.contains(.fullScreenNone)
        return ["kind": "real overlapping NSWindows and WindowServer front-to-back order; no cross-app activation or TCC dialog",
                "passed": passed, "samples": samples, "belowModalWindow": belowModal,
                "frontmostPIDUnchanged": focusUnchanged, "isKeyWindow": panel.isKeyWindow,
                "isMainWindow": panel.isMainWindow, "ignoresMouseEvents": panel.ignoresMouseEvents,
                "windowLevel": panel.level.rawValue, "dockLevel": CGWindowLevelForKey(.dockWindow),
                "menuLevel": CGWindowLevelForKey(.mainMenuWindow), "modalLevel": NSWindow.Level.modalPanel.rawValue,
                "fullScreenNone": panel.collectionBehavior.contains(.fullScreenNone),
                "onActiveSpace": panel.isOnActiveSpace, "occlusionVisible": panel.occlusionState.contains(.visible),
                "serverPanel": serverPanel ?? [:], "frontmostPID": before ?? -1,
                "activationPolicy": NSApp.activationPolicy().rawValue,
                "visible": panel.isVisible, "listenerStarted": false, "audioOutputStarted": false,
                "systemSettingsWritten": false, "permissionRequested": false]
    }
}
