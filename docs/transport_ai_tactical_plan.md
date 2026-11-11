# Transport Airlift Tactical AI — Implementation Plan

## Goal
Complete the transport-helicopter airlift loop with a deterministic, player-overridable tactical director. AI assists with reconnaissance, landing-site selection, insertion, post-drop squad behavior, and extraction; explicit player orders always take priority.

## Existing implementation baseline
The current Godot gameplay code already supports:
- Loading up to eight infantry while preserving passenger records and upgrades.
- Player-directed transport movement and rooftop/ground insertion.
- Sequential rope deployment with blocked-drop retry behavior.
- Passenger fire from the transport, with player focus taking priority.
- Target reacquisition from saved world positions after unit-array changes.
- Automatic return to the nearest completed airfield after a successful drop.
- Headless regression coverage for capacity, passenger preservation, focus priority, descent safety, rooftop insertion, and return-to-airfield.

These are implemented mechanics, not proof that the tactical AI is complete.

## Tactical director state machine
1. IDLE — wait for a player order or enabled autonomous policy.
2. ASSESSING — inspect cargo, landing candidates, known threats, and mission intent.
3. ROUTING — choose a safe route and approach point.
4. INBOUND — fly to the landing point while monitoring threats.
5. INSERTING — deploy passengers sequentially; pause or abort if the site becomes invalid.
6. SECURING — assign post-drop roles and squad rally positions.
7. EXTRACTING — return to a valid friendly airfield or player-designated recovery point.
8. ABORTED — preserve cargo, report the reason, and permit replanning.

## Landing-site scoring
Score candidate ground and rooftop locations using:
- Threat exposure and known anti-air coverage.
- Distance from objective and friendly support.
- Landing-space capacity and collision/occupancy checks.
- Rooftop/building validity and ownership/access constraints.
- Route exposure and escape-path availability.
- Mission type: assault, defensive reinforcement, or silent insertion.

Reject invalid candidates before ranking. If no acceptable point exists, keep passengers aboard and request a new order.

## Threat response
- Re-evaluate route and landing point at bounded intervals, not every frame.
- Before insertion, divert when threat rises and a safer alternate exists.
- During descent, never teleport or discard passengers; complete only a safe active rope cycle.
- If critically damaged, prioritize a viable recovery point.
- Never send an empty or destroyed transport into insertion.

## Passenger behavior after touchdown
- Preserve explicit player attack, guard, and movement orders.
- Without an explicit order, form a defensive perimeter around the landing point.
- Assign distinct cover positions; avoid stacking passengers.
- Reacquire enemies by saved world position, never stale array indices.
- Choose defend, regroup, or withdraw using local threat and squad health.
- Permit player override at every stage.

## Player control policies
- MANUAL: execute player orders only.
- ASSISTED: recommend landing point and route; player confirms.
- AUTONOMOUS: execute the plan, while explicit player commands always take priority.

Expose the selected policy in the transport selection panel and persist it in game settings.

## Regression gates for 100%
1. Deterministic landing-site ranking for equal inputs.
2. Invalid or occupied rooftop rejection.
3. Anti-air threat changes route or landing point.
4. No safe landing preserves all passengers aboard.
5. Threat increase during descent never loses or duplicates passengers.
6. Passenger formation slots remain unique and inside the playable map.
7. Player attack/guard/move orders survive insertion.
8. Autonomous post-drop behavior chooses defend/regroup/withdraw from fixtures.
9. Player override replaces every autonomous order.
10. Damaged transport chooses viable recovery; no airfield produces safe hold/idle.
11. Save/load preserves policy and mission state without stale target indices.
12. Long-match simulation detects no cargo duplication, passenger loss, or stuck transport states.

## Completion rule
Declare 100% only after all required tests pass in Godot headless CI and the full airlift loop is manually verified in an Android build on a real device. Report design readiness and implementation/test coverage separately; never mark unimplemented behavior complete.

## Implemented first slice — deterministic site evaluation

