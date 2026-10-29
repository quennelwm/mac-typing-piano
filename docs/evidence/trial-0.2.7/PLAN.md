# C-027 implementation plan

Approved scope: CR-006. Default profile: new playable when no explicit saved choice, per PM implementation assumption; old explicit choice wins. Canvas 208pt = 112pt body + 96pt transparent effects.

1. Capture current files/hashes; reproduce paused overlay failure with native controller and mocked audio/input.
2. Separate requested display, session safety, Dock suppression and audio pause. Observe Dock before revealing, reset alpha/order state on explicit toggle, preserve static display across ordinary pause, block session/secure input without automatic sound restart. Native controller regressions cover all paths.
3. Convert all 64 DOM IDs explicitly into existing SDK IDs, clone approved physical metadata, replace only note/color/name in new contract. Keep old bytes. Add preset persistence/menu; stop queued input and clear notes/animations before changing mapping, require explicit start after switch.
4. Double body geometry and update floating note to 24pt/48pt rise/4pt drift/900ms; preserve reduced motion and idle timer stop. Test production rendering and generate isolated PNGs.
5. Build independent ad-hoc 0.2.7/build10 App/ZIP; scoped plus full offline/unit suite, selfcheck/menu/snapshots, hashes and protected-file verification. No real input, hardware playback, system setting writes, installed-app launch, signing identity or Git operations.
