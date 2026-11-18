# Rush Protocol — Spieldesign: Casino-Risikoschleife

**Sprachen:** [English (canonical)](GAME_DESIGN.md) · Deutsch · [Русский](GAME_DESIGN.ru.md)

Inspiriert von *Buckshot Roulette*: wenige Regeln, steigende Spannung, sichtbare Wahrscheinlichkeiten und eine verborgene Reihenfolge. Diese Referenz unterscheidet implementiertes Prototypverhalten von geplanter Arbeit. Die Zahlen und Standardwerte beruhen auf dem aktuellen Code (`CheckpointRules`, `RouletteTable`, `ItemDraft` und `GameManager`).

## Kernablauf

1. **Fraktion und Rolle wählen.** Der Fraktion-zuerst-Assistent filtert die Rollen nach der gewählten Gruppe.
2. **Loadout vorbereiten.** Rollen legen Startressourcen, Schmuggel-Slots, garantierte Items und Kategorieeinschränkungen fest.
3. **Einlasskontrolle bestehen.** Nicht garantierte Schmuggel-Items können entdeckt und beschlagnahmt werden; ein Rauswurf kann einen Spieler eliminieren.
4. **Eine Runde spielen.** Standardmäßig werden Items zufällig verteilt; alternativ können Spieler den optionalen Item-Draft nutzen.
5. **Den Turm durchqueren.** Beim ersten Betreten eines Kontrollpunkts auf einer oberen Etage kann eine Kontrolle ausgelöst werden; im Penthouse ist sie obligatorisch.
6. **Einsatz erhöhen.** Im optionalen Patronen-Risikomodus enthalten die Magazine auf höheren Etagen mehr Patronen und einen höheren Anteil scharfer Patronen.
7. **Um das Ziel konkurrieren.** Last-Man-Standing- und Tresor-Zielsieglogik existiert; die vollständige Bossbegegnung ist noch in Entwicklung.

## Fraktionen und Rollen

| Fraktion | Aktuell in Charakterressourcen vorhandene Rollen |
|---|---|
| Militär | Militärischer Einsatzleiter, Leutnant, Soldat |
| Geheimdienst | Agent, Analyst |
| Zivilisten | Normalbürger, Journalist, Zocker |
| Mafia | Mafia-Boss, Capo, Schläger, Buchhalter |
| Casino-Elite | Millionär |
| Ermittler | Verdeckter Ermittler |
| Assassinen-Gilde | Assassine |

Rollenressourcen liegen unter `resources/characters/*.tres` und werden in Auswahl und Galerie geladen. Einige Fähigkeits- und Ziel-IDs sind noch reine Daten und dürfen nicht mit fertig implementierten Fraktionsfähigkeiten verwechselt werden.

## Sicherheitskontrollen

Die Einlasskontrolle findet nach der Loadout-Auswahl immer statt. Die Tabelle zeigt die Wahrscheinlichkeit, dass ein Kontrollpunkt auf einer oberen Etage **beim ersten Betreten** ausgelöst wird, bei null Misstrauen und null Heat. Die Durchwinkchance der Fraktion ist bereits berücksichtigt; die Penthouse-Kontrolle ist obligatorisch. Der Wert 28,5 % wird exakt angegeben.

| Fraktion | Salon / VIP | Hinterzimmer | Tresor-Korridor | Penthouse | Durchwinkchance |
|---|---:|---:|---:|---:|---:|
| Zivilisten | 19 % | 28,5 % | 38 % | 100 % | 5 % |
| Mafia | 18 % | 27 % | 36 % | 100 % | 10 % |
| Militär | 18 % | 27 % | 36 % | 100 % | 10 % |
| Geheimdienst | 14 % | 21 % | 28 % | 100 % | 30 % |
| Ermittler | 16 % | 24 % | 32 % | 100 % | 20 % |
| Casino-Elite | 12 % | 18 % | 24 % | 100 % | 40 % |
| Assassinen-Gilde | 20 % | 30 % | 40 % | 100 % | 0 % |

Jeder Misstrauenspunkt addiert 3 Prozentpunkte, jeder Heat-Punkt 2 Prozentpunkte zur Auslösewahrscheinlichkeit; bei nicht obligatorischen Kontrollen wird danach der Fraktions-Durchwinkfaktor angewendet und das Ergebnis auf 0–100 % begrenzt. Rollenspezifische Einstellungen können Teile des Fraktionsprofils überschreiben.

Bei einer Kontrolle gelten für den Einlass (Etagenstrenge 1,0) folgende **Basis-Fundchancen**, bevor Misstrauen, Rollenresistenz oder Fraktionsverdeckung einfließen. Itemkategorie, Misstrauen, Rolle und Etagenstrenge können die endgültige Chance verändern.

| Item | Basis-Fundchance |
|---|---:|
| Revolver | 85 % |
| Kopie des Tresorschlüssels | 90 % |
| Schutzband | 65 % |
| Rauchgranate | 55 % |
| Präparierte Karten | 30 % |
| Gefälschter Ausweis | 20 % |
| Falschmünze / Fake-Chip | 15 % |
| Giftnadel | 10 % |
| Kleber | 8 % |
| Feuerzeug | 5 % |
| Abhörwanze | 3 % |
| KI-Linse | 2 % |

