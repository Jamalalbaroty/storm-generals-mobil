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
