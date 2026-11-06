# Rush Protocol — Blackglass Casino

**Rush Protocol** ist ein taktisches 3D-Spielprototype in Godot 4.7, angesiedelt in einem mehrstöckigen Casino. Wähle eine Rolle, stelle ein begrenztes Loadout zusammen, passiere eine fiktive Einlasskontrolle, verwalte Chips und Misstrauen und versuche, rivalisierende Fraktionen im Casinoturm auszuspielen.

> **Status:** Aktiver Prototyp / vor einem Release. Dieses Repository enthält kein fertiges oder produktionsreifes Spiel. Poker und Blackjack sind noch keine vollständigen spielbaren Tischspiele. Waffen, Schmuggel, Täuschung und Casino-Betrug sind fiktive Spielmechaniken; das Projekt liefert keine Anleitungen für die reale Welt.

## In deiner Sprache lesen

- [English (primary)](README.md) · [Full game overview](GAME_OVERVIEW.md)
- **Deutsch (diese Seite)** · [Ausführliche Spielübersicht](GAME_OVERVIEW.de.md)
- [Русский](README.ru.md) · [Полный обзор игры](GAME_OVERVIEW.ru.md)

Englisch ist die maßgebliche Projektdokumentation. Die deutsche und russische Fassung sind Übersetzungen; bei Abweichungen gilt die englische Version.

## Was der Prototyp enthält

- Eine fünfstöckige Casino-Turmwelt, die zur Laufzeit aus Godot-3D-Geometrie aufgebaut wird, mit thematischen Etagen und Liftbereichen.
- Einen Fraktion-zuerst-Charakterassistenten, der Rollen nach der gewählten Fraktion filtert und die zuletzt gewählte Rolle merkt.
- Charakterressourcen für Mafia, Assassinen-Gilde, Zivilisten, Militär, Regierung/Ermittler und Casino-Elite.
- Rollenabhängige Startwerte, garantierte Ausrüstung sowie Schmuggel- und Loadout-Regeln.
- Eine fiktive Einlasskontrolle, Misstrauen und Heat, Spielerinventar, Chips, Risikoaktionen und verschiedene Gadgets und Waffen.
- Grundlagen für Hauptmenü, Einstellungen, Speichern, HUD, Solo-/KI-Spiel und Netzwerk.

Einige Funktionen sind noch Prototypen oder datengetriebene Grundlagen. Das Penthouse signalisiert eine Bossbegegnung, aber vollständige Boss-Arena, Questkette und ausgearbeitete Boss-UI sind noch nicht fertig. Poker-/Blackjack-Regeln, Dealer-KI, Fraktionsfähigkeiten, Zugangssperren für Etagen, Balancing und finale Präsentation benötigen weitere Arbeit. Die [ausführliche Spielübersicht](GAME_OVERVIEW.de.md) dokumentiert Funktionen und Einschränkungen.

## Voraussetzungen und Start

- Godot **4.7 oder neuer** (das Projekt richtet sich an Godot 4.x).
- Git, falls du das Repository über die Kommandozeile klonst.

```bash
git clone https://github.com/Mr1Err0r1/rush_protocol.git
cd rush_protocol
```

Importiere und öffne `project.godot` in Godot und starte das Projekt. Die Hauptszene öffnet das Hauptmenü. Im Solo-Ablauf wählst du zuerst eine Fraktion und danach eine Rolle dieser Fraktion, bevor du Geschlecht und Loadout anpasst; die Menüpfade können sich während der Entwicklung ändern.

Für einen headless Editor-Import (Godot muss im `PATH` liegen):

```bash
godot --headless --editor --path . --quit
```

Dieser Importtest ersetzt weder einen vollständigen interaktiven Spieletest noch eine audiovisuelle Qualitätsprüfung. Das automatisierte Smoke-Testskript `scripts/test/run_headless_smoke.sh` prüft den Szenenstart und Engine-Fehler, ersetzt aber keine Spiel- oder Audio/Video-QA.

## Steuerung

Verfügbare Aktionen hängen von Szene und Matchphase ab. Standardbelegungen des Prototyps:

| Eingabe | Aktion |
|---|---|
| `W A S D` | Bewegen |
| Maus | Umschauen / Kamera |
| `Shift` | Sprinten |
| `Leertaste` | Springen |
| `1`–`4` | Entsprechendes Hotbar-Item verwenden |
| Linke Maustaste | Risikoaktion (falls verfügbar) |
| `T` | Zielspieler auswählen |
| `Enter` | Zug beenden |
| `V` | Prototyp-Angriffseingabe |
| `F5` | Kameramodus wechseln |
| `Esc` | Pause / zurück, abhängig vom Bildschirm |
| `E` | Reservierte Interaktionstaste; Liftbereiche lösen derzeit beim Betreten aus |

Einstellungen und Tastenbelegung können je nach Bildschirm variieren und sind teilweise noch in Entwicklung.

## Repository-Struktur

```text
autoload/               Globale Manager (Spiel, Speichern, Sprache, Items, Audio, Events)
core/                   Charakter-, Spieler-, Match- und Risikologik
resources/characters/   Charakter- und Fraktionsdaten
resources/items/        Itemdefinitionen
scenes/world/           Hauptmenü-, Spielwelt- und Match-Szenen
scripts/world/          Match-Setup und prozeduraler Casinoturm
scripts/ui/              Menüs, Charakterauswahl und HUD
scripts/items/           Itemverhalten
```

## Mitwirken und Projektdokumentation

Bitte eröffne vor größeren oder bereichsübergreifenden Änderungen ein Issue. Halte Änderungen fokussiert, committe nicht den generierten Godot-Cache `.godot/` und prüfe Ressourcenpfade und Szenen in Godot, bevor du einen Pull Request erstellst. Siehe `CONTRIBUTING.md`, falls vorhanden, und die [ausführliche Spielübersicht](GAME_OVERVIEW.de.md).

## Releases

Es gibt **noch kein stabiles oder produktives Release**. Das Repository befindet sich in aktiver Prototypentwicklung. Die Fraktion-zuerst-Auswahl ist implementiert, benötigt aber noch interaktive QA. Vor einem Release sollten der Kernspielablauf an den Tischen, zentrale Gameplay-Flows, Plattformtests, Lizenzfrage und reproduzierbarer Build geprüft sein. Der aktuelle Branch `main` ist kein fertiges Spiel und kein Release-Build.

## Lizenz

Zum Zeitpunkt dieser Dokumentation ist in diesem Repository **keine Lizenz bestätigt**. Bis eine Lizenz hinzugefügt wird, gilt das übliche Urheberrecht; bitte gehe nicht davon aus, dass der Code Open Source ist oder weiterverbreitet werden darf. Die Lizenzentscheidung wird in [Issue #44](https://github.com/Mr1Err0r1/rush_protocol/issues/44) nachverfolgt.
