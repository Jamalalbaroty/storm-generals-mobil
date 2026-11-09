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

## Efficient development and APK strategy

- Work in batches: complete a coherent feature group, review the integrated code, and update its documentation before asking the user to install anything.
- Do not create a new APK for documentation-only changes. The Android workflow runs on manual dispatch or changes to game scripts, scenes, resources, supported media assets, project settings, export settings, or the workflow itself.
- Use lightweight source review and repository checks during development. Reserve the next user-facing APK for a planned integrated candidate after the major gameplay and presentation milestones are ready.
- Once the candidate is available, perform one structured Android test pass using `docs/QA_CHECKLIST.md`, collect defects, fix them in a batch, and produce a release candidate for a final confirmation pass.
- Keep the user informed about actual repository commits and build results; never describe a planned feature as implemented until it exists in the project.


## 3D visual migration — approved direction

The approved visual target is a cinematic, realistic 3D battlefield with an angled strategic camera. The migration is deliberately additive: keep `main.tscn` and the working 2D match as the active fallback while the 3D scene is developed and validated separately.

### Current 3D prototype status

- Added `prototype_3d/battlefield_3d.tscn` and `prototype_3d/battlefield_3d.gd` as an isolated Godot 3D scene.
- The prototype currently creates a lit arena, a strategic camera, and three primitive tank proxies.
- Added camera focus framing plus one-finger pan, two-finger pinch zoom, mouse-wheel zoom, and middle-mouse pan. These controls are isolated to the 3D prototype and still require an actual Godot scene smoke test and Android touch validation.
- These tank proxies are greybox geometry, not finished realistic vehicle assets. The prototype is not yet connected to production movement, combat, AI, economy, or touch selection.
- The main project remains on the Compatibility renderer and the existing 2D scene. Do not switch renderers or the startup scene until a verified Android test demonstrates that the chosen renderer and 3D content run reliably on target devices.

### Migration gates

1. **Scene foundation:** validate camera framing, lighting, mobile-friendly materials, and arena readability in the isolated scene.
2. **Camera and input:** add touch-friendly pan and zoom without conflicting with unit selection; verify landscape and different screen sizes.
3. **Asset quality:** replace proxies with original or properly licensed low-poly-to-high-detail military assets, with mobile-appropriate LODs, texture sizes, and draw calls.
4. **World composition:** add terrain, roads, shoreline/water, bases, buildings, cover, and readable faction silhouettes.
5. **Gameplay integration:** port unit navigation, targeting, combat, projectiles, health, selection, production, and AI in small testable slices.
6. **Effects and audio:** integrate optimized muzzle flashes, tracers, explosions, smoke, vehicle audio, weapon audio, and mix controls.
7. **Android performance gate:** profile frame time, memory, thermal behavior, and battery impact on the user's actual target phone before changing the default renderer or startup scene.
8. **Integrated candidate:** only after the above gates pass should the 3D scene replace the active 2D match and be included in the next planned APK candidate.

The visual goal is realistic and cinematic, but performance and legibility take priority over expensive effects on mobile. No stage is considered complete solely because a scene or asset file exists.

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
