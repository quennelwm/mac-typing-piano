import XCTest
@testable import PianoCore

final class StartupFlowTests: XCTestCase {
    func temporaryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("intent.json") }
    func testExplicitAuthorizationSurvivesRelaunchButRequiresNewClick() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = try StartupFlow(intentURL: url)
        XCTAssertEqual(try first.handle(.primary, permission: false, secureInput: false), .requestAuthorization)
        let relaunched = try StartupFlow(intentURL: url)
        XCTAssertTrue(relaunched.pendingAuthorization)
        XCTAssertEqual(try relaunched.handle(.becameActive, permission: true, secureInput: false), .none)
        XCTAssertEqual(try relaunched.handle(.primary, permission: true, secureInput: false), .start)
        XCTAssertEqual(try relaunched.handle(.becameActive, permission: true, secureInput: false), .none)
        XCTAssertFalse(try StartupFlow(intentURL: url).pendingAuthorization)
    }
    func testPlainLaunchActivationAndPauseNeverStartOrRequestPermission() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let flow = try StartupFlow(intentURL: url)
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: false), .none)
        _ = try flow.handle(.primary, permission: false, secureInput: false)
        _ = try flow.handle(.cancel, permission: true, secureInput: false)
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: false), .none)
        XCTAssertFalse(try StartupFlow(intentURL: url).pendingAuthorization)
    }
    func testReturnWithoutPermissionConsumesIntentAndDoesNotRequestAgain() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let flow = try StartupFlow(intentURL: url)
        _ = try flow.handle(.primary, permission: false, secureInput: false)
        XCTAssertEqual(try flow.handle(.becameActive, permission: false, secureInput: false), .permissionMissing)
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: false), .none)
    }
    func testSecureInputConsumesPendingIntentAndRequiresNewClick() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let flow = try StartupFlow(intentURL: url)
        _ = try flow.handle(.primary, permission: false, secureInput: false)
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: true), .secureInput)
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: false), .none)
        XCTAssertEqual(try flow.handle(.primary, permission: true, secureInput: false), .start)
    }
    func testFailedPersistencePreventsAuthorizationRequest() throws {
        let root = temporaryURL().deletingLastPathComponent(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let obstruction = root.appendingPathComponent("file"); try Data().write(to: obstruction)
        let flow = try StartupFlow(intentURL: obstruction.appendingPathComponent("intent.json"))
        XCTAssertThrowsError(try flow.handle(.primary, permission: false, secureInput: false))
        XCTAssertFalse(flow.pendingAuthorization)
    }
}

extension StartupFlowTests {
    func testIntermediateActivationDoesNotConsumePendingIntentBeforeSettingsVisit() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let flow = try StartupFlow(intentURL: url)
        _ = try flow.handle(.primary, permission: false, secureInput: false)
        var gate = AuthorizationReturnGate(); gate.beginRequest()
        XCTAssertFalse(gate.canContinue(permission: false))
        XCTAssertTrue(flow.pendingAuthorization)
        gate.observedSettings()
        XCTAssertTrue(gate.canContinue(permission: false))
        XCTAssertEqual(try flow.handle(.becameActive, permission: false, secureInput: false), .permissionMissing)
        XCTAssertFalse(flow.pendingAuthorization)
    }
    func testImmediatePermissionSuccessAndRelaunchDoNotRequireSettingsVisit() {
        var gate = AuthorizationReturnGate(); gate.beginRequest()
        XCTAssertTrue(gate.canContinue(permission: true))
        gate.reset()
        XCTAssertTrue(gate.canContinue(permission: true))
    }
}


extension StartupFlowTests {
    private func checkCleanupFailure(event: StartupFlow.Event, secureInput: Bool) throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var failClear = false
        let flow = try StartupFlow(intentURL: url, persist: { pending in
            if !pending && failClear { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("{\"pendingAuthorization\":\(pending)}".utf8).write(to: url, options: .atomic)
        })
        _ = try flow.handle(.primary, permission: false, secureInput: false)
        failClear = true
        XCTAssertThrowsError(try flow.handle(event, permission: true, secureInput: secureInput))
        XCTAssertFalse(flow.pendingAuthorization)
        failClear = false
        XCTAssertEqual(try flow.handle(.becameActive, permission: true, secureInput: false), .none)
        let relaunched = try StartupFlow(intentURL: url)
        XCTAssertTrue(relaunched.pendingAuthorization) // Durable stale flag is visible, but never auto-replayed.
        XCTAssertEqual(try relaunched.handle(.becameActive, permission: true, secureInput: false), .none)
        XCTAssertEqual(try relaunched.handle(.primary, permission: true, secureInput: false), .start)
        XCTAssertFalse(try StartupFlow(intentURL: url).pendingAuthorization)
    }
    func testConsumeCleanupFailureCannotRestartOnActivationOrRelaunch() throws {
        try checkCleanupFailure(event: .becameActive, secureInput: false)
    }
    func testSecureInputCleanupFailureCannotRestartOnActivationOrRelaunch() throws {
        try checkCleanupFailure(event: .becameActive, secureInput: true)
    }
    func testCancelCleanupFailureCannotRestartOnActivationOrRelaunch() throws {
        try checkCleanupFailure(event: .cancel, secureInput: false)
    }
}
