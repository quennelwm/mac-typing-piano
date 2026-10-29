import AppKit
import CoreGraphics
import Darwin
import Foundation

// Default is read-only. Private SPI availability/ABI must not be treated as a public compatibility promise.
let path = "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else { fatalError("HIServices unavailable") }
defer { dlclose(handle) }
guard let getAddress = dlsym(handle, "CoreDockGetAutoHideEnabled"),
      let setAddress = dlsym(handle, "CoreDockSetAutoHideEnabled") else { fatalError("CoreDock SPI unavailable") }
let get = unsafeBitCast(getAddress, to: (@convention(c) () -> UInt8).self)
let set = unsafeBitCast(setAddress, to: (@convention(c) (UInt8) -> Void).self)
func snapshot(_ phase: String) {
    let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    let windows = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []).filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
    }.map { row -> [String: Any] in
        var result: [String: Any] = [:]
        for key in [kCGWindowNumber,kCGWindowBounds,kCGWindowLayer,kCGWindowAlpha] { result[key as String] = row[key as String] }
        return result
    }
    let result: [String: Any] = ["phase":phase,"getter":get(),"getterSymbolAvailable":true,"setterSymbolAvailable":true,
        "dockOnscreenWindows":windows,"visibleFrames":NSScreen.screens.map { NSStringFromRect($0.visibleFrame) },
        "permissionRequested":false,"framework":path,"privateSPI":true]
    print(String(decoding:try! JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]),as:UTF8.self)); fflush(stdout)
}
snapshot("read-only-before")
if CommandLine.arguments.contains("--guarded-toggle") {
    guard get() == 1 else { fatalError("Expected user-selected autohide=true; no write performed") }
    defer {
        if get() == 0 { set(1) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
        snapshot("restored-original-true")
    }
    set(0)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
    snapshot("explicit-test-after-set-false")
}
