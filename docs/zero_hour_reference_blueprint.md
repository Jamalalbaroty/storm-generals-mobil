# Zero Hour Reference Blueprint — Storm Generals

## Purpose
This document collects gameplay patterns, presentation principles, effects vocabulary, and production stages that Storm Generals can learn from the Command & Conquer: Generals – Zero Hour style. It is an original implementation guide for Godot and Android, not a copy of proprietary source code, assets, maps, audio, animations, or extracted game files.

## Design rules
- Preserve Storm Generals identity, four factions, Arabic-facing terminology, and existing gameplay systems.
- Use Zero Hour as a reference for readable RTS behavior and battlefield presentation, not as a source of copied files.
- Keep the mobile experience touch-first: large targets, clear selection feedback, concise command panels, scalable camera, and performance budgets.
- Approved weather is bright, sunny spring weather only. Biome variation may change terrain, vegetation, architecture, and water, never rain, snow, fog, or storms.
- Do not replace the active 2D match scene with the 3D prototype until gameplay conversion, save/load, input parity, and Android performance are verified.
- Do not spend this phase on enemy AI. Focus on player-facing systems and integration.

## 1. Gameplay systems to reference and recreate
### Base and economy
- Command center as the core dependency and defeat condition.
- Supply collection, income cadence, storage limits, and readable resource feedback.
- Power generation/consumption as a strategic constraint where supported by faction design.
- Construction queue, build radius/placement validation, footprint occupancy, progress, cancellation, and completion feedback.
- Production structures with queues, costs, prerequisites, rally points, and capacity limits.
- Repair, sell, capture, and upgrade interactions where they fit the current game design.

### Combined-arms roster
- Infantry squads and specialist roles.
- Main battle tanks, light armor, artillery, anti-air, and support vehicles.
- Fighters, helicopters, transport aircraft, and carrier-based aircraft.
- Destroyers, submarines, carriers, and landing craft.
- Each unit needs role, cost, build time, health, armor class, movement class, attack range, damage profile, cooldown, target filters, and faction identity.
- Keep counters meaningful: armor vs anti-armor, air vs anti-air, naval control vs coastal defense.

### Tactical controls
- Tap selection, drag-box multi-selection, group selection feedback, move, attack-move, direct attack, stop, and rally point.
- Path destination markers and clear selected-unit status.
- Mobile camera pan and pinch zoom without accidental selection.
- Orders must operate on logical gameplay records; 3D nodes are visual counterparts, not the source of truth.

### Battle readability
- Health bars, faction colors, selection rings, damage feedback, projectile travel, muzzle flash, impact, explosions, smoke, track dust, rotor motion, propellers, and radar contacts.
- Distinguish visual-only showcase behavior from effects driven by real combat events.
- Effects should have bounded lifetime, pooling or reuse where practical, and mobile-safe particle/node budgets.

## 2. Visual language and art direction
- Strategic isometric/oblique camera with strong ground readability.
- Low-poly or optimized 3D assets with consistent scale and clear silhouettes.
- Distinct building silhouettes: command center, barracks, vehicle factory, airfield, shipyard, power plant, supply depot, bunker, turret, anti-air, missile defense.
- Distinct unit silhouettes: infantry, tank, artillery, fighter, helicopter, destroyer, carrier, submarine, landing craft.
- Faction identity comes from original palettes, markings, architecture, and UI motifs; avoid reproducing Zero Hour logos, faction insignia, exact skins, or recognizable proprietary art.
- Environments may include desert coast, forest coast, mountain coast, and coastal city, using original layouts and prop placement.

## 3. Effects and audio reference checklist
### Combat
- Weapon muzzle flash and brief light.
- Projectile/tracer or missile with readable direction.
- Impact spark/dust/water splash according to material.
- Explosion with short-lived fireball, expanding smoke, and debris kept within mobile budgets.
- Damage-state changes and destruction feedback tied to actual health/state.
### Movement
- Tank track dust and wheel/tread motion.
- Infantry gait and squad spacing.
- Aircraft rotor/propeller animation, navigation lights, takeoff/landing state.
- Naval wake, propeller rotation, and water impact.
### Audio
- Separate weapon, impact, engine, aircraft, naval, UI, alert, and ambience buses.
- Avoid one generic sound for every weapon class.
- Use original or properly licensed sound assets; generated procedural placeholders are temporary.
- Provide mute and volume settings, and avoid excessive simultaneous playback on Android.