The development branch now contains `_transport_ai_evaluate_landing_site` and `_transport_ai_choose_landing_site` in `main.gd`. The evaluator rejects out-of-bounds ground/roof points, unresolved rooftops, blocked ground footprints, and occupied landing footprints; it ranks remaining candidates using known anti-air exposure, route midpoint exposure, objective distance, nearby friendly support, and escape margin. Equal score/distance candidates use a stable site-ID tie-break. A focused headless test script was added at `tests/transport_ai_landing_site_test.gd`.

This is a reusable decision primitive only. It is not yet wired to MANUAL / ASSISTED / AUTONOMOUS mission execution, route movement, periodic threat replanning, or the transport UI. The new test has been authored but has not been executed in this environment; do not count it as passing until CI or a local Godot run confirms it.

## Implemented second slice — live-map candidate generation

`main.gd` now includes `_transport_ai_build_landing_candidates(objective_pos)` to create a deterministic grid of ground candidates inside the safe map bounds and rooftop candidates from completed, living non-wall structures. `_transport_ai_plan_landing(objective_pos)` evaluates that set and returns the best valid destination using the existing deterministic scorer. The landing-site regression script now also checks that candidate generation and planning return a complete valid destination on a normal map.

This remains a planning primitive: it does not yet launch or redirect a transport, and it does not replace the player's explicit manual landing command. Automated candidate generation and scoring must be run through Godot headless before being considered verified.


## Implemented third slice — broader threat sampling

The landing evaluator now samples the approach corridor at 25%, 50%, and 75% rather than relying on one midpoint. It also applies a distance-weighted penalty for nearby living enemy mobile units, with heavier weights for armor, artillery, and aircraft. The regression script includes a case that verifies the planner prefers a site outside a nearby hostile tank's threat radius. This remains unverified until the Godot headless test is run; it still does not issue transport movement orders or provide the player policy UI.


## Implemented fourth slice — player-priority decision contract

Added a pure decision layer for transport landing recommendations. The mode is read from `transport_ai_mode` and accepts MANUAL, ASSISTED, and AUTONOMOUS; absent or invalid values safely fall back to MANUAL. Empty cargo and missing safe sites are rejected. MANUAL returns manual_control, ASSISTED returns a recommendation without execution permission, and AUTONOMOUS may authorize a planned landing. The explicit `transport_ai_player_override` flag always blocks autonomous authorization. This helper does not move aircraft, alter existing targets, or replace the current manual landing command path. Regression coverage was added for all modes, the default, empty cargo, and player override. Godot execution remains pending.


## Implemented fifth slice — autonomous request reaches the transport state machine

Added `_transport_ai_request_landing` as the tactical-director entry point and `_transport_ai_process_pending_landing` as the state-machine bridge. MANUAL and player-override requests are rejected without changing transport state. ASSISTED stores and returns a recommendation while leaving the aircraft loaded and stationary. AUTONOMOUS queues an assessment; the next transport update re-evaluates the landing against the live battlefield and, only when still authorized, writes the selected landing target and transitions to the existing inbound flight state. The established inbound/rope-drop/return flow remains the execution path. Added regression cases for manual rejection, assisted recommendation-only behavior, autonomous transition to inbound, and player override. This is code-level integration; Godot CI and in-game Android validation remain outstanding.


## Player override lifecycle

Explicit player landing orders now mark the current sortie as player-overridden and discard stale AI recommendations. Cancelling a transport task also clears queued AI objectives and blocks an immediate autonomous restart. Loading a fresh group of passengers resets that sortie-scoped override, allowing a later tactical-director request to be considered. This preserves player authority without permanently disabling autonomy for future sorties.


## Landing clearance correction

The live unit-occupancy filter now ignores friendly transport helicopters while checking landing footprints. This prevents a transport from treating its own current hover position as an occupied ground landing zone during tactical planning. A regression case was added for a friendly transport hovering exactly over a candidate site. Other friendly ground units and hostile units continue to block the landing footprint.


## CI feedback and correction

