# Transport AI Acceptance Matrix

This matrix turns the tactical-director plan into observable gameplay acceptance criteria. It is intentionally separate from the existing transport mechanics regression: the current test suite validates the airlift loop, while these cases define the autonomous decision layer that still needs implementation.

## Decision contract

Every AI decision must return:
- A decision state and reason code.
- A chosen landing/recovery point, or an explicit no-safe-point result.
- A confidence/score breakdown for debugging.
- A timestamp or simulation tick for deterministic replay.
- Whether the decision is advisory or executable under the current player policy.

No decision may silently overwrite a player-issued order.

## Candidate-site scoring contract

Use a deterministic score in the range 0–100. The initial suggested weighting is:
- Threat exposure: 35 points.
- Route exposure: 20 points.
- Distance to objective: 15 points.
- Friendly support proximity: 10 points.
- Landing footprint / occupancy: 10 points.
- Escape and recovery options: 10 points.

Hard rejection conditions take precedence over scores: outside map bounds, invalid building/roof, occupied drop footprint, insufficient room for the requested passenger count, destroyed/hostile landing structure where friendly access is required, or a known lethal anti-air envelope with no viable alternate route.

Tie-break equal scores by shortest safe route, then stable candidate ID. Do not use random tie-breaking in tests.

## Threat levels

- GREEN: no known immediate threat; proceed with the selected route.
- AMBER: threat is present but manageable; prefer cover and friendly support.
- RED: route/site is unacceptable; replan or hold with cargo aboard.
- CRITICAL: transport damage or threat makes mission continuation unsafe; execute recovery behavior.

Threat assessment must use information available to the game simulation. Do not grant the AI omniscient knowledge of hidden enemies unless a difficulty setting explicitly enables it.

## Player policy invariants

### MANUAL
The AI may validate an order and warn about risk, but it must not choose or execute a different destination.

### ASSISTED
The AI may propose a site and route. It must wait for player confirmation before changing the active mission.

### AUTONOMOUS
The AI may select and execute a mission. Any new explicit player command immediately supersedes the autonomous plan.

## Acceptance scenarios

| ID | Setup | Expected observable result |
|---|---|---|
| AIRAI-001 | Two valid sites, one safer | Safer site selected deterministically |
| AIRAI-002 | Equal site scores | Stable tie-break; same result on replay |
| AIRAI-003 | Every site outside bounds | No-site result; cargo remains aboard |
| AIRAI-004 | Rooftop has insufficient footprint | Rooftop rejected |
| AIRAI-005 | Known anti-air threat covers shortest route | Longer safe route selected |
| AIRAI-006 | All routes/sites RED | Transport holds or returns; no forced insertion |
| AIRAI-007 | Threat appears before descent | Site re-evaluated and alternate selected |
| AIRAI-008 | Threat appears during rope descent | No passenger duplication/loss; safe cycle policy followed |
| AIRAI-009 | Passenger has explicit attack order | Existing order preserved after touchdown |
| AIRAI-010 | Passenger has no explicit order | Unique defensive formation slot assigned |
| AIRAI-011 | Player issues new move during autonomous routing | Autonomous route cancelled immediately |
| AIRAI-012 | Player issues new order during insertion | Safe insertion boundary respected; remaining cargo retained |
| AIRAI-013 | Transport health crosses critical threshold | Recovery behavior takes precedence |
| AIRAI-014 | No friendly airfield exists | Transport enters safe hold/idle behavior; no invalid target |
| AIRAI-015 | Save/load during each mission state | State and cargo restored without stale unit indices |
| AIRAI-016 | Repeated 30-minute simulation | No cargo duplication, passenger loss, or permanently stuck state |

## Telemetry required during development

Log state transitions and reason codes, not every frame. Suggested event names:
- `air_ai_assess_started`
- `air_ai_site_rejected`
- `air_ai_site_selected`
- `air_ai_route_replanned`
- `air_ai_insertion_paused`
- `air_ai_player_override`
- `air_ai_recovery_started`
- `air_ai_mission_completed`

Each event should include transport ID, mission ID, simulation tick, policy, state, and reason code. Avoid unbounded logging in release builds.

## Release gate

The tactical AI is not 100% until:
1. Every acceptance scenario above is automated or explicitly marked as a manual device test.
2. Existing transport-airlift regression remains green.
3. Godot headless CI passes.
4. Android device testing verifies touch selection, command override, rope descent presentation, and stable performance.
5. A complete mission can be played in MANUAL, ASSISTED, and AUTONOMOUS modes without losing or duplicating passengers.


