# Rush Protocol — vollständige Spielübersicht

**Projektname im Godot-Startfenster:** `Rush_Protocol`
**Setting dieser Ausbaustufe:** Blackglass Casino
**Engine:** Godot 4.7
**Genre:** taktisches 3D-Mehrspieler-/Solo-Spiel mit Rollenauswahl, Casino-Risikoaktionen, Schmuggel, Inventar und verdeckten Zielen

## 1. Spielidee

Die Spieler betreten ein luxuriöses Casino, in dem verschiedene Gruppen um Geld, Informationen und die Kontrolle über das Haus konkurrieren. Vor dem Einlass wird eine Rolle ausgewählt und ein begrenztes Loadout zusammengestellt. Die Sicherheitskontrolle kann nicht garantierte Schmuggel-Items entdecken und beschlagnahmen. Wer hineinkommt, versucht mit Chips, Ausrüstung, Einfluss und taktischen Entscheidungen weiter in das Gebäude vorzudringen, ohne dass Misstrauen und Aufmerksamkeit zu hoch werden.

Die zentrale Fantasie ist ein sozialer Heist-Thriller: Mafia, Militär, Assassinen, Ermittler, Casino-Elite und unauffällige Gäste verfolgen unterschiedliche Rollen. Pokerbetrug, Bestechung, falsche Identitäten und Waffen sind **rein fiktive Spielmechaniken**. Das Projekt gibt keine Anleitung zu realem Betrug, Schmuggel oder Gewalt.

## 2. Spielablauf im aktuellen Prototyp

1. **Spielstart und Modus:** Das Projekt hat Hauptmenü-Einstiegspunkte für Solo gegen KI, Lobby/Netzwerk und weitere lokale Match-Konfiguration.
2. **Charakterwahl:** Jeder Spieler wählt eine `CharacterClass`. Die Rolle legt Startwerte, Fraktion, Schmuggel-Slots, Startausrüstung, mögliche Loadout-Kategorien und ein narratives Ziel fest.
3. **Loadout:** Garantierte Rollen-Items kommen zusätzlich zu den wählbaren Slots ins Inventar. Wählbare Items müssen schmuggelbar sein und die erlaubten Kategorien der Rolle erfüllen. Die Prüfung geschieht in der UI und erneut in der Match-Logik.
4. **Einlasskontrolle:** Nicht garantierte Items werden anhand ihrer Entdeckungswahrscheinlichkeit kontrolliert. Misstrauen beeinflusst das Risiko; entdeckte Items können beschlagnahmt werden. Zu viel Misstrauen oder mehrere entdeckte Gegenstände ohne Bestechung können zum Rauswurf führen.
5. **Casino-Runden:** Runden besitzen die Zugphasen **Item**, **Aktion** und **Auflösung**. Items werden im Item-Schritt benutzt. In der Aktionsphase kann der aktuelle Risiko-Pool gezogen werden. Er verändert Chips und kann durch bestimmte Items beeinflusst werden.
6. **Vordringen und Ziele:** Der Match-Controller führt Spielerzonen, Status-Effekte, Chips, Gesundheit, Misstrauen, Heat, Items und Eliminierung. Der letzte nicht ausgeschiedene Spieler kann gewinnen; ein Vault-Ziel kann ebenfalls das Match beenden.
7. **Boss-Ebene:** Das Betreten der Penthouse-Zone löst derzeit das Signal für eine Bossbegegnung aus. Der Match-Controller enthält außerdem Boss-Gesundheit und eine Angriffs-/Siegfunktion. Eine ausgearbeitete Boss-Arena, Boss-UI und vollständige Fraktionsquest-Kette sind noch nicht fertig.

## 3. Casino-Welt und Etagen

Die Match-Szene baut zur Laufzeit einen vertikalen Casino-Turm aus Godot-3D-Geometrie auf. Jede Ebene hat eine farblich eigene Gestaltung, leuchtendes Etagen-Schild, Säulen, Geländer und Spieltische. Liftflächen bringen den Spieler beim Betreten zum Mittelpunkt der Nachbaretage; der Match-Zustand erhält dabei die passende Zone.

