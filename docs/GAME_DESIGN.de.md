# Rush Protocol – Spieldesign: Roulette-Schleife

Inspiriert von *Buckshot Roulette*: wenige Regeln, hohe Spannung, bekannte Wahrscheinlichkeiten, verborgene Reihenfolge.
Dieses Dokument beschreibt Ziel, aktuellen Umsetzungsstand und die offenen Punkte.
Alle Zahlen unten stammen aus dem Code (`CheckpointRules`, `RouletteTable`, `ItemDraft`) und sind durch Tests abgesichert.

## Die Spielschleife

1. **Fraktion und Rolle wählen** – z. B. Militär → Leutnant oder Soldat, Geheimdienst → Agent oder Analyst, Zivilisten (Normalbürger, Journalist, Zocker), Mafia → Boss, Capo, Schläger, Buchhalter.
2. **Items packen** – Rolle bestimmt Startkapital, Schmuggel-Slots und erlaubte Item-Kategorien.
3. **Einlasskontrolle am Casino** – jedes Schmuggel-Item wird mit einer Wahrscheinlichkeit gefunden (Rolle, Misstrauen, Item).
4. **Etage 1: erste Runde** – Item-Wahl (Draft), danach Züge am Tisch.
5. **Aufstieg** – beim ersten Betreten höherer Etagen kann eine **Etagenkontrolle** auslösen; das Penthouse wird immer kontrolliert.
6. **Je höher, desto gefährlicher** – das Magazin wird größer und enthält mehr scharfe Patronen.

## Fraktionen und Rollen

| Fraktion (UI) | Rollen |
|---|---|
| Militär | Militärischer Einsatzleiter, Leutnant, Soldat |
| Geheimdienst | Agent, Analyst |
| Zivilisten | Normalbürger, Journalist, Zocker |
| Mafia | Mafia-Boss, Capo, Schläger, Buchhalter |
| Elite / Polizei / Assassinen | Millionär / Verdeckter Ermittler / Assassine |

Rollen sind reine Daten (`resources/characters/*.tres`) und erscheinen automatisch in Auswahl und Galerie.
**Hinweis:** Die Fähigkeits-IDs (`passive_*`, `active_*`, `bonus_*`) sind aktuell nur Daten und noch nicht im Code umgesetzt.

## Kontrollen (Wahrscheinlichkeiten)

Chance, dass beim **ersten Betreten** einer Etage kontrolliert wird (Misstrauen 0, Heat 0). Misstrauen erhöht sie um 3 %, Heat um 2 % pro Punkt.

| Fraktion | Salon | Hinterzimmer | Tresor-Korridor | Penthouse | Durchwinken |
|---|---|---|---|---|---|
| Zivilisten | 19 % | 28 % | 38 % | 100 % | 5 % |
| Mafia | 18 % | 27 % | 36 % | 100 % | 10 % |
| Militär | 18 % | 27 % | 36 % | 100 % | 10 % |
| Geheimdienst | 14 % | 21 % | 28 % | 100 % | 30 % |
| Polizei | 16 % | 24 % | 32 % | 100 % | 20 % |
| Elite | 12 % | 18 % | 24 % | 100 % | 40 % |
| Assassinen | 20 % | 30 % | 40 % | 100 % | 0 % |

Wird kontrolliert, hat jedes Schmuggel-Item eine **Fundchance** (Einlass, Zivilist, Misstrauen 0):
Revolver 85 %, Vault-Schlüssel-Kopie 90 %, Schutzband 65 %, Rauchgranate 55 %, Präparierte Karten 30 %, Gefälschter Ausweis 20 %,
Fake-Chip 15 %, Giftnadel 10 %, Kleber 8 %, Feuerzeug 5 %, Abhörwanze 3 %, KI-Linse 2 %.
Fraktionen verstecken Kategorien besser (z. B. Militär Waffen ×0,7, Geheimdienst Intel ×0,5, Assassinen Waffen ×0,4); `detection_resistance` der Rolle senkt die Chance zusätzlich.
Etagenkontrollen sind strenger als der Einlass, je höher die Etage (Salon ×0,6 … Penthouse ×1,5).

Ergebnis: *nichts gefunden* · *beschlagnahmt* · bei ≥ 2 Funden ohne Bestechung (Einfluss ≥ 4) **zurückgeschickt** (Heat +1).

## Roulette-Modus (`risk_mode = "shells"`)

- Das Magazin enthält **scharfe** und **Platzpatronen**. Die Anzahlen werden angesagt, die Reihenfolge bleibt verborgen.
- Wer am Zug ist, schießt auf einen Gegner **oder auf sich selbst**.
- Scharf: Ziel verliert 1 Leben (2 mit Säge). Platzpatrone: nichts.
- **Platzpatrone auf sich selbst → Extra-Aktion.** Alles andere beendet den Zug.
- Leeres Magazin → neu laden, Anzahlen werden erneut angesagt.

| Etage | Patronen | scharf (Ø) |
|---|---|---|
| 1 Lobby | 4 | 1,6 |
| 2 Salon | 5 | 2,3 |
| 3 Hinterzimmer | 6 | 3,0 |
| 4 Tresor-Korridor | 7 | 3,9 |
| 5 Penthouse | 8 | 4,8 |

Die Stufe richtet sich nach der **höchsten Etage eines lebenden Spielers**.

Roulette-Items (nur in diesem Modus im Umlauf): **Lupe** (aktuelle Patrone ansehen), **Säge** (nächster Schuss doppelt),
**Handschellen** (Gegner setzt aus), **Verbandskasten** (+1 Leben). Die Schutzweste fängt einen Treffer ab.

## Item-Wahl pro Runde (`item_mode = "draft"`)

Statt Zufallsausgabe bekommt jeder Spieler ein Angebot (4 Items, Rollenkategorien 3× wahrscheinlicher) und wählt 2.
Das Inventar fasst 8 Items; ist es voll, entfällt die Wahl. KI-Spieler wählen automatisch.

## Modi ausprobieren

```text
godot --path . -- --roulette --draft
```
Entspricht `risk_mode = "shells"` und `item_mode = "draft"` in der Match-Config (`GameManager._default_match_config()`).
Weitere Schalter: `checkpoints` (Etagenkontrollen, Standard `true`), `roulette_seed` / `draft_seed` (reproduzierbar), `inventory_capacity`.

## Tests

```bash
bash tests/run_tests.sh      # Godot 4.7 im PATH oder GODOT=/pfad/zu/godot
```
Testet u. a. Rollen-Daten, Kontrollwahrscheinlichkeiten, den Roulette-Kern (2.000 Zufallsspiele), den Roulette-Modus im MatchController
(Hunderte simulierte Komplettspiele) und den Draft inklusive UI.

## Offene Punkte (siehe Issues)

- Charaktermodelle pro Rolle und **Personalisierung**, die tatsächlich am Modell sichtbar ist (die aktuelle Auswahl hat noch keine Wirkung).
- Fähigkeiten der Rollen umsetzen.
- Klügere KI für den Roulette-Modus (nutzt die angesagten Anzahlen).
- Menüschalter für Modi, Magazin-Anzeige im HUD, 3D-Präsentation (Waffe, Animationen).
- Zusammenspiel von Etagen-Aufstieg, Tischen und Boss im Roulette-Modus.
- Draft/Roulette online (Spieler-ID ↔ Peer), Inventar-Verwaltung (Items ablegen).
