# Rush Protocol — Blackglass Casino

**Rush Protocol** ist ein taktisches 3D-Spiel in Godot 4.7: Schleuse Ausrüstung ins Casino, bluffe an den Spieltischen, verwalte Chips und Misstrauen und entscheide, ob du als Syndikat, Ermittler, Einsatzkraft oder unauffälliger Gast die Kontrolle übernimmst.

Die vollständige Beschreibung von Spielschleife, Etagen, Rollenwerten, Fraktionen, Inventar, Items, Steuerung und aktuellem Entwicklungsstand steht in [GAME_OVERVIEW.md](GAME_OVERVIEW.md).

> Alle Waffen, Schmuggelobjekte und Täuschungsaktionen sind fiktive Spielmechaniken. Das Spiel beschreibt keine realen Methoden.

## Das Spiel in Kürze

Die Partie führt vom Charakter und Loadout über die Einlasskontrolle in die Casino-Runden. Spieler sammeln Chips und Items, nutzen ihre Ausrüstung, wagen riskante Aktionen und versuchen, unentdeckt vorzudringen. Die Casino-Welt ist als mehrstöckiger Schauplatz mit Aufzügen angelegt:

1. **Spielhalle** — Poker-, Blackjack-, Roulette- und High-Stakes-Tische; hier beginnt der Run.
2. **Goldener Salon (VIP)** — teure Tische, mehr Einfluss und mehr Aufmerksamkeit.
3. **Hinterzimmer / Schwarzmarkt** — diskrete Deals und ein riskanter Weg an Security vorbei.
4. **Tresor-Korridor** — Zugang zur gesicherten Zone; hier zählen Schlüssel, Chips und Vertrauen.
5. **Penthouse des Hausherrn** — finale Konfrontation um das Casino.

Die Etagen werden beim Start der Match-Welt prozedural aus Godot-Meshes aufgebaut. Betritt einen markierten Liftbereich, um die nächste Ebene zu erreichen. Die Etage wird außerdem in der Spielerposition erfasst.

## Fraktionen und Rollen

- **Mafia** — Einfluss, Einschüchterung und Kontrolle über das Haus.
- **Militär** — hohe Widerstandskraft; startet mit einer fiktiven, dienstlichen Revolver-Ausrüstung.
- **Zivilisten** — wenig Vorbereitung, dafür leicht zu unterschätzen.
- **Assassinen-Gilde** — lautloser Stil und Gift-Nadel als Startausrüstung.
- **Regierung und Ermittler** — Zugang, Beobachtung und Aufklärung.
- **Casino-Elite** — viele Start-Chips und Möglichkeiten, andere zu beeinflussen.

Fraktions-IDs sind Daten an den Charakter-Ressourcen (`resources/characters/*.tres`) und erscheinen in der Charakterauswahl. Neue Rollen können als weitere `CharacterClass`-Resource ergänzt werden.

## Schmuggel, Inventar und Casino-Betrug

Das Loadout-System und die Einlasskontrolle sind bereits Teil des Spiels. Charaktere haben eigene Schmuggel-Slots, Startwerte und garantierte Items; nicht garantierte Gegenstände können bei einer Kontrolle auffliegen. Das Inventar ist pro Spieler geführt. Vorhandene Ausrüstung umfasst unter anderem Falsch-Chips, gezinkte Karten, gefälschte Ausweise, Abhör-/Analyse-Gadgets, Schutzweste, Rauchgranate, Revolver, Gift-Nadel und Tresorschlüssel-Kopie.

Der Risiko-Pool liefert Gewinne oder Verluste. Die gezinkten Karten (`fake_cards`) können das nächste Ergebnis manipulieren; ein erzwungenes Ergebnis wird vom Risiko-Controller verwaltet. Das ist die Grundlage für weiter ausbaubare Tischspiele wie Poker und Blackjack. Es handelt sich derzeit **nicht** um vollständige Pokerregeln mit Kartenhand, Setzrunden und KI-Dealer — die Tischspiele sind aktuell Welt-/Konzeptpunkte und der manipulierbare Risiko-Pool die vorhandene Casino-Mechanik.

## Steuerung

- **W/A/S/D** — bewegen
- **Maus** — Kamera bewegen
- **Shift** — sprinten
- **Leertaste** — springen
- **E** — reservierte Interaktionstaste; die Aufzüge lösen im aktuellen Prototyp beim Betreten der Liftfläche aus
- **1–4** — Item aus der Hotbar verwenden
- **Linksklick** — Risiko-Aktion
- **T** — Zielspieler wechseln
- **Enter** — Zug beenden
- **V** — Angriff (Prototyp-Aktion)
- **F5** — Kamera-Modus wechseln
- **Esc** — Pause

## Starten

1. Godot **4.7** öffnen.
2. Dieses Repository als Projekt importieren.
3. `project.godot` starten; die Hauptszene ist das Hauptmenü.
4. Solo-Spiel starten, Charakter auswählen und Loadout bestätigen.

Headless-Import/Editorprüfung:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 10
scripts/test/run_headless_smoke.sh
```

## Projektstruktur

```text
autoload/               Globale Manager (Match, Items, Netzwerk, Saves, Audio)
core/                   Charakter-, Spieler-, Match- und Risiko-Logik
resources/characters/   Rollen-/Fraktionsdaten als Godot-Resources
resources/items/        Item-Daten als Godot-Resources
scenes/world/           Menü, Welt und Match-Szenen
scripts/world/          Match-Setup und prozeduraler Casino-Turm
scripts/items/           Itemverhalten, nach Kategorien organisiert
scripts/ui/              Charakterauswahl, Match-HUD, Menüs
```

## Aktueller Entwicklungsstand

Dieses Repository ist ein aktiver Prototyp, kein fertiges Online-Casino-Spiel. Solo-/Hotseat-/Netzwerk-Grundlagen, Charakterauswahl, Einlass-/Schmuggel-Logik, Risikoaktionen, Items, HUD und Save-/Menüsystem sind im Code angelegt. Die Casino-Etagen sind ein spielbarer 3D-Schauplatz-Prototyp. Vollständige Poker-/Blackjack-Regeln, Dealer-KI, Fraktionsquests, Boss-Phasen mit eigener Arena und Balancing sind sinnvolle nächste Meilensteine.

## Lizenz und Beiträge

Siehe Repository-Lizenz, falls vorhanden. Für Änderungen bitte Godot-Import und Projektstart testen und Ressourcen-Referenzen in `.tscn`/`.tres` auf vorhandene Dateien prüfen.