| Ebene | Ort | Zone-ID | Rolle im Spielstand |
|---|---|---|---|
| 1 | Spielhalle und öffentliche Tische | `lobby` | Einstieg und Casino-Flair |
| 2 | Goldener Salon / VIP | `vip_lounge` | gehobene Tische und High-Roller-Stimmung |
| 3 | Hinterzimmer / Schwarzmarkt | `backroom` | narrativer Bereich für diskrete Deals |
| 4 | Tresor-Korridor | `vault_corridor` | Übergang in die Hochsicherheitszone |
| 5 | Penthouse des Hausherrn | `boss_office` | löst die Bossbegegnungs-Phase aus |

**Wichtig zum aktuellen Stand:** Die Etagen sind im Spiel aufgebaut und die Aufzüge funktionieren als automatische Liftflächen. Zugangsschlüssel, gesperrte Türen, Händler-NPCs und unterschiedliche Regeln pro Etage sind noch nicht vollständig mit der Turm-Geometrie verbunden. Die Zone `vault_corridor` ist aktuell von der Match-Logikzone `vault` unterschieden.

## 4. Fraktionen und spielbare Rollen

Die Charaktere liegen als Datenressourcen unter `resources/characters/`. Gesundheit, Misstrauen, Heat, Einfluss und Chips sind Startwerte. Schmuggel-Slots zählen nur für frei gewählte Items; garantierte Items werden zusätzlich geführt und bei der Einlasskontrolle übersprungen.

| Rolle | Fraktion | Leben | Start-Misstrauen | Heat | Einfluss | Chips | Slots | Garantiertes Item | Erlaubte Loadout-Kategorien |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| Assassine | Assassinen-Gilde | 3 | 0 | 0 | 2 | 50 | 3 | Gift-Nadel | weapon, gadget, intel |
| Normalbürger | Zivilisten | 5 | 0 | 0 | 1 | 30 | 1 | — | alle schmuggelbaren Kategorien |
| Regierungsagent | Regierung | 3 | 0 | 1 | 4 | 60 | 2 | Fake-ID, Abhörwanze | intel, gadget, weapon, tool |
| Mafia-Boss | Mafia | 4 | 1 | 3 | 4 | 80 | 2 | Revolver | alle schmuggelbaren Kategorien |
| Militärischer Einsatzleiter | Militär | 5 | 0 | 1 | 3 | 45 | 1 | Revolver | intel, gadget, tool |
| Millionär | Casino-Elite | 3 | 2 | 2 | 5 | 150 | 2 | Falschmünze / Fake-Chip | chip, tool, disguise |
| Verdeckter Ermittler | Ermittler | 3 | 0 | 0 | 3 | 40 | 1 | KI-Linse | intel, gadget, tool |

