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


## Core gameplay identity — Generals / Zero Hour-inspired RTS

The intended match experience is a mobile adaptation of the classic base-building, economy-driven, combined-arms RTS formula associated with Command & Conquer: Generals and Zero Hour. The goal is to reproduce the strategic feel and pacing with original game content, not to copy proprietary maps, art, models, audio, dialogue, names, or source code.

### Match loop

1. Deploy a construction vehicle / builder and establish a defensible base.
2. Secure supply resources and expand the economy.
3. Build power, barracks, vehicle factories, airfields, naval yards, defenses, and technology structures.
4. Produce mixed forces and research faction-specific upgrades.
5. Scout, capture strategic supply or map-control points, defend expansion routes, and attack enemy infrastructure.
6. Earn access to commander support abilities and late-game strategic weapons with clear counters and warning feedback.
7. Win by destroying the enemy command base or completing a mission-specific objective.

### Design pillars

- **Readable RTS base building:** clear building footprints, construction queues, prerequisites, rally points, repair/sell options, and touch-friendly placement.
- **Economy and map control:** supply collection, finite or renewable resource locations as appropriate per map, supply lines, and meaningful expansion decisions.
- **Combined arms:** every unit class has a battlefield role and clear counters; no single unit should dominate all matchups.
- **Distinct commanders:** preserve the four established factions (American, Chinese, Arab Army, and وطن), then add commander specializations as a later layer rather than fragmenting the initial playable roster.
- **Support powers:** commander abilities, reconnaissance, air strikes, defensive deployments, and strategic weapons with cooldowns, costs, telegraphs, and counterplay.
- **Skirmish and campaign:** configurable AI skirmish matches first; a mission campaign with objectives, briefings, and escalating difficulty after the core loop is stable.
- **Mobile-first controls:** tap to select, tap ground to move, tap enemy to attack, drag-select, contextual command panel, touch camera pan and pinch zoom, and optional simplified control presets.
- **Cinematic 3D presentation:** angled strategic camera, legible silhouettes, terrain elevation, destructible-looking feedback, projectile trails, smoke, explosions, and faction-specific sound identity while maintaining Android performance.

### Originality and implementation boundaries

Use original faction names, unit/building names, maps, story, UI, models, textures, music, and voice acting, or assets with licenses that explicitly permit use and redistribution. Use Zero Hour only as a high-level gameplay reference. Do not reproduce its proprietary content.

### Implementation order

1. Stabilize the existing mobile RTS loop and touch interactions.
2. Add builder/construction-vehicle and building placement/queue mechanics.
3. Improve supply collection, expansion, and power/production dependencies.
4. Add commander identity, upgrades, and support powers with counters.
5. Improve AI economy, scouting, base defense, coordinated assaults, and recovery.
6. Build the 3D battlefield and port gameplay systems in tested slices, keeping the current working scene as fallback.
7. Add skirmish setup, maps, mission progression, and campaign presentation.
8. Profile and validate the integrated experience on the target Android phone.

Do not treat this direction document as proof that any listed feature has already been implemented.


### First base-building implementation slice — construction vehicle

- The player now starts a match with one free construction vehicle beside the command base.
- The vehicle can be selected and ordered to move with the existing ground-order control.
- A separate production button can purchase an additional construction vehicle for 600 credits; it uses no supply points.
- Building placement now requires a selected, living player construction vehicle within 220 world/screen units of the proposed site.
- The builder has its own visible vehicle silhouette and 220 HP. The existing barracks/factory/airfield/defense and naval-yard placement flow is retained.
- This is an initial construction-authorization and movement slice. Production queues, prerequisites, power management, rally points, repair/sell, and worker pathing remain future work.
- Player-placed buildings now take time to finish (6–13 seconds depending on type), show a construction progress bar, and cannot produce units or fire defenses until complete. AI-placed buildings retain the existing instant-completion behavior for now; AI construction timing remains a balancing task.
- Android/Godot smoke validation for this latest source commit is pending; do not describe this feature as device-tested until the relevant workflow and a phone test pass.
- Construction now advances only while a living player builder is within 48 units of the site. On placement, the selected builder receives a movement order to the site; if the builder is destroyed or cannot reach the site, progress pauses until a builder returns. On completion, the worker is released.

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
