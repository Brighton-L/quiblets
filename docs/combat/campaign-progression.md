# Campaign progression rebalance

September 24, 2026. Applies to all 160 nodes in 16 main regions and four optional routes. No player save is used by the tests or fixtures.

## Retuning after play feedback

The previous late-game curve overshot: area 14 recommended 109,000–159,000 power. The revised curve reduces stone-power growth after level 35, the final two regional level jumps, regional enemy multipliers, and stacked boss/escort multipliers. Existing equipment and saves are unchanged; newly earned stone rewards and revitalizer targets follow the revised curve. The intended benchmark is comfortable areas 1–13, mild pressure in 14, moderate pressure in 15, and substantial difficulty in 16 for a developed team around 69,000 power. This is fixed campaign balance, not scaling to the current player.

## Rules

- Fixed regional level anchors rise from 2 to 140. Each node advances within its region toward the next anchor; regular nodes also have small pressure increases, groves are gentler, and dedicated bosses have the highest target.
- Expected team size grows from one starter, to two in the first region, three in regions 2–3, four in regions 4–7, and five thereafter. This is a target, not a party restriction.
- Baseline equipment uses the actual 16-slot unlock bands, balanced Health/Attack allocation and 82% of the current mean drop power. No perfect bonus rolls or charm stacks are assumed. Progression combines levels, additional slots, larger teams and increasing stone power.
- Recommended power is expected total HP + Attack. The difficulty label uses the geometric mean of actual HP and Attack relative to the fixed target, so pure HP stacking does not imply adequate offense. It is a stat guide, not a win probability; healing and move combinations remain important.
- Ordinary enemy equipment follows the same stage equipment curve. Regional HP/damage multipliers remain separate, and encounter roles supply boss/escort strength. Surface Tension adds 20% of the team's average **level** lead, capped at 2–8 levels by region; fitted equipment no longer feeds it. It never lowers enemy levels.
- New stone drops use a narrow ±10% range around the stage mean, geometrically interpolated between power anchors. Late drops continue past the former 700-power tier ceiling. Enemies, treasure caches and stones on newly attracted Quiblets use this generator. Tier/material presentation remains separate from raw power.
- Revitalization targets that same mean for the highest reached stage, retaining its existing sacrifice cost and random 0–5 bonus. Existing stones keep their stored values.
- Victory XP uses the level XP curve and region-to-region level gap; a required seven-node route supplies roughly enough XP to reach the next region. Boss victories give more, groves less. Losses give 12% of the base reward and do not get the Challenger victory multiplier. Existing training formulas are unchanged.
- Boss escorts grow from one to two to three. Dedicated boss HP grows from 3× to 4.5×; field bosses from 1.8× to 2.4×. Damage multipliers grow separately. The existing marked attack uses level-appropriate base power rather than the same late-game power against a starter.
- Healing Bloom now restores 2.5% max HP per half-second for 4 seconds, before modifiers. Pollen Puff restores 18% with a 6.5-second base cooldown. Move Stones and healing bonuses still apply. This reduces sustained automatic recovery without removing the support role. Natural regeneration remains disabled during fights; revivals remain 10 seconds.

## Recommended power for every node

The numbers are generated from the same functions used by the level screen and live stages.

| Area | Level 1 | Level 2 | Level 3 | Grove | Level 4 | Level 5 | Boss | Optional grove |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Rolling Steppe | 306 | 314 | 713 | 638 | 733 | 840 | 840 | 780 |
| Windy Fields | 1,245 | 1,276 | 1,450 | 1,298 | 1,649 | 1,710 | 1,895 | 1,759 |
| Winding Creeks | 1,879 | 2,085 | 2,136 | 1,912 | 2,365 | 2,634 | 2,822 | 2,446 |
| Crooked Cliffs | 3,609 | 3,966 | 4,063 | 3,637 | 4,470 | 4,973 | 5,688 | 4,920 |
| Soggy Lowlands | 5,415 | 5,881 | 6,374 | 5,394 | 6,926 | 7,578 | 8,425 | 7,444 |
| Lush Basin | 7,896 | 8,486 | 9,104 | 7,782 | 9,833 | 10,694 | 11,763 | 10,403 |
| Glimmering Grotto | 11,538 | 12,182 | 12,849 | 11,503 | 13,643 | 15,008 | 15,891 | 14,322 |
| Shivering Shelf | 18,746 | 19,715 | 20,772 | 18,596 | 22,577 | 24,701 | 26,023 | 23,547 |
| Parched Plains | 24,444 | 25,554 | 27,281 | 23,958 | 28,672 | 30,942 | 32,754 | 29,264 |
| Highland Peaks | 30,370 | 31,685 | 33,532 | 29,572 | 35,694 | 38,196 | 40,041 | 36,062 |
| Muddy Moor | 36,924 | 38,895 | 40,385 | 35,669 | 42,661 | 45,344 | 46,871 | 42,575 |
| Foaming Fjord | 43,321 | 45,359 | 46,958 | 42,039 | 49,636 | 53,872 | 55,855 | 50,742 |
| Gloomy Glade | 50,829 | 52,990 | 55,092 | 48,958 | 57,604 | 60,710 | 62,657 | 57,278 |
| Looming Lowlands | 57,296 | 59,224 | 61,176 | 54,767 | 63,446 | 66,769 | 67,853 | 62,503 |
| Distant Downs | 61,550 | 63,584 | 66,151 | 58,766 | 69,085 | 72,837 | 74,573 | 68,138 |
| Mystery Meadow | 67,648 | 70,533 | 73,475 | 65,231 | 76,725 | 80,870 | 83,588 | 76,305 |
| Rustling Thicket | 1,294 | 1,327 | 1,508 | 1,350 | 1,715 | 1,778 | 1,970 | 1,830 |
| Pebbled Shoals | 8,212 | 8,825 | 9,468 | 8,094 | 10,226 | 11,122 | 12,233 | 10,819 |
| Rocky Ravine | 31,584 | 32,953 | 34,874 | 30,755 | 37,122 | 39,724 | 41,643 | 37,505 |
| Golden Grove | 59,588 | 61,593 | 63,623 | 56,958 | 65,984 | 69,440 | 70,567 | 65,003 |