The first Godot 4.4 regression run confirmed project import and the existing economy, gameplay-smoke, and transport-airlift suites, but the new AI test was rejected by strict Variant-inference warnings on two local variables. Those variables are now explicitly typed as `Dictionary`. The dedicated AI regression suite must be rerun on the corrected commit before this slice is considered validated.


## Implemented sixth slice — in-flight landing reassessment

Autonomous transports now re-evaluate their landing site every 1.25 seconds while inbound, provided the aircraft remains more than 80 pixels from touchdown and no player override is active. The evaluator checks the current destination against live occupancy and threat conditions, then compares it with a fresh plan. It switches targets only when the current site becomes invalid or the alternative scores at least 14 points better and is meaningfully separated, avoiding constant oscillation. Rooftop/ground metadata is updated together with the target. The objective is retained during flight and cleared when insertion completes or the task is cancelled. A regression case places a hostile tank on the current landing footprint and verifies the transport chooses a new site. Godot CI validation for this slice is pending.


## Implemented sixth slice — threat-aware autonomous waypoint routing

Autonomous transport sorties now compare a direct flight corridor with four deterministic lateral detours. Each candidate route is sampled along its segments and scored against known living enemy anti-air buildings; route distance adds a small tie-breaking cost so a clear battlefield retains the direct route. The selected waypoint sequence is stored on the transport and consumed by the existing inbound movement loop. If landing-site reassessment changes the destination, the route is rebuilt from the aircraft's current position. Manual player-directed sorties do not receive or follow these AI waypoints.

Regression coverage compares direct and detour exposure around a known anti-air battery and verifies that an unobstructed route remains direct. This code and test have been committed, but this slice must not be marked verified until the GitHub Actions run completes. The route planner is intentionally a first tactical layer: it currently models known anti-air buildings, not terrain occlusion, moving threat prediction, or full graph-based pathfinding.


## Implemented seventh slice — autonomous post-drop squad doctrine

When an AUTONOMOUS transport deploys a passenger who has no pre-existing player order, the passenger now receives the existing infantry guard stance anchored to the landing zone, with a 155-pixel defensive radius. This reuses the game's established guard/combat behavior instead of introducing a parallel combat system. Existing movement, attack, capture, attack-move, or guard orders are preserved and bypass the doctrine. MANUAL and ASSISTED sorties retain the previous formation-rally behavior. The doctrine is configurable per transport through `transport_ai_post_drop_doctrine`; the initial supported default is `DEFEND`.

Regression coverage verifies defensive stance assignment, landing-zone anchoring, radius, preservation of a pre-existing movement order, and no automatic doctrine in MANUAL mode. Godot execution is still required before this slice can be called validated.

## Implemented eighth slice — objective-directed post-drop attack-move

AUTONOMOUS transports may now set `transport_ai_post_drop_doctrine` to `ATTACK_MOVE`. Unassigned passengers then receive the saved sortie objective as their movement target and activate the game's existing attack-move combat loop, which searches for nearby hostile units/buildings while advancing. The doctrine safely declines when no objective was retained, allowing the established formation-rally fallback. DEFEND remains the default. Existing player orders are checked before any doctrine state is changed.

Regression cases cover activation, objective targeting, and the missing-objective fallback. These are authored tests only; Godot headless CI and Android gameplay validation remain pending.


## Implemented ninth slice — selected transport command panel

A compact touch panel is now shown when the player selects one or more friendly transport helicopters. It exposes a cycle button for MANUAL → ASSISTED → AUTONOMOUS → MANUAL and a post-drop doctrine toggle between DEFEND and ATTACK_MOVE. The panel writes settings to the selected aircraft records; it does not silently launch a sortie.

Safety locks prevent changing the control mode while a transport is inbound, descending, or assessing a landing, and prevent changing post-drop doctrine unless the aircraft is idle or loaded. Selection is restricted to player-owned transport helicopters. Regression tests cover visibility eligibility, mode/doctrine persistence, and both in-flight locks. These tests are authored but still require a successful Godot CI run and Android touch-device validation.


