# BUG-002 menu and duplicate launch implementation plan

Role: CODE; authorization: PM delegated the user's compact-menu/duplicate-icon fix. No Git writes, production launch, live audio, permission changes, or overwrite of authorized 0.2.1. Existing main-reported BUG-001 sound success is separate evidence.

Chosen scope: 20pt fixed status slot, retain current 18pt template image. New GUI launches acquire a per-user advisory flock before constructing the controller/status item. Recognize only exact typing-piano bundle identities plus matching contained executable; pre-protocol same-bundle instances (e.g. 0.2.1) block the new launch. Activate existing process and exit self; never terminate another process. A versioned Info.plist marker distinguishes cooperating new instances from pre-lock old apps, so simultaneous new launches cannot veto the lock winner. PM scope refinement: only local.typingpiano.trial is controlled; local.typingpiano.probe is ignored and PM has already quit it. Old unmodified apps launched after a new app cannot be controlled retrospectively. Do not replace bundle files beneath running apps.

- [x] Write regression tests for trusted app matching, old-vs-cooperating recognition, real exclusive lock contention/release/stale file and symlink rejection. Run red.
- [x] Implement small launch gate module and integrate before controller construction. Set status slot20pt. No other UI changes.
- [x] Test targeted headless suite. Build0.2.2/build5 only under candidate-0.2.2; protect frozen root in build script.
- [x] Verify signing/resources; compare designated requirements read-only, preserve0.2.1 hash. Handoff candidate, upgrade steps and explicit remaining GUI/TCC checks.

Alternative rejected: terminating old apps automatically disrupts active input/audio. Pure NSWorkspace enumeration alone has a concurrent-start race, so a kernel-held advisory lock handles cooperating versions. No certificate/TCC workaround will be introduced.
