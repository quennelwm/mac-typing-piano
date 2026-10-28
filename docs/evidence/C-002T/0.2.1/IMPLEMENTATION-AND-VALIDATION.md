# C-002T / 0.2.1 code handoff

Role: code subtask `local_trial_021`; date 2026-10-28. Repository baseline observed e08b09861dd21defe01da53ea602d5e2035d6817 with pre-existing uncommitted code/design work retained. Production code frozen at approximately 17:18 CST for parent packaging/signing. No Git writes, Design/contracts edits, App launch, UI automation, real listener, permission request, output playback or system setting changes were performed by this subtask.

## Changes

- Startup card provides explicit `授权输入监控` (only that click calls CGRequestListenEventAccess and opens the macOS Input Monitoring settings page), `重新检查并开始`, quit/reopen guidance, and `本窗口试弹（无需权限）`.
- Local continuous trial starts only on click, uses the selected/preloaded bank and local input, does not require global permission, and stops on app focus loss/window close/pause/quit. Global permission failure does not prevent a later local start. Existing safety-input protections remain.
- UI provides live aggregate diagnostics and an explicit save-panel JSON export. Exports contain effective event count, source and gain/volume, noteOn request/accepted counters, actual engine running/sampler loaded flags, actual output-node AudioUnit current device ID/name, and aggregate tap frame/callback/peak/last-callback metrics. Unsupported mock diagnostics remain unsupported/unknown.
- Realtime tap is attached only to this engine's main mixer in live mode. No input node, microphone, other-app audio, samples or key sequences are captured/stored. Work is capped at 8192 frames x 8 channels per callback; nonblocking try-lock may skip callbacks. A nonzero peak is mixer-output evidence, not acoustic evidence.
- Configuration notifications are filtered to the current engine identity; retired/unrelated engine notifications are ignored. Identity is cleared before shutdown.
- `--live-audio-smoke N` is explicit opt-in, 2–30 seconds, loads verified full source, plays fixed MIDI 60/64/67 with note-offs at 50% App volume, captures diagnostics and shuts down. Default launch never invokes it. No system output/volume routing changes. Existing .75 maximum mixer/+12 dB source gain unchanged.
- Menu quit has Command-Q key equivalent. No global shortcut interception added.

## Verification

Environment: macOS 27.2 (26B123), arm64, Apple Swift 6.4 (swiftlang-6.4.0.34.1).

```
swift test --build-system native --package-path Code \
  --scratch-path /Users/wuming/Library/Caches/local.typingpiano.trial/verify021 \
  --filter 'RuntimeDiagnosticsTests|LocalTrialStartTests|PianoCoreTests|AudioSelectionTests'
```

Final: **31 tests, 0 failures**, successful compile/link of changed modules and executable. `headless-tests.log` is the complete final run. No NSApplication/controller window tests were executed. `test-red.log` and `local-red.log` retain initial missing-API test compilation failures before implementation. Only final warning is existing SwiftPM native build-system deprecation.

Specific regression coverage: global permission failure then local continuous success with mock services; startup silent state; preparation failure cleanup; unsupported diagnostic truthfulness; unprepared sampler rejects noteOn; current/old/unrelated notification identity; synthetic in-memory buffer aggregate meter behavior. Existing core/selection tests also passed.

## PM-only pending manual checks

User must grant Input Monitoring to the final signed App path; this task has not requested or verified permission. Parent owns packaging and final version/hash/signature. User/PM must verify startup controls/layout, authorization, fresh retry/reopen, actual local key/mouse trial, full-source audio, displayed current output device and live nonzero meter, export, pause and exit. No sound, TCC, device route, physical keys, focus transitions or visual fit is claimed tested.

Optional explicit command for PM, after ensuring no conflicting trial session:

```
'/Users/wuming/Library/Caches/local.typingpiano.trial/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe' --live-audio-smoke 5 > '/Users/wuming/Desktop/键盘钢琴/docs/evidence/C-002T/0.2.1/live-audio-smoke.json'
```

This command was **not run** by this subtask. It plays local output; no microphone is used. `noteOnAccepted` means submitted to a running sampler, not audible sound. Inspect `engineRunning`, `currentOutputDeviceName`, `outputTapCallbackCount`, `outputTapFrameCount`, `outputTapPeak`, and `cleanupEngineRunning` in the resulting JSON. A zero meter or no callback needs investigation and is not a passing acoustic test.
