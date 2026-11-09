# Storm Generals — Android Build History

## 2026-11-09 — Build 130

- Workflow: [Build Android APK #130](https://github.com/Jamalalbaroty/storm-generals-mobil/actions/runs/42666704169)
- Result: **success**
- Commit: `02d720a58fd2311aaef94e65f319dbd2813a2fd6`
- Export: `StormGenerals-debug.apk`
- Artifact: `StormGenerals-Android-APK` (artifact ID `13697036882`)
- Artifact size: 26,786,539 bytes
- SHA-256: `05862ebdde5bad09ce03fb3a305bb51b773568b1a1fd3ac2d50636aee18b8f8b`
- Artifact expiry: 2027-02-07

The workflow completed the Godot headless startup smoke test and Android debug export. The user has confirmed that the installed game launches on their phone.

## Remaining release checks

A successful export and launch are not equivalent to full release QA. Continue with:
1. Validate a complete match, including victory and defeat.
2. Exercise construction, production prerequisites, resource/supply limits, capture points, and invalid-action feedback.
3. Test ground, air, missile, and naval counters and target cleanup.
4. Test AI behavior after production buildings are destroyed.
5. Check a 10-minute match, pause/resume, and Android background/foreground transitions.
6. Record device model, Android version, resolution, and tested commit before calling a build release-ready.

This is a debug APK candidate, not a signed production release.
