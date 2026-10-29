import Foundation
import PianoCore

public protocol AlertVolumeStorage: AnyObject {
    func read() throws -> Int
    func write(_ volume: Int) throws
}

/// Fixed Standard Additions commands in this process. No target application, shell,
/// System Events, defaults writes, media-volume parameter or automation entitlement.
public final class StandardAdditionsAlertVolumeStorage: AlertVolumeStorage {
    public typealias Executor = (String) throws -> String
    private let execute: Executor
    public init(execute: @escaping Executor = StandardAdditionsAlertVolumeStorage.executeInProcess) { self.execute = execute }
    public func read() throws -> Int {
        let result = try execute("return alert volume of (get volume settings)")
        guard let value = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)), (0...100).contains(value) else {
            throw ProbeError.invalid("系统提示音音量读回无效；未修改设置。")
        }
        return value
    }
    public func write(_ volume: Int) throws {
        guard (0...100).contains(volume) else { throw ProbeError.invalid("提示音音量必须在0到100之间") }
        _ = try execute("set volume alert volume \(volume)")
    }
    public static func executeInProcess(_ source: String) throws -> String {
        precondition(Thread.isMainThread)
        guard let script = NSAppleScript(source: source) else { throw ProbeError.invalid("系统提示音脚本不可用") }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue ?? 0
            if code == -1743 {
                throw ProbeError.invalid("系统拒绝提示音操作（-1743）。本App不会追加自动化权限；请使用系统声音设置。")
            }
            throw ProbeError.invalid("系统提示音操作失败（\(code)）；请使用系统声音设置。")
        }
        return result.stringValue ?? ""
    }
}

/// Owns only this process's verified change. Original volume is kept in memory:
/// crashes cannot promise restoration, and a new process never claims an old change.
public final class AlertVolumeAdapter {
    public enum Outcome: String { case noChange, cancelled, muted, alreadySilent, restored, externalChange, failed }
    private let storage: AlertVolumeStorage
    public private(set) var observed: Int?
    public private(set) var originalVolume: Int?
    private var lastVerified: Int?
    public private(set) var outcome: Outcome = .noChange
    public private(set) var detail = "尚未读取；默认保持系统现状"
    public var hasOwnedChange: Bool { originalVolume != nil }
    public var mutedState: Bool? {
        guard outcome != .failed, !(originalVolume != nil && lastVerified == nil) else { return nil }
        return observed.map { $0 == 0 }
    }
    public init(storage: AlertVolumeStorage) { self.storage = storage }
    private func read() throws -> Int {
        let value = try storage.read()
        guard (0...100).contains(value) else { throw ProbeError.invalid("系统提示音音量读回无效") }
        return value
    }
    private func finish(_ result: Outcome, _ message: String) -> Outcome {
        outcome = result; detail = message; return result
    }
    private func releaseOwnership() { originalVolume = nil; lastVerified = nil }
    @discardableResult public func refresh() -> Outcome {
        do {
            let value = try read(); observed = value
            if originalVolume != nil && value != 0 {
                releaseOwnership()
                return finish(.externalChange, "检测到外部修改为\(value)%；已放弃恢复，不覆盖系统现状")
            }
            if let originalVolume {
                return finish(lastVerified == 0 ? .noChange : .failed,
                    lastVerified == 0 ? "本App已静音；本次原提示音量\(originalVolume)%" : "写后状态未完整核验；原提示音量\(originalVolume)%，请检查系统声音设置")
            }
            return finish(.noChange, value == 0 ? "系统原已静音；本会话未改动，不猜测恢复音量" : "系统提示音量\(value)%；本App未改动")
        } catch { observed = nil; return finish(.failed, error.localizedDescription) }
    }
    @discardableResult public func mute(confirmed: Bool) -> Outcome {
        guard confirmed else { return finish(.cancelled, "已取消；未修改系统提示音") }
        let current = refresh()
        guard current != .failed && current != .externalChange else { return current }
        guard let value = observed else { return finish(.failed, "提示音量未知；保持不动") }
        if value == 0 { return finish(.alreadySilent, originalVolume == nil ? "系统原已静音；不保存虚构的恢复值" : detail) }
        originalVolume = value; lastVerified = nil
        var writeError: String?
        do { try storage.write(0) } catch { writeError = error.localizedDescription }
        do {
            observed = try read()
            if observed == 0 {
                lastVerified = 0
                if let writeError { return finish(.failed, "\(writeError)；读回为0，已保留本次原值\(value)%供关闭时恢复") }
                return finish(.muted, "本App已静音；本次原提示音量\(value)%")
            }
            releaseOwnership()
            return finish(.failed, writeError ?? "系统未确认静音；未报告成功，保持实际读回状态")
        } catch { observed = nil; return finish(.failed, "写后核对失败；原提示音量\(value)%，请检查系统声音设置") }
    }
    @discardableResult public func restore() -> Outcome {
        guard let original = originalVolume else {
            return finish(.noChange, observed == 0 ? "系统原已静音；本App没有可恢复原值，请使用系统声音设置" : detail)
        }
        do {
            observed = try read()
            guard observed == 0 else {
                releaseOwnership(); return finish(.externalChange, "检测到外部修改；未恢复或覆盖系统现状")
            }
            guard lastVerified == 0 else {
                return finish(.failed, "未确认本App写入成功，不能自动恢复；原提示音量\(original)%，请在系统声音设置检查")
            }
            var writeError: String?
            do { try storage.write(original) } catch { writeError = error.localizedDescription }
            observed = try read()
            if observed == original {
                releaseOwnership()
                return finish(writeError == nil ? .restored : .failed, writeError ?? "已恢复本次原提示音量\(original)%")
            }
            if observed != 0 { releaseOwnership() }
            return finish(.failed, writeError ?? "恢复后读回不符；请检查系统声音设置")
        } catch { observed = nil; return finish(.failed, "提示音恢复未完成：\(error.localizedDescription)") }
    }
}