## Progression inputs and rewards

Columns span Level 1 through the dedicated Boss Level. Slot counts are an expectation across the randomized unlock bands, not a forced board layout.

| Area | Expected levels | Team size | Unlocked slots/member | Mean new stone power |
|---|---:|---:|---:|---:|
| Rolling Steppe | 2–4 | 1–2 | 1.2–1.7 | 30–38 |
| Windy Fields | 5–8 | 3–3 | 1.9–2.6 | 43–62 |
| Winding Creeks | 9–13 | 3–3 | 2.8–3.6 | 70–86 |
| Crooked Cliffs | 14–19 | 4–4 | 3.8–4.8 | 91–119 |
| Soggy Lowlands | 20–26 | 4–4 | 5.0–6.2 | 125–157 |
| Lush Basin | 27–33 | 4–4 | 6.3–7.2 | 163–204 |
| Glimmering Grotto | 35–42 | 4–4 | 7.5–8.6 | 220–244 |
| Shivering Shelf | 44–52 | 5–5 | 8.8–10.1 | 251–282 |
| Parched Plains | 54–63 | 5–5 | 10.3–11.7 | 290–312 |
| Highland Peaks | 65–75 | 5–5 | 12.0–13.2 | 317–344 |
| Muddy Moor | 77–87 | 5–5 | 13.4–14.4 | 350–371 |
| Foaming Fjord | 90–101 | 5–5 | 14.7–16.0 | 378–403 |
| Gloomy Glade | 104–116 | 5–5 | 16.0–16.0 | 410–451 |
| Looming Lowlands | 119–126 | 5–5 | 16.0–16.0 | 462–489 |
| Distant Downs | 128–138 | 5–5 | 16.0–16.0 | 497–539 |
| Mystery Meadow | 140–152 | 5–5 | 16.0–16.0 | 548–608 |
| Rustling Thicket | 5–8 | 3–3 | 1.9–2.6 | 43–62 |
| Pebbled Shoals | 27–33 | 4–4 | 6.3–7.2 | 163–204 |
| Rocky Ravine | 65–75 | 5–5 | 12.0–13.2 | 317–344 |
| Golden Grove | 119–126 | 5–5 | 16.0–16.0 | 462–489 |

## Validation and limits

`tests/progression_curve.gd`: 10,578 checks across all 160 nodes, covering target ordering, generated legal equipment, upgrades improving preparedness, reward ranges, optional-host mapping, sufficient route XP, revitalizer consistency, old stone value preservation, save isolation, and UI/live node agreement.

`tests/campaign_combat_audit.gd`: 160 unique moving-arena encounter samples, one per node. Level 1 and intermediate regular nodes test a normal enemy group; Level 5 tests a field boss; Boss Level tests the dedicated boss; each grove tests a real generated guardian group. Real species selection, loadouts, actor physics, collisions, cooldowns, status effects, heals and revivals are used. Tests bypass terrain rendering, exploration and loot handling; they are **not full expeditions**. Each uses one deterministic seed and a generated legal progression-appropriate party, automatically pressing ready moves without dodging. Fixtures evolve when eligible, add a fourth learned move from level 75 onward, and distribute a milestone-based Move Stone slot budget (three initial slots plus approximately 0.8 slots per 25 levels). Later moves carry Rush, Heavy and, when space permits, Blast Stones. They do not reproduce a saved team or assume optimized rare bonus rolls. No saved player team is used.

The final sweep produced 160 victories, 0 defeats and 0 timeouts, with knockouts and revivals appearing in later fights. These counts are coverage observations, not population win rates. Additional seeds, full-map play and unusual builds can differ substantially. Raw encounter results are in `campaign-combat-results.json`.

The graphical preview checks the final level cards, current team power, recommendations and long optional-grove title at 1280×800. Five- and six-digit power values fit without overlap.

Other checks: combat rebalance, pressure, in-range attacks while chasing/retreating, boss roles, defensive moves, move runtime, difficulty, stone workshop and area UI/progression.

Run with `--script` and `-- --no-save`. The combat audit supports `--all-nodes`; without it the audit samples nodes 0, 5 and 6, while `--remaining-nodes` covers 1, 2, 3, 4 and 7. Use `--fixed-fps 60` for native-physics combat runs.

## Fixed developed-team benchmark

`--late-benchmark` holds the same generated five-member, level-119 team (66,468 total HP + Attack) fixed across regions 13–16. It uses the existing synthetic roster, ordinary balanced equipment at 1.20× the area-14 fixture power, and no player-save data. Two seeds (`--seed-offset=0` and `--seed-offset=1000`) sample regular enemies, field bosses, and dedicated bosses: 24 encounters total. Regions 13–14 won all 12 samples; region 14 occasionally lost one member temporarily. Region 15 won all six samples but its bosses reduced the party to two or three survivors before recovery. Region 16 won three, lost one, and reached the 75-second limit twice, with one surviving member at the lowest point in one fight. Timeouts mean unresolved encounters, not defeats. Results are in `late-campaign-benchmark.json`. These checks support the requested relative difficulty, but full expeditions and different move matchups still require play feedback.
