# Rush Protocol — Blackglass Casino

**Rush Protocol** is a Godot 4.7 tactical 3D game prototype set in a multi-floor casino. Choose a role, prepare a limited loadout, pass a fictional security check, manage chips and suspicion, and try to outplay rival factions as you move through the casino tower.

> **Status:** Active prototype / pre-release. This repository is not a finished or production-ready game. Poker and blackjack are not yet complete playable table games. Weapons, contraband, deception and casino cheating are fictional game mechanics; this project does not provide real-world instructions.

## Read this in your language

- **English (primary):** this page and [the full game overview](GAME_OVERVIEW.md)
- [Deutsch](README.de.md) · [Ausführliche Spielübersicht](GAME_OVERVIEW.de.md)
- [Русский](README.ru.md) · [Полный обзор игры](GAME_OVERVIEW.ru.md)

English is the canonical project documentation. The German and Russian pages are maintained translations; when they differ, use the English version as the reference.

## What is in the prototype

- A five-floor casino-tower environment, assembled from Godot 3D geometry at runtime, with themed floors and elevator areas.
- Character resources representing the Mafia, Assassins' Guild, civilians, military, government/investigators and casino elite.
- Character-specific starting stats, guaranteed equipment and smuggling/loadout rules.
- A fictional entry inspection, suspicion and heat systems, player inventory, chips, risk actions and a range of gadgets and weapons.
- Main-menu, settings, save, HUD, solo/AI and networking foundations.

Several features remain prototypes or data-driven foundations. The penthouse signals a boss encounter, but the complete boss arena, quest chain and polished boss UI are not finished. Poker/blackjack rules, dealer AI, faction abilities, floor access gates, balance and final presentation still need work. See [GAME_OVERVIEW.md](GAME_OVERVIEW.md) for the detailed feature inventory and known limitations.

## Requirements and run

- Godot **4.7 or newer** (the project targets Godot 4.x).
- Git, if cloning from the command line.

```bash
git clone https://github.com/Mr1Err0r1/rush_protocol.git
cd rush_protocol
```

Import and open `project.godot` in Godot, then run the project. The main scene opens the main menu. Use the solo flow to start a local prototype match; available menu paths can change as development continues.

For a headless editor import check (requires the Godot executable on `PATH`):

```bash
godot --headless --editor --path . --quit
```

This import check does not replace a full interactive playtest or audiovisual QA. A reusable automated scene smoke-test script is proposed in [PR #11](https://github.com/Mr1Err0r1/rush_protocol/pull/11) and is not part of `main` yet.

## Controls

The exact available actions depend on the current scene and match phase. Default prototype bindings include:

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look / camera |
| `Shift` | Sprint |
| `Space` | Jump |
| `1`–`4` | Use the corresponding hotbar item |
| Left mouse button | Risk action (where available) |
| `T` | Select target player |
| `Enter` | End turn |
| `V` | Prototype attack input |
| `F5` | Change camera mode |
| `Esc` | Pause / navigate back, depending on screen |
| `E` | Reserved interaction binding; elevator areas currently trigger on entry |

Settings and key-binding behavior may vary by screen and may still be under development.

## Repository map

```text
autoload/               Global managers (game, save, locale, items, audio, events)
core/                   Character, player, match and risk logic
resources/characters/   Character and faction data
resources/items/        Item definitions
scenes/world/           Main menu, game world and match scenes
scripts/world/          Match setup and procedural casino tower
scripts/ui/              Menus, character selection and HUD
scripts/items/           Item behavior
```

## Contributing and project documentation

Please open an issue before large or cross-cutting changes. Keep changes focused, avoid committing Godot's generated `.godot/` cache, and test resource paths and scenes in Godot before opening a pull request. See the [detailed overview](GAME_OVERVIEW.md) for architecture and gameplay notes.

## Releases

There is **no stable or production release yet**. The repository is in active prototype development. A release should wait until the core table-game loop, faction/character onboarding, key gameplay flows, platform testing, licensing and a reproducible build have been reviewed. Do not treat the current `main` branch as a finished game or a release build.

## License

No license has been confirmed in this repository at the time of writing. Unless and until a license is added, the source remains subject to the default copyright rules; please do not assume it is open-source or redistribute it. See [issue #44](https://github.com/Mr1Err0r1/rush_protocol/issues/44) for the licensing decision.