## AIRAI-008 implementation note

The automated transport AI regression now covers an immediate hostile tank appearing during rope descent: the aircraft diverts to a candidate outside the threat radius, resets the rope cycle, preserves all remaining cargo, and leaves already deployed ground units untouched. The full acceptance case still requires a separate manual Android presentation check at the release gate.

## Verified CI snapshot — 2026-11-11

Validated development commit: `a1b423c6e3fd43c41420fb894723ddbf2e793883`.

GitHub Actions results for this exact commit:
- Godot Validation run `43071919288` (#806): success.
- Godot Regression Tests run `43071919399` (#729): success.
- The regression workflow completed the gameplay economy/enemy recovery smoke test, transport airlift regression, transport AI landing-site/control-policy regression, combined-arms group formation, coordinated group attack, live 2D-to-3D bridge, and long-match endurance simulation.

The automated coverage now exercises deterministic landing selection and tie-breaking, invalid/occupied sites, threat-aware route/site choices, MANUAL/ASSISTED/AUTONOMOUS authorization, explicit player override, inbound reassessment, critical-damage recovery, no-safe-site cargo preservation, threat response during rope descent, post-drop DEFEND/ATTACK_MOVE behavior, multi-transport rescue and escort assignment/rebalancing, passenger capacity/preservation, rooftop insertion, and airfield return/service.

This CI result verifies the headless scenarios in the checked-in scripts only. It does **not** close every acceptance item above: save/load during each mission state is not demonstrated by this run; visual/touch behavior and performance still require a real Android device; and a complete end-to-end sortie in all three policies still needs manual device verification. Therefore the transport tactical AI is **CI-green, not release-certified or 100% complete**.

## Save/load audit — 2026-11-11

### Current verified state

The current `main.gd` contains `_load_commander_profile()` and `_save_commander_profile()`, backed by `user://storm_generals_profile.cfg`. That file stores career/profile data (battle counts, kills, medals, campaign progress and campaign funds). It is **not** a battle save: it does not capture the live match state.

A targeted scan of the current gameplay smoke and transport regression scripts found no save/load or serialization regression. Therefore AIRAI-015 remains **not implemented / not verified**. Do not describe campaign profile persistence as save-game support.

### Battle snapshot contract before implementation

Persist a versioned match snapshot containing:
- Match identity and phase: schema version, faction, map, campaign mission index, started/paused/result state.
- Economy and objectives: player/enemy credits, supplies, income timers, supply-point ownership, base health, enemy strategy and mission timers.
- World state: player/enemy units, player/enemy buildings, production queues, missiles and any active gameplay objective state.
- Transport integrity: each aircraft's state, passenger manifest (full passenger dictionaries), remaining cargo, target/return positions, route points, policy, doctrine, escort assignments and rescue/pickup mission state.
- Stable identity: persistent unit/building IDs and references by ID; never persist transient array indices as authoritative target references.

Rebuildable presentation state should be regenerated after load, not serialized: audio players/streams, touch/drag ownership, viewport state, transient particles and visual-only effects. Reacquire combat targets from stable IDs or saved focus positions and validate every restored destination against the current map.

### Required safeguards and tests

1. Version the schema and reject unsupported/corrupt snapshots without overwriting the last valid save.
2. Write to a temporary file, verify the write, then replace the active snapshot safely.
3. Validate required keys, value types, collection sizes, unit IDs, cargo capacity, and transport state/cargo consistency before mutating the live match.
4. Restore into a staged state first; commit only after the entire snapshot passes validation.
5. Add round-trip tests for an ordinary ground battle, active production, damaged buildings, a loaded transport, inbound/descending transport with remaining cargo, returning/rearming transport, escorts, and a campaign mission.
6. Add corruption/older-version tests and verify a failed load leaves the current match unchanged.
7. Confirm on Android that saving and loading works across app termination/relaunch and that the restored touch UI remains usable.

**Implementation status:** audit and contract only. No battle save/load code has been added yet, and no persistence test has been claimed as passing. The next engineering task is to implement this contract in small, testable steps, beginning with stable entity IDs and a versioned snapshot codec.

### Stable-identity prerequisite found in source audit

The current source assigns `production_id` to buildings and uses it to reacquire airfield/building references. The unit creation paths inspected do not assign an equivalent persistent unit ID; several live combat/selection paths still refer to units by array index. A safe save-game implementation must therefore introduce and regression-test stable unit identities (including cargo passengers and spawned enemy units) before it can claim robust restoration of cross-unit targets, escort links, or transport manifests. This is a prerequisite, not a cosmetic enhancement.

### Stable unit identity implementation — 2026-11-11

Implemented on development commit `6c389ca15e8ec4b891a142210a914695af48d05f`:
- Added a monotonic `unit_id` allocator for active field units and carried transport passengers.
- The identity pass runs at the start of each gameplay frame, repairs empty/duplicate IDs, and advances the allocator beyond any restored numeric `unit_########` IDs it encounters.
- Added a gameplay smoke assertion covering a transport, a field enemy, and a passenger with colliding initial IDs; it checks that all three end with distinct non-empty identities and that the allocator advances.

GitHub Actions for this exact commit:
- Godot Regression Tests run `43072453872` (#734): success. This includes the gameplay smoke test containing the new identity assertions, plus transport airlift, transport AI, group formation/attack, 2D-to-3D bridge and endurance regressions.
- Godot Validation run `43072452185` (#811): success, including project import, active scene, 3D scene, live bridge, gameplay recovery and endurance checks.

**Scope boundary:** this establishes runtime identity and verifies duplicate repair. It does not yet implement battle serialization, persist the identity counter, replace all array-index target references with ID-based references, or prove IDs survive an application restart. Battle save/load remains incomplete and unverified.

### Battle save/load implementation and CI verification — 2026-11-11

Implemented on commit `4c40adb19f54a354ab52ff138885beb61d9f0fbe`:
- Added `scripts/battle_save_store.gd` with schema version 1, safe Variant serialization (object deserialization disabled), temporary-file write, read-back verification, backup promotion, and recovery from a verified backup when the primary file is missing or invalid.
- Added validation for schema version, required state arrays, unit/passenger identity uniqueness, unit core fields and Vector2 positions, and the eight-passenger transport capacity. Rejected snapshots leave the previous valid save intact.
- Integrated `_build_battle_snapshot()`, `_save_battle_snapshot()`, and staged `_load_battle_snapshot()` into `main.gd`. The snapshot includes both economies, supply ownership, base health, unit/building arrays, production orders, active missiles, transport state/cargo, and identity counters.
- Added mobile command-deck actions `حفظ المعركة` and `استعادة المعركة` in the strategy tab. The three-row layout preserves 44px touch targets and has viewport-fit assertions for common phone sizes.
- Added storage round-trip, invalid-save preservation, backup-recovery, and live-scene restore integration tests.

GitHub Actions for this exact commit:
- Godot Regression Tests run `43073552882` (#750): success. Both new battle save tests and the updated mobile command-deck geometry assertions passed, along with the full existing regression suite.
- Godot Validation run `43073552614` (#827): success.
- Android APK export was skipped as required by the 80% release gate.

### Remaining release gates

- Battle snapshot save/restore is manually triggered from the strategy command tab; autosave and multiple save slots are not implemented.
- The current schema is version 1; migration from future schemas is intentionally rejected. Cross-version migration has not been implemented.
- Android device testing across app force-stop/relaunch, low-storage conditions, and real touch interaction remains outstanding. CI headless tests do not replace device certification.
- The snapshot keeps unit-array order so legacy array-index combat references remain consistent at restore time; a full conversion of all live target/escort references to stable IDs remains future work.

This implementation is CI-green for the covered headless scenarios, but it is not yet a complete mobile release certification.

### Battle snapshot storage and gameplay integration — 2026-11-11

Implemented on development commit `1db6f2a1175121741ef8fb237dec2e311d66eb22`:
- Added versioned battle snapshot storage under `user://storm_generals_battle.save`, using a verified temporary payload, backup promotion, and recovery from the last verified backup.
- Integrated save and staged restore into the live gameplay scene and exposed both actions in the mobile Strategy command tab.
- Snapshot includes faction/map/campaign state, both economies and bases, supply ownership, stable-ID units and transport manifests, both building arrays, production orders, active missiles, and the enemy missile attack timer.
- Restore validates and stages the snapshot before replacing live arrays; transient UI selection, touch state, particles, and audio are intentionally rebuilt/reset rather than serialized.
- Regression coverage includes round-trip storage, corrupt/unsupported/duplicate-ID rejection, backup recovery, and a live-scene save/restore integration covering transport cargo and enemy missile cadence.

GitHub Actions for this exact commit:
- Godot Regression Tests run `43074102799` (#752): success; all regression steps completed, including battle save store and live gameplay save/restore integration.
- Godot Validation run `43074102637` (#829): success; project import, active scene, isolated 3D battlefield, live bridge, gameplay recovery, and endurance checks completed.
- Android APK export remained skipped, as requested until the overall project reaches the separately verified 80% threshold.

**Remaining release gates:** real Android device touch/performance and app-close/relaunch verification are not covered by headless CI. The save schema currently captures the defined match state; it still needs a device lifecycle test before being treated as release-ready.

### Mobile lifecycle autosave — 2026-11-11

- Active battles now save synchronously on Godot `NOTIFICATION_APPLICATION_PAUSED` (Android background/interruption) and `NOTIFICATION_WM_CLOSE_REQUEST` (desktop close). Finished or not-yet-started matches are not autosaved by this hook.
- Added a regression that changes the live economy, dispatches the application-paused notification, deliberately mutates the in-memory state, then reloads and verifies the autosaved value.
- GitHub Actions on commit `d372d3753f2a68ff3b011602d35133531f3fa5fa`: Regression run `43074404381` (#754) success, including lifecycle autosave integration and all existing transport/formation/attack/endurance tests; Validation run `43074404520` (#831) success.
- APK export remained skipped. CI notification simulation is not a substitute for verifying actual Android process termination/relaunch on a physical device.

### Battle-save recovery and transport lifecycle regression — 2026-11-11

- Expanded the save-store regression to retain a known-good backup while writing a deliberately truncated/corrupt primary payload, then verify recovery promotes the backup back to the primary path.
- Expanded live-scene save/restore integration coverage across transport `inbound` flight, `descending` rope deployment, `returning` to base, `loaded` standby, and `idle` after a passenger leaves the cargo manifest as a field unit. Destination, route points, drop index, cargo manifest, and passenger identity are asserted.
- The first corruption fixture failed because it had already consumed the backup during the preceding missing-primary recovery check. The fixture was corrected to recreate the backup+corrupt-primary layout before testing fallback; no production save-store logic change was needed for that test-fixture failure.
- Corrected code/test commit `7788d3440a3685dec2d6cdaf338ea88db09dd0c3`: Regression #758 success and Validation #835 success. Android APK export remained skipped.

### Snapshot validation and stable unit identity hardening — 2026-11-11

- Snapshot validation now rejects non-finite numeric values and coordinates, negative unit/building/base health or economy balances, malformed building progress, invalid production queue timing/producer references, and malformed missile state before persistence.
- Added regression cases for NaN unit health, infinite unit position, negative building health, out-of-range build progress, NaN production duration, and NaN missile target. The valid production-order fixtures now include producer position and kind as required by the live schema.
- Stable identity assignment now reserves all existing field-unit and passenger IDs before generating missing IDs. This prevents an earlier unassigned spawn from taking an ID already owned by a later unit. Added coverage for ID preservation and array compaction after a unit is removed.
- Final tested code commit `63550d9f69eaa6da3c0be14395e42cf90c80f9ec`: Regression #764 success and Validation #841 success. All regression steps passed, including save-store, live save/restore, transport lifecycle, formations, coordinated attacks, 2D/3D bridge, and endurance. Android APK export was skipped as required.
- An earlier validation attempt exposed an incomplete test fixture (missing producer position); the fixture was corrected and the full suite passed on the final tested commit.

### Battle outcome and campaign accounting regression — 2026-11-11

- Added live-scene regression coverage for immediate victory resolution when the enemy base reaches zero HP and defeat resolution when the player base reaches zero HP.
- Verified victory increments battles played and victories once, unlocks the next Watan campaign mission, and grants the first mission reward plus its secondary-objective bonus (350 credits total).
- Verified repeated victory resolution does not duplicate career statistics or campaign rewards; repeated defeat resolution does not duplicate defeat statistics.
- Verified defeat does not advance campaign progress or award campaign funds. The test restores the pre-test commander profile after assertions.
- Tested code commit `2a64a0eed886655e29582ca1ce83e43a40869b15`: Regression #766 success and Validation #843 success. All regression steps passed, including battle save/restore, transport, combined-arms, coordinated attacks, 2D/3D bridge, and endurance. Android APK export remained skipped.