Beispiele für Fraktionsverdeckung: Militärwaffen ×0,7, Geheimdienst-Intel ×0,5 und Waffen der Assassinen-Gilde ×0,4. `detection_resistance` einer Rolle senkt die Fundchance. Etagen-Multiplikatoren der Fundchance: Salon ×0,6, Hinterzimmer ×0,9, Tresor-Korridor ×1,2 und Penthouse ×1,5.

Eine Kontrolle ohne Fund beschlagnahmt nichts; gefundener Schmuggel wird entfernt. Bei der Einlasskontrolle führen das Erreichen des Misstrauenslimits oder mindestens zwei Funde ohne gültige Bestechung zum Rauswurf und zur Eliminierung. An oberen Etagen-Kontrollpunkten schickt das Finden von mindestens zwei Items ohne Bestechung den Spieler normalerweise zurück und erhöht Heat um 1; wird dabei das Misstrauenslimit erreicht, hat der Rauswurf Vorrang. Eine gültige Bestechung erfordert die Falschmünze im Inventar oder mindestens 4 Einfluss. Ausgeworfene Spieler können sich nicht weiterbewegen und keine Tresor-/Boss-Effekte auslösen.

## Optionaler Patronen-Risikomodus (`risk_mode = "shells"`)

Standardmäßig bleibt der Chip-Pool aktiv. Für einen lokalen/Solo-Schnelltest kann `--roulette` hinter dem `--`-Trenner von Godot angegeben werden; dadurch wird `shells` in der Match-Konfiguration gesetzt.

| Höchste Etage eines lebenden Spielers | Patronen im Magazin | Erwartete scharfe Patronen |
|---|---:|---:|
| 1 — Lobby | 4 | 1,6 |
| 2 — Salon | 5 | 2,3 |
| 3 — Hinterzimmer | 6 | 3,0 |
| 4 — Tresor-Korridor | 7 | 3,9 |
| 5 — Penthouse | 8 | 4,8 |

Die Anzahl scharfer Patronen und Platzpatronen wird beim Laden/Nachladen angesagt; ihre Reihenfolge bleibt verborgen. Ein scharfer Schuss verursacht 1 Schaden (2 mit aktiver Säge); eine Platzpatrone verursacht keinen Schaden. Eine auf sich selbst abgefeuerte Platzpatrone gewährt eine Extra-Aktion; andere Schüsse beenden den Zug. Die Säge wird mit dem nächsten Schuss verbraucht, auch wenn es eine Platzpatrone ist. Die Lupe verrät ihrem Benutzer die aktuelle Patrone, Handschellen lassen ein Ziel einen Zug aussetzen, und ein Verbandskasten heilt bis zum Rollenmaximum. Ein Schutzschild kann einen Treffer abfangen. Dies ist ein kompakter Patronen-Risikomodus und kein vollständiges Poker- oder Blackjack-Tischspiel.

## Optionaler Item-Draft pro Runde (`item_mode = "draft"`)

Standardmäßig bleibt die zufällige Itemverteilung aktiv. Für einen lokalen/Solo-Schnelltest kann `--draft` hinter dem `--`-Trenner von Godot angegeben werden. Jeder Spieler erhält vier unterschiedliche Angebote; Items aus einer rollengerechten Kategorie haben das dreifache Auswahlgewicht. Ein Spieler kann bis zu zwei Items wählen, begrenzt durch freie Inventarplätze. Das Standard-Inventarlimit beträgt acht; bei vollem Inventar entfällt der Draft. KI-Spieler wählen automatisch, und die Runde wartet mit dem Zugstart, bis alle ausstehenden menschlichen Auswahlen abgeschlossen sind.

Beide Modus-Flags lassen sich kombinieren:

```bash
godot --path . -- --roulette --draft
```

Zu den erweiterten Match-Konfigurationsschlüsseln gehören `checkpoints`, `roulette_seed`, `draft_seed` und `inventory_capacity`; das sind Konfigurationswerte und keine zusätzlichen Kommandozeilen-Flags. Der Draft ist derzeit für Solo/Lokal/Hotseat implementiert. Eine Modusauswahl im Spielmenü und eine autoritative Online-Synchronisierung des Drafts sind noch Folgearbeiten.

## Tests und Grenzen

Verhaltens-/Regressionstests und Szenen-Smoke-Checks mit Godot 4.7.2 oder neuer ausführen:

```bash
GODOT=/pfad/zu/godot bash tests/run_tests.sh
GODOT_BIN=/pfad/zu/godot bash scripts/test/run_headless_smoke.sh
```

GitHub Actions führt die Regressionstests mit Godot 4.7.2-stable aus und schlägt fehl, wenn der Runner oder alle Testfälle fehlen. Automatisierte Prüfungen ersetzen keine interaktive, Multiplayer-, Balance-, Animations- oder Audio/Video-QA. Poker/Blackjack, Fraktionsfähigkeiten, eine vollständige Boss-Handlung, Modusauswahl im Menü und Release-Pakete sind noch nicht fertig. Schmuggel, Waffen, Bestechung und Täuschung sind fiktive Spielmechaniken und keine Anleitung für die reale Welt.
