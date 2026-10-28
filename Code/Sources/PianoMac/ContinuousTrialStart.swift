import PianoAudio

/// Explicit user action only. Local input does not depend on global permission.
/// The caller owns UI/coordinator state; failures always clean both services.
enum ContinuousTrialStart {
    static func run(global: Bool, input: InputMonitoring, audio: AuditionSession) throws {
        do {
            try input.start(global: global, duration: .continuous)
            try audio.enable()
        } catch {
            input.stop(); audio.disable()
            throw error
        }
    }
}
