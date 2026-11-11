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
