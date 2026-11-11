# Rush Protocol — Spielübersicht

**Sprachen:** [English (canonical)](GAME_OVERVIEW.md) · Deutsch · [Русский](GAME_OVERVIEW.ru.md)

**Projekttitel in Godot:** `Rush_Protocol`
**Setting:** Blackglass Casino
**Engine:** Godot 4.7
**Genre:** Taktischer 3D-Multiplayer-/Solo-Prototyp mit Charakterrollen, Casino-Risikoaktionen, Schmuggel, Inventar und verdeckten Zielen

## 1. Spielidee

Die Spieler betreten ein luxuriöses Casino, in dem rivalisierende Gruppen Geld, Informationen und die Kontrolle über das Haus suchen. Vor dem Eintritt wählt jeder eine Rolle und stellt ein begrenztes Loadout zusammen. Bei einer fiktiven Einlasskontrolle können nicht garantierte Schmuggelgegenstände entdeckt und beschlagnahmt werden. Im Casino verwalten die Spieler Chips, Ausrüstung, Einfluss und Misstrauen und versuchen, weiter ins Gebäude vorzudringen.

Der gewünschte Ton ist ein sozialer Heist-Thriller: Mafia, Militär, Assassinen, Ermittler, Casino-Elite und gewöhnliche Gäste verkörpern unterschiedliche Rollenfantasien. Pokerbetrug, Bestechung, falsche Identitäten und Waffen sind **fiktive Spielmechaniken**. Das Projekt ist keine Anleitung zu realem Betrug, Schmuggel oder Gewalt.

## 2. Aktueller Prototyp-Spielablauf

1. **Start und Modus:** Das Hauptmenü bietet Einstiegspunkte für Solo gegen KI, Lobby/Netzwerk und lokale Match-Konfiguration. Manche Abläufe befinden sich noch in Entwicklung.
2. **Fraktion zuerst:** Spieler wählen zuerst eine Fraktion; danach zeigt die Rollenliste nur verfügbare Rollen dieser Fraktion. Die zuletzt gewählte Rolle merkt sich das Spiel für den nächsten Besuch. Eine Rollenressource definiert Startwerte, Schmuggel-Slots, garantierte Ausrüstung, erlaubte Loadout-Kategorien und ein narratives Ziel.
3. **Loadout:** Garantierte Rollen-Items werden getrennt von auswählbaren Slots hinzugefügt. Optionale Items müssen schmuggelbar sein und Rollenbeschränkungen erfüllen. Prüfungen existieren sowohl in der Auswahl-UI als auch in der Match-Logik.
4. **Einlasskontrolle:** Nicht garantierte Items können abhängig von ihrer Entdeckungswahrscheinlichkeit auffliegen. Misstrauen beeinflusst die Kontrolle; entdeckte Items können beschlagnahmt werden. Zu hohes Misstrauen kann zum Rauswurf führen.
5. **Casino-Züge:** Der Match-Controller verfolgt Phasen wie Itemnutzung, Aktion und Auflösung. Risikoaktionen können Chips verändern und durch ausgewählte Items beeinflusst werden.
6. **Fortschritt und Ziele:** Der Matchzustand verwaltet Spieler, Zonen, Statuseffekte, Chips, Gesundheit, Misstrauen, Heat, Inventar und Eliminierungen. Last-Man-Standing- und Tresor-Zielsieglogik sind prototypisch vorhanden.
7. **Penthouse/Boss-Signal:** Das Betreten der Penthouse-Zone kann eine Bossbegegnung signalisieren. Bossgesundheit und Angriffs-/Sieg-Hooks gibt es, die vollständige Begegnung ist aber noch nicht fertig.

## 3. Casinoturm

Die Match-Szene erstellt zur Laufzeit einen vertikalen Casinoturm aus Godot-3D-Geometrie. Die Etagen unterscheiden sich durch Gestaltung, Beschilderung, Säulen, Geländer und Tische. Liftbereiche bewegen Spieler zwischen benachbarten Etagen und aktualisieren den zugehörigen Zonenstatus.

| Etage | Ort | Zonen-ID | Aktuelle Funktion |
|---|---|---|---|
| 1 | Spielhalle und öffentliche Tische | `lobby` | Eingangsbereich und Casino-Setting |
| 2 | Goldener Salon / VIP | `vip_lounge` | High-Roller-Atmosphäre |
| 3 | Hinterzimmer / Schwarzmarkt | `backroom` | Erzählort für diskrete Deals |
| 4 | Tresor-Korridor | `vault_corridor` | Übergang zu einem gesicherten Bereich |
| 5 | Penthouse des Eigentümers | `boss_office` | Signalisiert die Bossphase |

**Einschränkungen:** Etagen und Liftbereiche existieren im Prototyp. Schlüsselgesicherte Türen, Händler, vollständig unterschiedliche Regeln pro Etage und eine komplette Sicherheitsprogression sind noch nicht integriert. `vault_corridor` und die Match-Logikzone `vault` sind getrennte IDs.

## 4. Fraktionen und Charakterrollen

Charaktere liegen als Datenressourcen unter `resources/characters/`. Startwerte umfassen Gesundheit, Misstrauen, Heat, Einfluss und Chips. Schmuggel-Slots gelten für ausgewählte Items; garantierte Rollenausrüstung wird separat geführt und umgeht die gewöhnliche Einlasskontrolle.

