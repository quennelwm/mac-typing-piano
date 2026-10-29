import XCTest
import Carbon
import PianoCore
@testable import PianoMac
func mappingFixture() throws -> KeyMapping {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try KeyMapping.load(url: root.appendingPathComponent("contracts/keymap.ansi64.v0.1.json"))
}
final class InputNormalizerTests: XCTestCase {
    func testSDKResolvesAll64UniqueCodesExcludesTopRow() throws {
        let keys = try SDKKeys.resolve(mappingFixture())
        XCTAssertEqual(keys.count, 64)
        for code in [kVK_Escape, kVK_F1, kVK_F12] { XCTAssertNil(keys[UInt16(code)]) }
    }
    func testSidedModifierUsesDeviceBitsNotCombinedShiftFlag() throws {
        let n = try InputNormalizer(mapping: mappingFixture())
        XCTAssertEqual(n.normalize(code: UInt16(kVK_Shift), kind: .flags, flags: 0x20002)?.phase, .down)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_RightShift), kind: .flags, flags: 0x20006)?.phase, .down)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_Shift), kind: .flags, flags: 0x20004)?.phase, .up)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_RightShift), kind: .flags, flags: 0)?.phase, .up)
    }
    func testFnAndCapsSemanticsRemainUnverifiedAndPulseOnlyCandidate() throws {
        let n = try InputNormalizer(mapping: mappingFixture())
        XCTAssertEqual(n.normalize(code: UInt16(kVK_Function), kind: .flags, flags: 0x800000)?.phase, .down)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_Function), kind: .flags, flags: 0)?.phase, .up)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_CapsLock), kind: .flags)?.phase, .pulse)
        XCTAssertEqual(n.normalize(code: UInt16(kVK_Function), kind: .flags)?.captureCapability, "unverified")
    }
    func testFiltersAutoRepeatAndUnexpectedKinds() throws {
        let n = try InputNormalizer(mapping: mappingFixture())
        XCTAssertNil(n.normalize(code: UInt16(kVK_ANSI_A), kind: .down, isRepeat: true))
        XCTAssertNil(n.normalize(code: UInt16(kVK_ANSI_A), kind: .flags))
        XCTAssertEqual(n.normalize(code: UInt16(kVK_ANSI_A), kind: .down)?.physicalKeyID, "keyA")
        XCTAssertNil(n.normalize(code: UInt16(kVK_F1), kind: .down))
    }
}
