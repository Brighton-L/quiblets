# Looming Lowlands combat audit — September 24, 2026

Historical audit before the campaign-wide rebalance. Current targets and results are in [campaign progression](campaign-progression.md).

51 isolated encounter simulations, using three seeds (23, 41, 79). No player save was accessed.

## Method

`tests/looming_combat_audit.gd` uses native actor physics, actual move casts/cooldowns, damage, healing, status effects, enemy target selection, and 10-second revivals. The real Looming Lowlands encounter/species/loadout generator supplies enemies. Level 5 uses stage level 61; the dedicated Boss Level uses 64. Cosmetic spawning, loot and terrain generation are bypassed. Actors move and collide in a 48 × 40 flat arena. This does not measure full-map navigation or predict the player's win rate.

The default team is level-60 Burlow, an evolved Fire attacker, and Electrish, each with four 300-power Health Stones and four Attack Stones. All equipped moves belong to their learnsets. Damage uses no Move Stones. Support replaces the Fire attacker with Bloomie using Healing Bloom, Pollen Puff and Spore Cloud. Support + bonuses adds eight Healing Received and Damage Resistance bonuses per Quiblet (80% healing, 40% resistance). Drain fits three Drain Stones on each equipped move. Strong uses level 80, 450-power stones, and two Heavy Stones plus one Rush Stone per move. The controller activates ready moves without tactical movement. These are generated comparison builds, not replicas of the user's team.

Healing columns count actual HP restored by active healing, excluding overheal. Natural recovery is blocked during every test fight. Trials stop at victory, defeat, or 90 seconds; a timeout is not a victory.

## Final results

| Encounter | Build | Wins / losses / timeouts | Reached one survivor (trials) | Mean active HP restored across team |
|---|---|---|---|---|
| ordinary | damage | 0 / 3 / 0 | 3 | 0 |
| ordinary | support | 3 / 0 / 0 | 0 | 11274 |
| ordinary | support_bonus | 3 / 0 / 0 | 0 | 8555 |
| ordinary | drain | 3 / 0 / 0 | 1 | 6009 |
| ordinary | strong | 3 / 0 / 0 | 0 | 0 |
| field_boss | damage | 0 / 3 / 0 | 3 | 0 |
| field_boss | support | 1 / 1 / 1 | 2 | 34311 |
| field_boss | support_bonus | 3 / 0 / 0 | 0 | 22482 |
| field_boss | drain | 0 / 3 / 0 | 3 | 3274 |
| field_boss | strong | 0 / 3 / 0 | 3 | 0 |
| boss | damage | 0 / 3 / 0 | 3 | 0 |
| boss | support | 0 / 1 / 2 | 2 | 39539 |
| boss | support_bonus | 0 / 0 / 3 | 1 | 33903 |
| boss | drain | 0 / 3 / 0 | 3 | 3205 |
| boss | strong | 0 / 3 / 0 | 3 | 0 |

## Last-survivor control

Two teammates start knocked out. Electrish starts at 35% HP; its actual movement commands lead away from the approaching field-boss encounter. No healing or offensive move is used during this escape. The standing control receives the same starting state and enemies, and can still automatically use basic attacks.

| Seed | Running | Standing |
|---|---|---|
| 23 | defeat at 9.8s; Electrish 0% HP | defeat at 1.7s |
| 41 | recovered at 10.4s; Electrish 14% HP | defeat at 2.1s |
| 79 | defeat at 9.3s; Electrish 0% HP | defeat at 1.8s |

The successful running trial travelled 15 units and restored both teammates after the existing revival timer. Escape is possible, not guaranteed. The unsuccessful running trials still lasted substantially longer than standing still.

## Findings and changes

- Active healing and resistance strongly affect survivability. Support can neutralize ordinary-wave damage, but sacrifices an attacker and takes longer to clear. Stacking more global enemy damage would punish teams without healing disproportionately. Healing move values and Drain Stone values were not changed in this pass.
- Every final boss trial recorded actual boss move casts. The no-movement test teams often lose; the tests do not support claiming bosses remain universally too easy. Dedicated-boss support stalemates also remain a balance concern, not a successful clear.
- A focused regression reproduced a separate bug: an enemy retreating at low HP could stop attacking indefinitely if blocked before reaching its preferred distance. In-range attacks now work during enemy retreat. Player movement orders retain precedence over automatic basic attacks.
- Boss escorts are capped at three. Earlier runs allowed four escorts for a Level 5 boss and five for the dedicated boss, producing overwhelming simultaneous area attacks. The cap reduces that pile-up without adding boss HP or increasing damage. Normal-wave population is unchanged. Different counts also change the seeded boss selection, so these runs cannot isolate a percentage improvement caused by escort count alone.
- Natural recovery remains exploration-only. Active healing and teammate revival continue during combat.

## Verification

Passed: combat_pressure, combat_rebalance, attack_while_chasing (now includes blocked retreat), encounter_pressure (checks three escorts), and defensive_moves. The retreat regression failed before the fix and passed afterward. All 51 final audit rows completed without script errors; expected losses and timeouts are recorded above.

Run the audit with Godot: `--headless --path . --fixed-fps 60 --script res://tests/looming_combat_audit.gd -- --no-save`. Add `--boss-only` after `--no-save` to skip ordinary waves.