Fähigkeits- und Ziel-IDs sind bereits in vielen Charakterressourcen hinterlegt (zum Beispiel `passive_fear_aura`, `active_mob_call`, `eliminate_rivals` oder `expose_criminals`). Die vollständige Ausführung dieser Rollenfähigkeiten ist ein offener Entwicklungsschritt, der in [Issue #4](https://github.com/Mr1Err0r1/rush_protocol/issues/4) festgehalten ist.

## 5. Inventar und Items

Itemdaten liegen als `ItemDefinition`-Ressourcen unter `resources/items/`; das Spiel lädt derzeit zwölf Item-Ressourcen. Kategorien und Entdeckungswerte beeinflussen die Loadout-Auswahl und Einlasskontrolle. Die Beschreibung eines Gegenstandes ist seine fiktionale Spielrolle; nicht jedes Item besitzt bereits einen vollständig polierten UI-Effekt.

| Item | Kategorie | Spielidee |
|---|---|---|
| KI-Linse (Stift-Kamera) | intel | verdeckte Beobachtung / Information |
| Kugelsicheres Schutzband | tool | einmaliger Schutz gegen Schaden |
| Falschmünze / Fake-Chip | chip | riskantes Spielen, Bestechung oder Ablenkung |
| Präparierte Karten | tool | manipuliert im aktuellen System das nächste Risiko-Ergebnis; Pokerregeln selbst fehlen noch |
| Gefälschter Ausweis | disguise | reduziert in der Datenbeschreibung Verdacht bzw. eröffnet eine VIP-Tarnung |
| Superkleberpatrone | tool | fiktionale Sabotage/Ablenkung |
| Feuerzeug | gadget | Ablenkung und Bereichseffekt |
| Abhörwanze | intel | Information über ein Ziel für begrenzte Runden |
| Gift-Nadel | weapon | fiktionaler, über mehrere Runden wirkender Effekt |
| Revolver | weapon | laute Schadensaktion; erzeugt zusätzlich Aufmerksamkeit |
| Mini-Rauchgranate | gadget | Rauch-/Ablenkungsaktion |
| Vault-Schlüssel (Kopie) | tool | Zugangswerkzeug als Risiko-Item |

Im zentralen Risiko-Pool sind standardmäßig vier positive und sechs negative Ergebnisse vorgesehen. Positive Ziehungen gewähren Chips, negative Ziehungen kosten Chips. Die präparierten Karten können ein positives Ergebnis erzwingen; ein erzwungenes Ergebnis wird vom Risiko-Controller gekennzeichnet. Das ist gegenwärtig eine abstrahierte Casino-Betrugsmechanik und **keine** vollständige Poker- oder Blackjack-Simulation.

Ein vollständiges Kartenspiel mit privaten Händen, Setzrunden, Fold/Call/Raise, Dealer-/Gegnerlogik und serverautoritativer Auflösung ist als [Issue #2](https://github.com/Mr1Err0r1/rush_protocol/issues/2) dokumentiert.

## 6. Steuerung

| Taste | Aktion im Prototyp |
|---|---|
| W / A / S / D | Bewegung |
| Maus | Blick/Kamera |
| Shift | Sprint |
| Leertaste | Springen |
| V | Angriffs-/Projektileingabe im Charaktercontroller-Prototyp |
| 1–4 | jeweiliges Hotbar-Item benutzen |
| Linksklick | Risiko-Aktion |
| T | Zielspieler wechseln |
| Enter | Zug beenden |
| F5 | Kameraansicht wechseln |
| Esc | Pause |
| E | reservierte Interaktionstaste; Casino-Aufzüge lösen derzeit beim Betreten der Liftfläche aus |

Die konkrete Verfügbarkeit einer Aktion hängt von Matchphase, aktivem Spieler und vorhandener Ausrüstung ab.

## 7. Projektaufbau

- `project.godot` — Godot-Projekteinstellungen, Eingaben und Autoloads.
- `autoload/` — Event-Bus, Match-/Save-/Audio-/Locale-/Item-Manager.
- `core/` — Charakter-, Spieler-, Risiko-, Match- und Einlasslogik.
- `resources/characters/` — Fraktionen, Startwerte, Ziele und Item-Slots.
- `resources/items/` — Item-Ressourcen.
- `scenes/world/` — Menü- und Match-Szenen.
- `scripts/world/casino_tower.gd` — prozedurale Casino-Geometrie und Liftwechsel.
- `scripts/ui/` — Menü, Charakterauswahl und Match-HUD.
- `scripts/items/` — Verhalten nach Gadget-, Werkzeug- und Waffenkategorien.

## 8. Grenzen und nächste Schritte

Das Projekt ist ein spielbarer Prototyp, kein fertiger Release. Die fünf Etagen, Rollenressourcen, Loadout-Kategorien und zentrale Match-Systeme sind vorhanden. Vollständige Poker-/Blackjack-Regeln, ausgewogene und klar angezeigte Item-Effekte, ausgebaute Fraktionsfähigkeiten, Zugangsvoraussetzungen je Etage, Boss-UI und Balancing sind noch offen. Die offenen Aufgaben sind in [Issue #2](https://github.com/Mr1Err0r1/rush_protocol/issues/2), [Issue #3](https://github.com/Mr1Err0r1/rush_protocol/issues/3) und [Issue #4](https://github.com/Mr1Err0r1/rush_protocol/issues/4) nachverfolgbar.

Die aktuell fehlenden Einstellungsübersetzungen werden im Feature-Branch ergänzt; das zugehörige Issue ist [Issue #3](https://github.com/Mr1Err0r1/rush_protocol/issues/3).

## 9. Projekt lokal testen

Mit Godot 4.7 oder neuer:

```bash
godot --headless --editor --path . --quit
godot --headless --path . res://scenes/world/match_world.tscn --quit-after 4
```
