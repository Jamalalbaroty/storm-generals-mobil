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
