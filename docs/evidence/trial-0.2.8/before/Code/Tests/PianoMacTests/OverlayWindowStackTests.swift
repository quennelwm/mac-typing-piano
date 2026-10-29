import XCTest
import AppKit
import PianoCore
@testable import PianoMac

final class OverlayWindowStackTests: XCTestCase {
    func testOrdinaryWindowsReorderBelowOverlayWhileModalStaysAbove() throws {
        _ = NSApplication.shared
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mapping = try KeyMapping.load(url: root.appendingPathComponent("contracts/" + KeyMapping.defaultFilename))
        let result = OverlayWindowEvidence.run(mapping: mapping)
        print("C029_WINDOW_STACK " + String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
        XCTAssertEqual(result["passed"] as? Bool, true)
        XCTAssertEqual(result["activationPolicy"] as? Int, NSApplication.ActivationPolicy.accessory.rawValue)
    }
}
