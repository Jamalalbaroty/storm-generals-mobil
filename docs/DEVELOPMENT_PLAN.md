# Storm Generals — Development Plan

## Current project baseline

The repository already contains a Godot 4.4.1 mobile RTS prototype (README version 0.2.0). The current implementation includes:
- Four selectable factions: American, Chinese, Arab Army, and وطن.
- A player base and an enemy base, resource income, supply-point control, and base health.
- Infantry, tanks, artillery, fighters, helicopters, anti-air, missile systems, and naval units including carriers, destroyers, submarines, and landing craft.
- Barracks, factories, defensive towers, anti-air, airfields, missile facilities, and naval production infrastructure.
- Touch selection, drag selection, movement/attack orders, automated combat, capture behavior, and a first enemy AI.
- Procedurally generated weapon and explosion sounds.
- Android export configuration and a GitHub Actions workflow that builds an APK artifact.

This plan describes the next development and validation work. It is not a claim that every system is fully balanced or device-tested.

## Product direction

Build a stable, readable, mobile-first real-time strategy game. Preserve the current integrated gameplay while improving reliability, balance, clarity, and mission progression.

## Faction identity

All four factions share readable counters and fair core rules. Differences should come from unit statistics, costs, production times, and a small number of signature abilities.

- American: flexible combined-arms toolkit.
- Chinese: disciplined production and defensive efficiency.
- Arab Army: mobile pressure and cost-effective forces.
- وطن: elite technology and powerful specialist units, balanced by higher costs, slower reinforcement, and resource dependence.

## Combat and counter principles

- Infantry are inexpensive and useful for capturing objectives, but vulnerable to armor and artillery.
- Tanks pressure vehicles and structures, but need protection from anti-armor and aircraft.
- Artillery has long range and high area damage, but is slow and vulnerable when exposed.
- Anti-air units protect strategic assets but should not dominate ground combat.
- Fighters counter hostile aircraft; helicopters pressure ground forces but remain vulnerable to anti-air.
- Naval units should have distinct roles: destroyer escort, submarine ambush, carrier air support, and landing-craft transport.
- Missile weapons should be powerful, scarce, telegraphed, and counterable.

## Next milestones

1. **Build verification — completed for build 130:** GitHub Actions passed the Godot headless startup smoke test and exported `StormGenerals-debug.apk`. The user confirmed that the installed game launches on their phone. This verifies the current debug build path, not full gameplay or release readiness; see `docs/BUILD_HISTORY.md`.
2. **Combat QA:** test unit-vs-unit damage, range, cooldowns, splash damage, terrain modifiers, and death/removal behavior.
3. **AI QA:** verify production limits, defense assignments, objective capture, attack timing, and recovery after losing buildings.
4. **Mobile usability:** verify touch targets, drag selection, HUD readability, landscape scaling, and safe-area behavior on a real phone.
5. **Faction balance:** run repeatable mirror and cross-faction matches; adjust costs, health, damage, speed, and production times based on observed outcomes.
6. **Mission progression:** add a short campaign/tutorial sequence with clear objectives and increasing difficulty after skirmish stability.
7. **Release candidate:** run a clean Android export, install it on a real device, and record the tested build/commit before calling it release-ready.

## Definition of done

A feature is complete only when:
- It works in the actual Godot project and does not merely exist as a design note.
- It is usable with touch controls on a phone.
- It handles invalid actions and edge cases safely.
- It has visible feedback and is documented.
- It passes a repeatable test scenario.
- The Android export succeeds after the change.

## Release discipline

GitHub Actions is configured to export a debug APK on pushes to `main`. A successful workflow artifact is a build candidate, not proof of complete gameplay or device compatibility. Final release readiness requires installation and play-testing on a physical Android device.