| Rolle | Fraktion | Leben | Misstrauen | Heat | Einfluss | Chips | Slots | Garantierte Items |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Assassine | Assassinen-Gilde | 3 | 0 | 0 | 2 | 50 | 3 | Gift-Nadel |
| Zivilist | Zivilisten | 5 | 0 | 0 | 1 | 30 | 1 | — |
| Regierungsagent | Regierung | 3 | 0 | 1 | 4 | 60 | 2 | Fake-ID, Abhörwanze |
| Mafia-Boss | Mafia | 4 | 1 | 3 | 4 | 80 | 2 | Revolver |
| Militärischer Einsatzleiter | Militär | 5 | 0 | 1 | 3 | 45 | 1 | Revolver |
| Millionär | Casino-Elite | 3 | 2 | 2 | 5 | 150 | 2 | Falschmünze / Fake-Chip |
| Verdeckter Ermittler | Ermittler | 3 | 0 | 0 | 3 | 40 | 1 | KI-Linse |

Charakterressourcen enthalten außerdem Fähigkeits- und Ziel-IDs (zum Beispiel `passive_fear_aura`, `active_mob_call`, `eliminate_rivals` und `expose_criminals`). Nicht alle aufgeführten Fähigkeiten sind vollständig spielmechanisch implementiert; Fraktionsfähigkeiten und Boss-Handlungsbogen sind noch Entwicklungsarbeit, dokumentiert in [Issue #4](https://github.com/Mr1Err0r1/rush_protocol/issues/4).

## 5. Inventar und Items

Itemdefinitionen sind Godot-Ressourcen unter `resources/items/`. Die aktuelle Sammlung umfasst Informationswerkzeuge, Schutzitems, Falsch-Chips, präparierte Karten, Tarnungen, Gadgets, Waffen und einen Schlüsselkopie-Tresorwerkzeug. Beschreibungen zeigen die beabsichtigte fiktionale Rolle; nicht jedes Item verfügt über einen polierten Effekt oder UI-Rückmeldung.

Der Risiko-Pool ist eine abstrakte Casino-Aktion mit positiven und negativen Ergebnissen, die Chips verändern. Präparierte Karten können ein günstiges Risikoergebnis erzwingen. Das ist **keine** vollständige Poker- oder Blackjack-Implementierung: Es gibt noch keine vollständigen privaten Hände, Setzrunden, Fold/Call/Raise-Regeln, Dealer-/Gegnerlogik oder autoritative Auflösung am Spieltisch. Vollständige Kartentische und ausgewogene Gegenmechaniken sind in [Issue #2](https://github.com/Mr1Err0r1/rush_protocol/issues/2) erfasst.

## 6. Steuerung

| Eingabe | Prototyp-Aktion |
|---|---|
| `W` / `A` / `S` / `D` | Bewegung |
| Maus | Umschauen / Kamera |
| `Shift` | Sprint |
| `Leertaste` | Springen |
| `1`–`4` | Entsprechendes Hotbar-Item verwenden |
| Linke Maustaste | Risikoaktion, falls verfügbar |
| `T` | Zielspieler wählen |
| `Enter` | Zug beenden |
| `V` | Prototyp-Angriffseingabe |
| `F5` | Kameramodus wechseln |
| `Esc` | Pause / zurück, je nach Bildschirm |
| `E` | Reservierte Interaktion; Liftbereiche lösen derzeit beim Betreten aus |

Verfügbare Aktionen hängen vom aktiven Spieler, der Matchphase und der Ausrüstung ab. Tastenbelegung und Menüs können sich während der Entwicklung ändern.

## 7. Projektstruktur

- `project.godot` — Projekteinstellungen, Input-Map und Autoloads.
- `autoload/` — Event-Bus sowie Spiel-, Save-, Audio-, Locale- und Item-Manager.
- `core/` — Charakter-, Spieler-, Match-, Risiko- und Einlasskontrolllogik.
- `resources/characters/` — Fraktions-, Werte-, Ziel- und Item-Slot-Daten.
- `resources/items/` — Itemressourcen.
- `scenes/world/` — Menü-, Welt- und Match-Szenen.
- `scripts/world/casino_tower.gd` — prozedurale Casino-Geometrie und Liftübergänge.
- `scripts/ui/` — Menüs, Charakterauswahl und Match-HUD.
- `scripts/items/` — Verhalten von Gadgets, Werkzeugen und Waffen.

## 8. Bekannte Grenzen und nächste Schritte

Dies ist ein aktiver Prototyp, kein fertiges Spiel oder Release-Build. Die fünfstöckige Welt, Rollenressourcen, Loadout-Kategorien und zentrale Match-Systeme sind eine Grundlage. Zu den großen offenen Punkten zählen vollständige Poker-/Blackjack-Spielabläufe, verständliche und ausgewogene Itemeffekte, implementierte Fraktionsfähigkeiten, Zugangsvoraussetzungen für Etagen, eine fertige Bossbegegnung, Onboarding, vollständige Lokalisierung, Plattform-QA und Balancing. Aktuelle Arbeit wird in den [GitHub-Issues](https://github.com/Mr1Err0r1/rush_protocol/issues) verfolgt.

## 9. Lokal testen

Für einen headless Editor-Import Godot 4.7 oder neuer verwenden:

```bash
godot --headless --editor --path . --quit
```

Dieser Importtest bestätigt weder Gameplay-Balancing noch Online-Funktion, audiovisuelle Qualität oder Release-Reife. Ein wiederverwendbares automatisiertes Szenen-Smoke-Testskript ist in [PR #11](https://github.com/Mr1Err0r1/rush_protocol/pull/11) vorgeschlagen und noch nicht Teil von `main`.
