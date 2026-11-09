# Storm Generals — Development Plan

## Product direction
A mobile real-time strategy game inspired by classic modern-warfare base-building games. The first goal is a stable, playable Godot Android prototype, not a collection of disconnected features.

## Prototype 0.1 scope
- Main menu and faction selection: American, Chinese, Arab Army, and وطن.
- A compact battlefield with a player base, enemy base, resource points, and clear touch controls.
- Build menu and construction placement with validation (range, occupancy, and cost).
- Economy loop: earn/spend resources; show balances and costs in the HUD.
- Unit production: infantry and tanks, with production queues and clear feedback.
- Select units by touch; issue move and attack orders; support basic group selection.
- Enemy AI: gather resources, build a small force, defend its base, and attack when ready.
- Win/loss conditions, pause, restart, and a short tutorial.
- Android-safe UI scaling, performance limits, and save/settings basics.

## Faction identity
All four factions share the same core rules and readable counter system. Their differences should be expressed through unit statistics, costs, production time, and a small number of signature abilities—not unfair advantages.

- American: flexible combined-arms toolkit.
- Chinese: disciplined production and defensive efficiency.
- Arab Army: mobile pressure and cost-effective forces.
- وطن: elite technology and powerful specialist units, balanced by higher costs, slower reinforcement, and resource dependence.

## Core combat rules
Use explicit counters rather than one universally strongest unit:
- Infantry can capture/secure points and threaten light vehicles.
- Tanks are strong against structures and vehicles but vulnerable to dedicated anti-armor units.
- Anti-air units counter aircraft and helicopters but are weaker against ground forces.
- Artillery has long range and high structure damage, but needs protection and has a slow firing cycle.
- Aircraft provide rapid response but are expensive and vulnerable to anti-air defenses.

## Recommended Godot project structure
```
project.godot
scenes/
  menus/
  battlefield/
  buildings/
  units/
  effects/
scripts/
  core/
  economy/
  combat/
  ai/
  ui/
data/
  factions/
  units/
  buildings/
assets/
  sprites/
  audio/
tests/
```

## Implementation sequence
1. Establish the Godot project, input map, autoload managers, and Android viewport settings.
2. Build one small test map and camera/touch navigation.
3. Implement resource economy and construction placement.
4. Implement unit production, selection, movement, and attack orders.
5. Add health, damage, projectile/artillery behavior, and destruction.
6. Add anti-air, aircraft, and helicopter roles after the ground-combat loop is stable.
7. Add enemy AI and match victory/defeat.
8. Add faction data, balancing, audio, UI polish, and Android performance testing.
9. Export and test a single integrated APK on a real Android device.

## Definition of done for each feature
- Works in an actual Godot scene, not only as a design note.
- Touch input is usable on a phone.
- Has visible feedback and handles invalid actions safely.
- Does not break existing core gameplay.
- Is tested in a repeatable match scenario.

## Current repository baseline
The repository began with only a README. This document records the agreed scope and implementation order. It does not claim that gameplay systems or an APK already exist; those must be implemented and tested in the Godot project.
