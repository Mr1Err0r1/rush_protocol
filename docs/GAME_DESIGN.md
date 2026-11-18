# Rush Protocol — Game Design: Casino Risk Loop

**Languages:** English (canonical) · [Deutsch](GAME_DESIGN.de.md) · [Русский](GAME_DESIGN.ru.md)

Inspired by *Buckshot Roulette*: a small ruleset, rising tension, visible probabilities and a hidden sequence. This reference distinguishes implemented prototype behavior from planned work. The numbers and defaults below are based on the current code (`CheckpointRules`, `RouletteTable`, `ItemDraft`, and `GameManager`).

## Core loop

1. **Choose a faction and role.** The faction-first wizard filters roles to the selected group.
2. **Prepare a loadout.** Roles define starting resources, smuggling slots, guaranteed items and category restrictions.
3. **Pass the entry inspection.** Non-guaranteed smuggled items may be found and confiscated; an ejection can eliminate a player.
4. **Play a round.** Items are distributed randomly by default, or players may use the optional item draft.
5. **Move through the tower.** First entry to an upper-floor checkpoint may trigger a search; the penthouse check is mandatory.
6. **Raise the stakes.** In the optional shell-risk mode, higher floors use larger magazines with a higher live-shell ratio.
7. **Compete for the objective.** Last-player-standing and vault-related win logic exist; the complete boss encounter is still in development.

## Factions and roles

| Faction | Roles currently represented in character resources |
|---|---|
| Military | Field leader, Lieutenant, Soldier |
| Intelligence | Agent, Analyst |
| Civilians | Civilian, Journalist, Gambler |
| Mafia | Mafia boss, Capo, Enforcer, Accountant |
| Casino elite | Millionaire |
| Investigators | Undercover investigator |
| Assassins' Guild | Assassin |

Role resources live in `resources/characters/*.tres` and are loaded into the selection/gallery systems. Some ability and objective IDs remain data-only; they should not be mistaken for finished faction abilities.

## Security checks

The entry inspection always runs after loadout selection. The table below describes the probability of an upper-floor checkpoint being triggered **on first entry**, at zero suspicion and zero Heat. Faction pass-through is already applied; the penthouse is mandatory. Values are exact except the displayed 28.5% value.

| Faction | Salon / VIP | Backroom | Vault corridor | Penthouse | Pass-through chance |
|---|---:|---:|---:|---:|---:|
| Civilians | 19% | 28.5% | 38% | 100% | 5% |
| Mafia | 18% | 27% | 36% | 100% | 10% |
| Military | 18% | 27% | 36% | 100% | 10% |
| Intelligence | 14% | 21% | 28% | 100% | 30% |
| Investigators | 16% | 24% | 32% | 100% | 20% |
| Casino elite | 12% | 18% | 24% | 100% | 40% |
| Assassins' Guild | 20% | 30% | 40% | 100% | 0% |

Suspicion adds 3 percentage points per point and Heat adds 2 percentage points per point to the checkpoint trigger chance; non-mandatory checks then apply the faction pass-through modifier, and the result is clamped to 0–100%. Character-specific settings can override parts of the faction profile.

If a search occurs, the following are the base item discovery chances at the entry inspection (strictness 1.0), before suspicion, role resistance or faction concealment. Item category, suspicion, role and floor strictness can change the final chance.

| Item | Base discovery chance |
|---|---:|
| Revolver | 85% |
| Copied vault key | 90% |
| Bulletproof band | 65% |
| Smoke grenade | 55% |
| Prepared cards | 30% |
| Fake ID | 20% |
| Counterfeit coin / fake chip | 15% |
| Poison needle | 10% |
| Glue | 8% |
| Lighter | 5% |
| Listening bug | 3% |
| AI lens | 2% |

Faction concealment includes, for example, military weapons ×0.7, intelligence intel ×0.5, and Assassins' Guild weapons ×0.4. Role `detection_resistance` reduces discovery chance. Floor strictness multipliers are Salon ×0.6, Backroom ×0.9, Vault corridor ×1.2 and Penthouse ×1.5.

A clean search yields no confiscation; found contraband is removed. At the entry inspection, reaching the suspicion limit or finding at least two items without a valid bribe causes ejection/elimination. At an upper-floor checkpoint, two or more finds without a bribe normally send the player back and add 1 Heat; if the suspicion limit is reached, ejection takes precedence. A valid bribe means carrying the coin item or having at least 4 Influence. Ejected players cannot continue moving or trigger vault/boss effects.

## Optional shell-risk mode (`risk_mode = "shells"`)

The default risk mode remains the chip pool. For a local/solo quick test, pass `--roulette` after Godot's `--` separator; this sets the match configuration to `shells`.

| Highest floor occupied by a living player | Magazine shells | Expected live shells |
|---|---:|---:|
| 1 — Lobby | 4 | 1.6 |
| 2 — Salon | 5 | 2.3 |
| 3 — Backroom | 6 | 3.0 |
| 4 — Vault corridor | 7 | 3.9 |
| 5 — Penthouse | 8 | 4.8 |

The live/blank counts are announced on load or reload; their order is hidden. A live shot deals 1 damage (2 when the shooter's saw is active); a blank deals no damage. A blank fired at oneself grants an extra action; other shots end the turn. A saw is consumed by the next shot even if it is blank. The magnifier reveals the current shell to its user, handcuffs make a target skip a turn, and a medkit restores health up to the role's maximum. A shield can absorb one hit. This is a compact shell-risk mode, not a full poker or blackjack table game.

## Optional round item draft (`item_mode = "draft"`)

The default item mode remains random distribution. For a local/solo quick test, pass `--draft` after Godot's `--` separator. Each player receives four distinct offers; items in a role-compatible category receive three times the selection weight. A player may choose up to two items, limited by free inventory slots. The default inventory capacity is eight; a full inventory skips the draft. AI players choose automatically, and the round waits for outstanding human choices before starting the turn.

The mode flags can be combined:

```bash
godot --path . -- --roulette --draft
```

Advanced match-config keys include `checkpoints`, `roulette_seed`, `draft_seed` and `inventory_capacity`; these are configuration values, not additional command-line flags. The current draft flow is implemented for solo/local/hotseat play. A player-facing mode selector and authoritative online draft synchronization remain follow-up work.

## Testing and boundaries

Run the behavior/regression suite and scene smoke checks with Godot 4.7.2 or newer:

```bash
GODOT=/path/to/godot bash tests/run_tests.sh
GODOT_BIN=/path/to/godot bash scripts/test/run_headless_smoke.sh
```

GitHub Actions runs the regression suite with Godot 4.7.2-stable and fails if the runner or all test cases are missing. Automated checks do not replace interactive, multiplayer, balance, animation or audiovisual QA. Poker/blackjack, faction abilities, a complete boss arc, mode selection in menus and release packaging remain unfinished. Contraband, weapons, bribery and deception are fictional game systems, not real-world instructions.
