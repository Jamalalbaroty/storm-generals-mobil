# Storm Generals — QA Checklist

Use this checklist for each candidate build. Record device model, Android version, screen resolution, commit SHA, and test result before marking a test complete.

## 1. Startup and faction selection
- [ ] App opens without a crash or black screen.
- [ ] All four factions are visible and selectable: American, Chinese, Arab Army, وطن.
- [ ] Starting a match initializes player/enemy bases, resources, supply points, and HUD.
- [ ] Restarting a match resets all state (credits, units, buildings, health, missiles, effects, and timers).

## 2. Economy and construction
- [ ] Passive income increases credits at the expected rate and respects the maximum balance.
- [ ] Capturing a supply point changes ownership and income as intended.
- [ ] A purchase with insufficient credits is rejected with clear feedback.
- [ ] Buildings cannot be placed outside the permitted area or on occupied/invalid locations.
- [ ] Building prerequisites are enforced (barracks for infantry, factory for tanks, and relevant production buildings for specialist units).
- [ ] Destroyed buildings stop producing and stop providing defensive effects.

## 3. Ground combat
- [ ] Single-unit selection works by touch.
- [ ] Drag selection selects only eligible friendly units.
- [ ] Move orders update unit destinations and units stop at valid positions.
- [ ] Attack orders target hostile units/buildings, not friendly forces.
- [ ] Units acquire targets only within their intended range.
- [ ] Cooldowns prevent continuous over-firing.
- [ ] Damage, splash damage, terrain modifiers, death, and cleanup behave consistently.
- [ ] Base health reaches defeat/victory exactly once and ends combat cleanly.

## 4. Air and artillery
- [ ] Artillery attacks at long range and has a visible firing/explosion effect.
- [ ] Fighters prioritize hostile aircraft and do not become stuck after losing a target.
- [ ] Player and enemy fighters use the same air-target acquisition radius (300), attack range (270), damage (30 before terrain modifiers), cooldown (1.35s), and movement speeds; fighters do not damage the opposing base when no aircraft target exists.
- [ ] Helicopters attack valid ground targets and take damage from anti-air defenses.
- [ ] Helicopter production costs match the selected faction for both player and AI: وطن 850 credits; American, Chinese, and Arab Army 650 credits; all consume three supplies.
- [ ] Anti-air defenses prioritize air targets and do not incorrectly target ground-only units.
- [ ] Aircraft launched from carriers return or despawn according to their carrier lifecycle.

## 5. Missiles and naval combat
- [ ] Missile launch consumes the correct resources and respects cooldown/stock limits.
- [ ] Missile defense can detect/intercept valid incoming missiles.
- [ ] Missile defense intercepts incoming missiles with a 0.75-second per-building cooldown; consecutive missiles are tested against the 190-unit interception radius.
- [ ] Missile launch cost is faction-aware on both sides: وطن 850 credits; American, Chinese, and Arab Army 650 credits; all consume four supplies, with faction-specific warhead damage and silo cooldown preserved.
- [ ] Faction balance profile is the single source for helicopter cost/damage/cooldown, missile cost/damage/cooldown, and naval base damage; verify all four faction rows and preserve role-specific naval damage exceptions.
- [ ] Destroyers, submarines, carriers, and landing craft retain distinct behaviors.
- [ ] Landing craft unload troops at valid shore positions and do not strand units outside the map.
- [ ] Naval escorts remain near their assigned transports/carriers when required.
- [ ] Naval units do not target invalid or already-destroyed objects.
- [ ] A submarine remains untargetable to the opposing fleet until a living destroyer or helicopter enters its sonar detection radius; it becomes targetable while detected.
- [ ] Destroyers prioritize detected submarines and landing craft appropriately; submarines prioritize carriers; destroyed ships are skipped.
- [ ] Player and enemy naval units use the faction stored on each unit for base naval damage (Chinese 40, Arab Army 42, American 44, وطن 50); destroyer anti-submarine damage remains 78, submarine damage 62, and carrier damage 24.
- [ ] Carrier fighter launches respect the three-fighter team cap, and carrier-based fighters return, recover, and rearm without becoming stuck.
- [ ] Landing craft unload exactly three marines, return to their recorded home position, reload after the loading delay, and can repeat the landing cycle.
- [ ] Destroyer escorts stay near an active friendly landing craft or carrier when the fleet's main target is far away, then resume engaging naval targets.

## 6. Enemy AI
- [ ] Enemy income and production remain within configured limits.
- [ ] Enemy builds and defends its base without overlapping structures.
- [ ] Enemy forces respond to threats and pursue objectives without oscillating indefinitely.
- [ ] Enemy ground forces prioritize player units threatening the enemy base or nearby structures.
- [ ] Enemy threat selection gives appropriate priority to artillery, tanks, aircraft, and infantry.
- [ ] Enemy ground formations select only visible ground targets; aircraft are handled by enemy fighters and anti-air defenses rather than pulling tanks/infantry away from ground objectives.
- [ ] Enemy artillery, ordinary ground troops, and defensive guards never switch to aircraft or naval units as fallback targets when no ground threat is in range.
- [ ] Enemy units produced by the AI and carrier-launched aircraft use the selected rival faction, not a hard-coded faction.
- [ ] Enemy can recover its behavior after a target or building is destroyed.
- [ ] Enemy does not build a second anti-air site when fewer than three living player aircraft are present; at three or more, it can reinforce up to two sites when credits and build space allow.
- [ ] Enemy builds missile defense when the player owns a missile silo or has a player missile in flight, and does not repeatedly purchase duplicate missile defenses.
- [ ] When air or missile threats are absent, enemy production retains resources for units and core structures instead of repeatedly buying threat-specific defenses.
- [ ] AI does not spawn unbounded units or create severe frame-rate drops.

## 7. Mobile and performance
- [ ] Landscape orientation is enforced.
- [ ] HUD and touch targets remain readable at supported phone resolutions.
- [ ] Touch selection and dragging work without requiring a mouse.
- [ ] Audio is not clipped or excessively loud; repeated combat sounds do not create runaway playback.
- [ ] A 10-minute match completes without a crash, runaway memory use, or severe slowdown.
- [ ] Pause/resume and Android app background/foreground transitions are safe.

## 8. Android release candidate
- [ ] Latest GitHub Actions Android workflow completes successfully.
- [ ] APK artifact downloads and installs on a physical Android device.
- [ ] Fresh install launches and starts a match.
- [ ] A full match can reach victory and defeat conditions.
- [ ] Tested commit SHA and device details are recorded.
- [ ] Build is labelled a release candidate only after all critical checks pass.

## Defect report template

- Build / commit:
- Device / Android:
- Steps to reproduce:
- Expected result:
- Actual result:
- Severity: blocker / major / minor
- Screenshot or log:
