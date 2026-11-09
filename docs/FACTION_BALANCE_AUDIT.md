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
| Missile | 650 (850 for وطن) |

Most costs are shared constants. Helicopters and strategic missiles are the faction-aware exceptions: وطن pays 850 credits for each, while the American, Chinese, and Arab Army pay 650. Player and AI spending use the owning faction's cost.

## Centralized faction balance profile

The live values for the four playable factions are stored together in `FACTION_BALANCE` in `main.gd`. Helicopter cost/damage/cooldown, missile cost/damage/cooldown, and base naval damage read from this single table. Unknown faction values safely fall back to the Chinese baseline. Role-specific naval damage remains separate: destroyer versus submarine 78, submarine 62, carrier 24.

| Faction | Helicopter cost | Helicopter damage / cooldown | Missile cost | Missile damage / cooldown | Naval base damage |
|---|---:|---:|---:|---:|---:|
| Chinese | 650 | 30 / 1.35 s | 650 | 185 / 14 s | 40 |
| American | 650 | 32 / 1.25 s | 650 | 195 / 13 s | 44 |
| Arab Army | 650 | 34 / 1.20 s | 650 | 205 / 12 s | 42 |
| وطن | 850 | 38 / 1.10 s | 850 | 230 / 11 s | 50 |

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

1. **وطن's stacked premium bonuses:** it has the highest helicopter damage and fastest helicopter cadence, and the highest missile damage with the shortest missile cooldown. Its raw helicopter damage rate is about 55% above the Chinese value; its missile damage-per-cooldown rate is about 59% above the Chinese value. Helicopters and strategic missiles each carry a 200-credit surcharge for وطن. Missile defense cooldown is 0.75 seconds per building (190-unit interception radius), reducing the previous 2-second gap that could allow a follow-up missile through.
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

## Recent implementation notes

- Fighter combat parity: both teams now use a 300-unit air acquisition radius, 270-unit attack range, 30 base damage before terrain modifiers, 1.35-second cooldown, and matching pursuit/patrol speeds. Enemy fighters no longer inflict a base-only strike when no hostile aircraft target exists.
- Helicopter premium trade-off: وطن retains its elite 38 damage / 1.10-second cadence, but its production cost is 850 credits rather than 650. Player and AI production both apply the unit owner's faction cost. Other factions retain 650 credits.
- Strategic missile premium trade-off: وطن retains 230 damage and an 11-second silo cooldown, but each launch costs 850 credits rather than 650. Player and AI launches apply the firing faction's cost; other factions retain 650 credits.
- Missile-defense response: each missile-defense building now has a 0.75-second interception cooldown, down from 2 seconds, while retaining the 190-unit interception radius.

## Next implementation step

Run controlled faction matchups and record economy, unit production, combat losses, and outcomes to validate whether وطن's helicopter and missile advantages are offset by its higher costs. Extend the central profile only when a real faction-specific gameplay value is confirmed; do not add arbitrary bonuses.
