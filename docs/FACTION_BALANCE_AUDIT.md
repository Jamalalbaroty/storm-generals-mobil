# Storm Generals — Faction Balance Audit (Initial Code Review)

## Scope and confidence

This is a static review of `main.gd`, not a measured win-rate report. No balance values are changed by this document. Before tuning, run repeatable matches on the same map and record unit counts, elapsed time, resource spend, and outcomes.

## Existing shared economy values

| Setting | Current value |
|---|---:|
| Starting credits | 1,200 |
| Passive income | 6 credits/second |
| Maximum credits | 5,000 |
| Infantry cost | 100 |
| Tank cost | 300 |
| Barracks | 250 |
| Factory | 450 |
| Turret | 350 |
| Artillery | 450 |
| Airfield | 600 |
| Fighter | 500 |
| Anti-air | 400 |
| Helicopter | 650 |
| Missile silo | 800 |
| Missile defense | 700 |
| Missile | 650 |

These costs are shared constants in the current code. Faction-specific production cost multipliers were not found in the reviewed code paths.

## Existing faction-specific combat values

### Helicopters

| Faction | Damage per attack | Attack cooldown | Approx. raw damage/second |
|---|---:|---:|---:|
| Chinese | 30 | 1.35 s | 22.2 |
| American | 32 | 1.25 s | 25.6 |
| Arab Army | 34 | 1.20 s | 28.3 |
| وطن | 38 | 1.10 s | 34.5 |

### Strategic missiles

| Faction | Damage | Cooldown |
|---|---:|---:|
| Chinese | 185 | 14 s |
| American | 195 | 13 s |
| Arab Army | 205 | 12 s |
| وطن | 230 | 11 s |

### Naval attack damage

The player-side naval attack expression includes faction-specific base damage values: Chinese 40, Arab Army 42, American 44, and وطن 50. Destroyer anti-submarine damage (78), submarine damage (62), and carrier damage (24) are handled as separate role-specific values in that expression.

## Balance risks to validate

1. **وطن's stacked premium bonuses:** it has the highest helicopter damage and fastest helicopter cadence, and the highest missile damage with the shortest missile cooldown. Its raw helicopter damage rate is about 55% above the Chinese value; its missile damage-per-cooldown rate is about 59% above the Chinese value. Because the reviewed shared cost constants do not show a compensating faction surcharge, this deserves priority testing.
2. **Faction identity is concentrated in a few units:** the visible differences found in this review cluster around helicopters, missiles, and naval base damage. Confirm that other unit classes have intentional, documented differences before adding more bonuses.
3. **Naval faction selection:** inspect both player and enemy naval damage paths during testing to ensure each side uses its own faction's values, rather than a shared player-faction variable.
4. **Counterplay:** verify that anti-air can reliably punish helicopters, missile defense can mitigate strategic missiles, and these counters are affordable and available early enough to matter.

## Recommended controlled test matrix

For each faction matchup, run at least three matches on each of:
- Open desert map
- Forest/coastal map
- Mountain/coastal map
- Coastal city map

Keep starting credits, map seed, player side, and AI difficulty fixed. Swap player/enemy factions and alternate sides. Record:
- Winner and match duration
- Credits spent by category
- Units/buildings produced and lost
- Supply points controlled over time
- Missile launches and interceptions
- Air units lost to anti-air
- Crashes, stuck units, and AI stalls

Do not tune based on one match. Prefer small changes to one variable at a time, then rerun the same matchup set.

## Proposed balancing guardrails

- Keep وطن elite, but make its premium strengths compete with meaningful economic or availability trade-offs.
- Avoid making one faction best at both damage and firing cadence across several high-impact unit classes.
- Every powerful unit should have at least one clear, affordable counter.
- Keep faction advantages understandable in the selection screen and in-game unit descriptions.
- Do not label a balance change successful until controlled matches show that the advantage is competitive rather than automatic.

## Next implementation step

After the controlled tests, create a single data-driven faction-balance table and route all faction modifiers through it. This will make tuning auditable and reduce scattered nested conditional expressions. Keep current values until baseline results are collected.