## Implemented tenth slice — physical boarding and extraction safety

The manual reload interaction now enforces battlefield proximity and aircraft state. A transport can accept selected infantry only while idle or already loaded, and only when each passenger is within 76 world units of the landed aircraft. Airborne, inbound, descending, and landing-assessment transports reject boarding without removing infantry from the battlefield. Capacity remains eight; selected troops outside pickup range remain in the field. Regression coverage checks nearby boarding, distant-unit preservation, and rejection while inbound. Godot CI and Android playtesting remain pending.


## Implemented eleventh slice — infantry rendezvous for extraction

When the player issues boarding with a landed transport and selected infantry outside pickup range, the infantry now receive deterministic movement targets around the aircraft inside the 76-unit boarding radius. They remain on the battlefield and keep their normal movement behavior; the player confirms boarding again after they arrive. The command still rejects airborne/descending transports, and actual boarding still enforces the eight-soldier capacity. Regression coverage checks that distant infantry receive a rendezvous target without being removed. Automated Godot execution and Android playtesting are still pending.


## Implemented twelfth slice — wounded-first extraction and rendezvous correction

Boarding selection is now ordered by ascending current health, so the most wounded selected infantry are evacuated first when aircraft capacity is limited. A code review also found and corrected a rendezvous-list handling error: the nearby-only subset had replaced the full selected squad before rendezvous orders were assigned. The full squad is now preserved separately, so distant infantry actually receive their movement targets. Regression tests cover rendezvous movement and wounded-first boarding. Godot execution and device validation are still pending.


## Implemented thirteenth slice — recall transport to a field squad

The airlift command tab now includes a pickup-recall action. With one player transport and one or more player infantry selected, the command computes the squad rendezvous center, asks the existing tactical landing planner for a safe nearby ground/rooftop site, assigns an anti-air-aware route, and dispatches the empty aircraft. On landing it settles into the existing idle state; the player then moves the squad within boarding range and confirms loading. The order rejects multiple transports, missing infantry, occupied cargo, busy aircraft, and unavailable safe landing plans. A regression test covers dispatch state, landing target, and route assignment. This is a player-confirmed extraction workflow, not automatic pickup or automatic boarding. Godot execution and Android validation remain pending.


## Implemented fourteenth slice — pickup rendezvous hold state

A transport recalled for field extraction now carries an explicit pickup-wait marker. When it reaches the planned landing site empty, the descent/update loop transitions it to `pickup_waiting` and holds position instead of dropping into ordinary `idle`. The boarding command accepts this landed waiting state; successful boarding clears the marker and returns the aircraft to `loaded`. Manual landing orders and cancellation clear stale pickup state. Regression coverage checks the waiting transition, boarding from the waiting state, cargo transfer, and marker cleanup. This remains player-confirmed boarding; no automatic squad pickup has been introduced. CI and Godot/device execution results are pending.


## Implemented fifteenth slice — clear temporary pickup movement on boarding

Infantry sent to the aircraft by the extraction rendezvous command now carry a dedicated temporary-order marker. When they board, that temporary movement target is removed from the cargo record so the soldiers do not resume walking back to the pickup point after a later redeployment. Other pre-existing player movement/combat orders remain preserved. A regression assertion covers this cleanup alongside the pickup-wait boarding flow. Runtime validation is pending.

## Implemented sixteenth slice — player-directed return to friendly base

The airlift command panel now includes a separate **عودة إلى القاعدة** action. It accepts exactly one selected player transport with passengers and only while the aircraft is landed/available. The command searches completed, living friendly airfields in the player's building collection, chooses the nearest, and refuses safely when none exists; enemy airfields are never candidates. It preserves the cargo and assigns the existing anti-air-aware waypoint route. The returning state now follows those waypoints and transitions back to loaded at the airfield. Arrival does not unload passengers: the player retains control and may issue a later deployment order.

Regression assertions were added for a valid return, friendly-versus-enemy airfield selection, route assignment, passenger preservation, and safe rejection when no friendly airfield exists. These tests are authored only; Godot execution, CI, and Android touch/gameplay validation remain outstanding.

