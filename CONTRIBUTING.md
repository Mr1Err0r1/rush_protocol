# Mitarbeiten

## Branches & PRs
- Ein Thema pro Branch (`fix/…`, `feat/…`, `perf/…`, `docs/…`, `chore/…`), PR gegen `main`.
- Zu jedem PR gehört ein Issue (`Closes #N` in der PR-Beschreibung).

## Was ins Repo gehört (Godot 4)
- **Nicht committen:** `.godot/`, `*.tmp`, Export-Ausgaben (steht in `.gitignore`).
- **Committen:** `*.import` und `*.uid` – sie enthalten Import-Einstellungen bzw. stabile Ressourcen-IDs.
- Konzeptkunst gehört nach `idea/` (wird per `.gdignore` nicht importiert).

## Lokale Prüfung
```bash
pip install gdtoolkit==4.5.0
find . -name '*.gd' -not -path './.godot/*' -print0 | xargs -0 gdparse   # Syntax
godot --headless --path . --quit-after 10                                 # Projekt lädt?
```

## Audio
Platzhalter-Sounds liegen in `assets/sounds/` und lassen sich mit `tools/audio/synth.py` neu erzeugen.