## 4. Storm Generals project inventory (from current source inspection)
- main.gd is the active 2D gameplay controller and already contains faction definitions, economy constants, campaign mission data, unit/building records, production, battle effects/audio, and a 3D bridge.
- The four player-facing factions are American, Chinese, Arab Army, and Watan.
- Campaign data currently defines five missions and four coastal map themes.
- prototype_3d/battlefield_3d.gd builds a separate Node3D battlefield with terrain, coastal water, roads, base showcase, camera/touch handling, selection/order indicators, radar HUD, placeholder unit visuals, combat presentation, health bars, ground dust, aircraft/naval animation, and procedural audio.
- The 3D script exposes spawn_game_building, spawn_game_unit, and gameplay synchronization paths. These must be checked against actual logical records before extending.
- main.tscn remains the active Node2D scene. prototype_3d/battlefield_3d.tscn is a separate Node3D prototype. Do not claim the game is fully 3D-integrated yet.
- Some 3D models are explicitly placeholders. Replace them progressively with original production-quality assets.
- Health metadata was recently corrected in the 3D unit synchronization path; retain that behavior.

## 5. Integration stages
### Stage A — Reference and audit
- Map every existing logical unit/building type to its 3D visual factory.
- Map gameplay state fields to 3D state: position, facing, faction, health/max health, movement, attack target, construction/production progress, and alive/destroyed state.
- Identify duplicate showcase-only systems and prevent them from being mistaken for live gameplay.
- Record missing data rather than inventing defaults.

### Stage B — Data-driven visual bridge
- Keep main.gd records authoritative.
- Give each 3D counterpart a stable gameplay key.
- Synchronize spawn, despawn, position, rotation/turret facing, faction tint, health, and state.
- Avoid recreating nodes every sync tick; update existing nodes by stable key.
- Ensure building footprints and unit positions use one documented world-coordinate conversion.

### Stage C — Player controls and combat parity
- Verify touch selection and multi-selection against live units.
- Route move/attack/stop commands from 3D input into the existing gameplay order functions.
- Return actual combat damage/state to the 3D presentation; visuals must not independently decide battle outcomes.
- Keep 2D mode available as a fallback until parity is demonstrated.

### Stage D — Art and effects replacement
- Replace placeholders with original optimized meshes/materials.
- Add distinct silhouettes and faction variants.
- Connect weapon, impact, movement, aircraft, naval, construction, and destruction effects to real gameplay events.
- Add effect pooling and quality tiers for mobile performance.

### Stage E — Content and completeness
- Complete faction-specific rosters and buildings.
- Complete campaign/map objectives and rewards.
- Verify land, air, and naval operating areas and map boundaries.
- Implement complete match save/restore, settings, audio controls, and UI feedback.

### Stage F — Validation and release
- Run Godot parse/import checks and headless gameplay tests.
- Test 3D/2D parity, touch gestures, save/restore, and all unit/building types.
- Profile on representative Android hardware: frame time, memory, draw calls, node count, audio voices, and thermal behavior.
- Export and install an Android build only after the above checks pass.

## 6. Acceptance gates
A feature is complete only when:
1. Its logical gameplay state exists and is authoritative.
2. Its 3D representation reflects that state correctly.
3. Its touch interaction issues the intended gameplay command.
4. It survives save/restore where applicable.
5. It passes a repeatable test and does not break the 2D fallback.
6. Its performance is acceptable on the target Android device.

## 7. Immediate next engineering tasks
1. Audit the complete live-unit synchronization function and stable-key lifecycle.
2. Audit building synchronization and placement footprint conversion.
3. Synchronize body facing and turret facing from logical unit records.
4. Confirm every current unit kind maps to the correct 3D visual class; mark missing types explicitly.
5. Connect construction and production progress to live 3D visuals.
6. Separate showcase-only combat from combat driven by the logical game state.

## Legal and production note
Use public gameplay observations and original design analysis. Do not copy proprietary source code, extracted models, textures, maps, animations, music, sound effects, names, logos, or UI artwork. Recreate the underlying ideas with original code and assets or properly licensed resources.