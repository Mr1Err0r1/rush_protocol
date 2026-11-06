# Rush Protocol — Game Overview

**Languages:** English (canonical) · [Deutsch](GAME_OVERVIEW.de.md) · [Русский](GAME_OVERVIEW.ru.md)

**Project title in Godot:** `Rush_Protocol`\
**Setting:** Blackglass Casino\
**Engine:** Godot 4.7\
**Genre:** Tactical 3D multiplayer/solo prototype with character roles, casino risk actions, smuggling, inventory and hidden objectives

## 1. Game premise

Players enter a luxury casino where competing groups seek money, information and control of the house. Before entering, each player chooses a role and assembles a limited loadout. A fictional security check may discover and confiscate non-guaranteed contraband. Inside, players manage chips, equipment, influence and suspicion while trying to advance through the building.

The intended tone is a social heist thriller: Mafia, military, Assassins, investigators, casino elites and ordinary guests pursue different role fantasies. Poker cheating, bribery, false identities and weapons are **fictional game mechanics**. The project is not a guide to real-world fraud, smuggling or violence.

## 2. Current prototype loop

1. **Start and mode:** The main menu exposes solo-versus-AI, lobby/network and local match configuration entry points. Some flows remain under development.
2. **Faction-first role selection:** Players choose a faction before the role screen opens; the list then shows only available roles from that faction. The last selected role preselects its faction on a later visit. A role resource defines starting statistics, smuggling slots, guaranteed equipment, permitted loadout categories and a narrative objective.
3. **Loadout:** Guaranteed role items are added separately from selectable slots. Optional items must be eligible for smuggling and comply with role restrictions. Validation exists in both the selection UI and match logic.
4. **Entry check:** Non-guaranteed items may be detected according to their discovery chance. Suspicion affects the check; discovered items may be confiscated. Excess suspicion can result in ejection.
5. **Casino turns:** The match controller tracks phases such as item use, action and resolution. Risk actions can alter chips and can be affected by selected items.
6. **Progress and objectives:** Match state tracks players, zones, status effects, chips, health, suspicion, heat, inventory and elimination. Last-player-standing and vault-related win logic exist in the prototype.
7. **Penthouse / boss signal:** Entering the penthouse zone can signal a boss encounter. Boss health and attack/win hooks are present, but the full encounter is unfinished.

## 3. Casino tower

The match scene builds a vertical casino tower at runtime from Godot 3D geometry. Floors have distinct visual themes, signs, columns, railings and tables. Elevator areas move a player between neighboring floors and update the associated zone state.

| Floor | Location | Zone ID | Current role |
|---|---|---|---|
| 1 | Gaming hall and public tables | `lobby` | Entry area and casino setting |
| 2 | Golden salon / VIP | `vip_lounge` | High-roller atmosphere |
| 3 | Backroom / black market | `backroom` | Narrative space for discreet deals |
| 4 | Vault corridor | `vault_corridor` | Transition toward a secured area |
| 5 | Owner's penthouse | `boss_office` | Signals the boss phase |

**Limitations:** The floors and elevator areas exist in the prototype. Key-gated doors, merchants, fully distinct rules per floor and a complete security progression are not yet integrated. `vault_corridor` and the match-logic zone `vault` are separate identifiers.

## 4. Factions and character roles

Characters are data resources under `resources/characters/`. The selection wizard filters roles by faction and provides localized English, German and Russian onboarding labels. Starting values include health, suspicion, heat, influence and chips. Smuggling slots apply to selected items; guaranteed role equipment is tracked separately and bypasses the ordinary entry check.

| Role | Faction | Health | Suspicion | Heat | Influence | Chips | Slots | Guaranteed item(s) |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Assassin | Assassins' Guild | 3 | 0 | 0 | 2 | 50 | 3 | Poison needle |
| Civilian | Civilians | 5 | 0 | 0 | 1 | 30 | 1 | — |
| Government agent | Government | 3 | 0 | 1 | 4 | 60 | 2 | Fake ID, listening bug |
| Mafia boss | Mafia | 4 | 1 | 3 | 4 | 80 | 2 | Revolver |
| Military field leader | Military | 5 | 0 | 1 | 3 | 45 | 1 | Revolver |
| Millionaire | Casino elite | 3 | 2 | 2 | 5 | 150 | 2 | Fake coin / chip |
| Undercover investigator | Investigators | 3 | 0 | 0 | 3 | 40 | 1 | AI lens |

Character resources also contain ability and objective IDs (for example, `passive_fear_aura`, `active_mob_call`, `eliminate_rivals` and `expose_criminals`). Not every listed ability has a complete gameplay implementation; faction abilities and the boss arc remain development work tracked in [issue #4](https://github.com/Mr1Err0r1/rush_protocol/issues/4).

## 5. Inventory and items

Item definitions are Godot resources under `resources/items/`. The current set includes information tools, defensive items, fake chips, prepared cards, disguises, gadgets, weapons and a copied vault key. Their descriptions express intended fictional roles; not every item has a polished effect or UI feedback.

The risk pool is an abstract casino action with positive and negative outcomes that affect chips. Prepared cards can force a favorable risk result. This is **not** a full poker or blackjack implementation: there are no complete private hands, betting rounds, fold/call/raise rules, dealer/opponent logic or authoritative table-game resolution yet. Full playable card tables and balanced cheating counterplay are tracked in [issue #2](https://github.com/Mr1Err0r1/rush_protocol/issues/2).

## 6. Controls

| Input | Prototype action |
|---|---|
| `W` / `A` / `S` / `D` | Move |
| Mouse | Look / camera |
| `Shift` | Sprint |
| `Space` | Jump |
| `1`–`4` | Use the corresponding hotbar item |
| Left mouse button | Risk action, where available |
| `T` | Select target player |
| `Enter` | End turn |
| `V` | Prototype attack input |
| `F5` | Change camera mode |
| `Esc` | Pause / back, depending on current screen |
| `E` | Reserved interaction input; elevator areas currently trigger on entry |

Available actions depend on the active player, match phase and equipped items. Bindings and menu behavior may change while the prototype is being developed.

## 7. Project structure

- `project.godot` — project settings, input map and autoloads.
- `autoload/` — event bus and game, save, audio, locale and item managers.
- `core/` — character, player, match, risk and entry-check logic.
- `resources/characters/` — faction, statistics, objectives and item-slot data.
- `resources/items/` — item resources.
- `scenes/world/` — menu, world and match scenes.
- `scripts/world/casino_tower.gd` — procedural casino geometry and elevator transitions.
- `scripts/ui/` — menus, character selection and match HUD.
- `scripts/items/` — gadget, tool and weapon behavior.

## 8. Known limitations and next steps

This is an active prototype, not a finished game or release build. The five-floor environment, role resources, loadout categories and central match systems form a foundation. The major remaining areas include complete poker/blackjack loops, clear and balanced item effects, implemented faction abilities, floor access requirements, a finished boss encounter, onboarding, localization coverage, platform QA and overall balance. Track current work in [GitHub issues](https://github.com/Mr1Err0r1/rush_protocol/issues).

## 9. Local testing

Use Godot 4.7 or newer for a headless editor import check:

```bash
godot --headless --editor --path . --quit
```

This import check alone does not certify gameplay balance, online behavior, audiovisual quality or release readiness. A reusable automated scene smoke-test script is proposed in [PR #11](https://github.com/Mr1Err0r1/rush_protocol/pull/11) and is not part of `main` yet.
