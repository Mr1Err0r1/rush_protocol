# Sounds

Alle Dateien hier sind **synthetische Platzhalter**, erzeugt mit `tools/audio/synth.py`
(numpy/scipy + ffmpeg, deterministischer Seed, keine fremden Samples).

- SFX: `ui_click`, `ui_hover`, `ui_confirm`, `risk_win`, `risk_lose`, `item_*`, `turn_start`, `player_die`, `match_over`
- Musik: `music_menu`, `music_match`, `music_tense` (nahtlose Loops), `music_gameover` (kein Loop)

Neu erzeugen: `python tools/audio/synth.py` (Ziel standardmäßig `assets/sounds/`).
Eigene Assets einfach unter gleichem Dateinamen ersetzen – die Zuordnung steht in `autoload/audio_manager.gd`.

Nach dem ersten Öffnen in Godot entstehen `*.ogg.import`-Dateien: bitte mit committen.