## Implemented seventeenth slice — powered-airfield recovery routing

Manual and automatic transport recovery now share one nearest-friendly-airfield selector. It only considers completed, living airfields in the player's own building collection that pass the existing power-allocation check. This prevents a transport from treating an unfinished, destroyed, or unpowered airfield as a valid recovery destination. Automatic return after the final passenger drop now also assigns the existing anti-air-aware waypoint route instead of switching to a direct unplanned flight. The regression fixture includes a closer unfinished airfield and a destroyed airfield and verifies that the valid friendly destination is selected over those invalid candidates and an enemy airfield. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented eighteenth slice — in-flight recovery destination validation

A returning transport now validates its selected airfield against the live friendly building list and current power allocation. If that airfield is destroyed, unfinished, or loses power, the transport replans to the nearest remaining valid friendly airfield and rebuilds its threat-aware route. If no valid recovery field remains, it stops the return mission safely, returns to a landed/available state, and retains every passenger rather than continuing toward an invalid destination. A regression case destroys the original destination during flight and checks that the aircraft retargets the alternate powered field without losing cargo. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented nineteenth slice — Zero Hour-style transport servicing

When a transport reaches a valid friendly airfield, it now enters a dedicated `rearming` service state instead of becoming immediately available. The aircraft remains parked for a five-second service cycle, preserves its entire passenger manifest, and restores its health before returning to `loaded` or `idle`. The service state continuously verifies that the airfield is still completed, alive, friendly, and powered; if the field becomes unavailable, service is aborted safely and cargo remains aboard. This mirrors the familiar airfield turnaround loop from Generals/Zero Hour while keeping passenger deployment under player control. Regression assertions cover service entry, cargo retention, repair completion, and readiness for the next sortie. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twentieth slice — mobile-air threat-aware transport routing

The transport route exposure model now evaluates living enemy fighters and helicopters along each sampled route segment in addition to static anti-air batteries. Fighters receive a higher interception-risk weight and a wider threat radius than hostile helicopters; enemy mobile units represented as `anti_air` also contribute a ground-based threat envelope. The existing deterministic direct-versus-detour planner therefore considers mobile air patrols when assigning routes for autonomous transport flights and returns. Regression assertions place an enemy fighter over the direct corridor and verify that its exposure is detected and a lateral detour is safer. This is route-risk avoidance, not a full escort command or combat simulation; escorts and active defensive engagement remain future work. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-first slice — fighter and helicopter transport escort

The 3D gameplay command bridge now accepts fighter and helicopter escort orders, in addition to the existing tank escort role. Escort aircraft can be assigned to a friendly artillery unit or transport helicopter by its stable 3D sync ID. While attached, a fighter screens nearby hostile aircraft and a helicopter engages nearby ground threats; both return to their saved formation offset when no escort-area threat is present. Automatically acquired escort targets are tracked separately so they can be released when they leave the protected unit's 220-unit defense radius, and a destroyed or missing escort target cancels the escort stance cleanly. Explicit player attack orders continue to replace escort duty through the existing command bridge. Regression tests cover assignment, stable target identity, stale-order replacement, and rejection of a destroyed transport. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-second slice — atomic multi-transport recovery

The return-to-base command now accepts one or more selected loaded player transport helicopters. Before changing any unit, it validates every aircraft's cargo, task state, and access to a living, completed, powered friendly airfield. If any aircraft fails validation, the whole group order is rejected without partially dispatching the others. Once validated, each transport independently chooses its nearest eligible friendly airfield and receives the existing anti-air-aware route; passenger manifests remain aboard. Regression assertions cover two transports choosing different nearest airfields, both receiving routes, and cargo preservation. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-second slice — coordinated multi-transport ground insertion

