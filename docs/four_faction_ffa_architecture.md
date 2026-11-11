# Four-Faction Free-for-All Architecture Plan

## Status and guardrails

This document describes the implementation boundary for a future four-faction free-for-all (FFA) battle. It is not a claim that FFA is implemented. The current playable battle remains the existing player-versus-enemy mode.

- Preserve the existing two-side mode and its save compatibility throughout the migration.
- Keep faction identity (American, Chinese, Arab, Watan) separate from team identity and diplomacy.
- Keep naval gameplay disabled; the FFA work covers land and air only.
- Do not change faction balance values as part of the structural migration.
- Add each phase behind tests before switching any production gameplay path.

## Current architecture observed in `main.gd`

The current match state is organized around two fixed sides rather than an arbitrary number of factions:

- `units` is a shared unit array, but combat queries compare `unit.team` directly with the literal values `player` and `enemy`.
- Buildings, construction, production, power, and base health are split into `buildings` / `enemy_buildings`, `credits` / `enemy_credits`, and `player_base_hp` / `enemy_base_hp`.
- Enemy AI has a single scheduler and a single strategy state (`enemy_timer`, `enemy_strategy`).
- Helpers such as `_nearest_player_unit`, `_nearest_enemy_unit`, and `_nearest_enemy_ground_unit` encode the two-side relationship directly.
- `faction` and `_enemy_faction()` choose faction profiles independently of the two-side storage model. This distinction should be retained.

These constraints mean that adding two more faction labels to the existing team field would not create a correct FFA battle. It would leave targeting, base ownership, economy, production, AI turns, and victory checks incomplete.

## Target model

Introduce a match-level team registry. Each team record should own at least:

- Stable `team_id` (not array position), faction identifier, and display/player-controller type.
- Base position, base health, and base-destruction state.
- Credits, income accumulator, supplies, and supply capacity.
- Owned building IDs and production queues.
- AI strategy, decision timer, and difficulty profile (or a human controller).
- Diplomacy/relationship data used by target selection.

Units and buildings should store a stable `team_id`. Faction remains a separate field used only for unit stats, visuals, and faction-specific rules. A team's identity must not be inferred from its faction: two teams may eventually select the same faction in custom matches.

## Targeting and combat rules

1. Add one authoritative hostility query, e.g. `_are_teams_hostile(source_team_id, target_team_id)`, backed by the match diplomacy matrix.
2. Build generic target queries around source team and hostility rather than `player` / `enemy` literals.
3. Preserve role filters: air-only, ground-only, submarine detection (if naval is ever re-enabled), retreat state, range, and existing target-priority scoring.
4. Preserve landing-craft protection priority and existing aircraft target-score/range behavior during the initial migration.
5. Remap attack targets by stable unit ID when units are removed; do not rely on array indexes across frames.
6. Ensure defensive buildings only target hostile teams and never friendly or neutral teams.

## Economy, ownership, and production

Move player/enemy duplicated fields behind team-owned state accessors. Every economy tick, supply update, construction update, power allocation, production queue, and reinforcement limit must receive an explicit team ID. Production orders must remain associated with the owning team's producer IDs. Capturing a building must transfer ownership and its future production/power attribution atomically.

## AI scheduling

Replace the single enemy timer/strategy with one AI controller state per AI-controlled team. Each AI turn must:

- Assess threats from all hostile teams, not just the human player.
- Protect its own base and strategic installations.
- Select targets using diplomacy and tactical priorities.
- Avoid treating other AI teams as allies unless diplomacy says so.
- Use deterministic seeded decisions in regression tests.

## Victory and match lifecycle

Replace the two-base conditional with a living-team evaluation. FFA victory occurs when one hostile team remains (or when the selected game mode's explicit victory rule is met). Simultaneous base destruction must resolve deterministically. Draws and eliminated teams must be represented in the battle result and post-match statistics.

## Save compatibility

Introduce a versioned team-state section in battle saves. A migration layer must read existing two-side saves and map the legacy player/enemy records into two team records without losing unit IDs, buildings, production orders, resources, base health, or faction selection. Keep the old save fixture in regression coverage until migration is proven.

## Implementation sequence

### Phase A — characterization tests (no gameplay behavior changes)
- Inventory every player/enemy literal and every duplicated economy/base field.
- Add regression fixtures that lock current two-side targeting, damage, production, capture, save/restore, and victory behavior.
- Add helper-level tests for hostility matrices, stable team IDs, and faction/team separation.

### Phase B — team registry and compatibility adapter
- Add team registry data structures and lookup/accessor helpers.
- Populate two team records from the current match setup.
- Keep legacy fields synchronized through a narrow adapter; do not change the UI or combat behavior yet.
- Prove old saves load and round-trip unchanged.

### Phase C — generic combat and ownership
- Migrate target selection, attack orders, defensive targeting, building ownership, and capture to team IDs.
- Keep a two-team diplomacy matrix and prove parity with existing behavior before allowing more teams.

### Phase D — per-team economy and AI
- Migrate resources, production, power, supply, construction, base state, and AI scheduler.
- Add two-team parity tests and multi-AI deterministic tests.

### Phase E — four-team FFA enablement
- Add four-team map placement, team selection, diplomacy defaults, independent AI turns, and living-team victory resolution.
- Run all six faction pairings plus four-team land/air endurance and save/restore scenarios.
- Enable the mode only after the full regression suite passes.

## Acceptance criteria

- Existing two-side campaign/skirmish behavior and saves remain compatible.
- Four teams can independently build, produce, earn income, consume supplies, capture assets, issue orders, and fight all hostile teams.
- No unit attacks its own team or a diplomatic ally.
- Faction bonuses follow faction identity regardless of team slot.
- Watan retains its deliberate combat advantage and higher land/air reinforcement costs; no balance values are silently altered.
- Four-team FFA uses only land and air while naval systems remain paused.
- Tests prove actual simulated team interactions; stat tables alone do not count as an FFA simulation.
