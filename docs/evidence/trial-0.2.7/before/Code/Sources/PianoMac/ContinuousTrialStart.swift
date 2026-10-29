import Foundation
import PianoAudio

/// Explicit user action only. Local input does not depend on global permission.
/// The caller owns UI/coordinator state; failures always clean both services.
enum ContinuousTrialStart {
    enum Failure: LocalizedError {
        case input(Error), audio(Error)
        var errorDescription: String? {
            switch self {
            case .input(let error): return "输入监听未能开始：\(error.localizedDescription)"
            case .audio(let error): return "声音启动失败：\(error.localizedDescription)；请检查音频设备或重新点击开始。"
            }
        }
    }
    static func run(global: Bool, input: InputMonitoring, audio: AuditionSession) throws {
        do {
            do { try input.start(global: global, duration: .continuous) } catch { throw Failure.input(error) }
            do { try audio.enable() } catch { throw Failure.audio(error) }
        } catch {
            input.stop(); audio.disable()
            throw error
        }
    }
}