When multiple player transport helicopters have a pending landing order and the player clicks a ground area, the group planner now reserves a distinct safe ground site for each aircraft before dispatching any of them. Candidate sites must be within 240 world units of the requested area, pass the existing landing safety/threat evaluation, and remain at least 96 units from every site already reserved for this group. If the planner cannot find a complete set, no aircraft is dispatched. A single-transport order keeps the existing exact-point/rooftop behavior. A multi-transport click on one rooftop is rejected with guidance rather than stacking aircraft on the same roof. Regression assertions cover three transports, distinct landing positions, and inbound state. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-second slice — automatic air escort assignment for transport groups

When a player issues a coordinated ground insertion to multiple selected transports, selected living player fighters and gunships are now assigned to protect the nearest transport in that group. Assignment uses each transport's stable 3D sync ID, balances escort counts with a distance penalty, preserves a bounded formation offset, cancels aircraft recovery before taking escort duty, and clears stale movement/combat/patrol orders. The existing escort combat behavior then handles interception and returns the aircraft to its protected transport. Escorts are assigned only after the group insertion plan succeeds, so a failed landing plan does not disturb their previous orders. Regression assertions cover nearest-transport assignment for a fighter and gunship and stale movement cleanup. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-second slice — deterministic escort formation slots

Automatic transport-group escort assignment now gives each aircraft a deterministic protective slot around its assigned transport instead of preserving an arbitrary arrival position. The first four slots form a staggered forward/side screen; additional escorts use separated rear reserve rows. Each aircraft stores its slot index and current assigned formation size, while the existing escort movement/combat loop follows the stored offset and resumes station after interception. Regression coverage checks that two escorts protecting one transport receive different slots and offsets, while the escort distribution remains attached to the nearest transport. Tests are authored only; execution and CI validation remain pending.

## Implemented twenty-second slice — unified manual and automatic escort formations

Manual escort orders issued through the 3D command bridge now use the same deterministic formation-slot layout as escorts assigned automatically during a multi-transport insertion. The bridge counts living escorts already attached to the same stable target ID, places the new aircraft in the next open slot, and updates the formation-size metadata for all living members. This prevents manually assigned fighters and gunships from converging on the same saved offset. Regression assertions cover two manually assigned aircraft receiving distinct slots and offsets and a synchronized formation size. Tests are authored only; Godot execution, CI, and Android validation remain pending.

## Implemented twenty-second slice — escort recovery after transport loss

Air escorts assigned to a transport now retain the protected target kind and can recover automatically if that transport is destroyed or otherwise disappears. A surviving fighter or gunship searches living friendly transports, chooses the nearest candidate with a load-balancing penalty for transports that already have escorts, and joins the next deterministic formation slot. The replacement formation size is synchronized across its living members, and stale automatically acquired combat targets from the lost transport are cleared. This recovery is deliberately limited to escorts whose recorded protected target was a transport; escorts assigned to artillery are not silently redirected. Regression assertions cover nearest replacement selection, free-slot allocation, stale-target cleanup, and formation-size synchronization. Tests are authored only; Godot execution, CI, and Android validation remain pending.


## Implemented twenty-second slice — compact escort formations after losses

Air escort formations now have a shared synchronization helper that rebuilds the living members' deterministic slots, offsets, and formation-size metadata for a protected target. Manual escort assignment and automatic reassignment after transport loss both invoke the helper, so a destroyed or detached escort cannot leave a permanent gap in the formation when the next aircraft joins. The helper ignores dead, non-player, and detached units and preserves the existing stable target ID model. Regression assertions cover slot compaction, updated formation size, and restoration of the deterministic offset. Tests are authored only; Godot execution, CI, and Android validation remain pending.


## Implemented twenty-second slice — adaptive escort formation catch-up

Air escorts now use a bounded distance-based catch-up speed while returning to their assigned moving formation slot. The base speed remains unchanged inside the normal formation tolerance; speed increases progressively with separation and is capped at 1.4x the unit's own base speed. Fighter and gunship movement retain their distinct base speeds. Regression assertions cover acceleration beyond the formation tolerance and the upper speed cap for both aircraft classes. Tests are authored only; Godot execution, CI, and Android validation remain pending.
