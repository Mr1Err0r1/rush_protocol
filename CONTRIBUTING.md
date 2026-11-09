# Contributing to Rush Protocol

Thanks for helping improve the project. Keep each change focused and reviewable.

## Branches and pull requests

- Use one topic per branch with a descriptive prefix, for example `fix/...`, `feat/...`, `perf/...`, `docs/...`, or `chore/...`.
- Open pull requests against `main` and link the related issue in the PR body (`Closes #N`) when there is one.
- Explain what changed, why, and how it was validated. Do not claim a test passed unless it was actually run.

## Godot 4 project files

- Do not commit the generated `.godot/` cache, `*.tmp` editor files, or export output; the repository `.gitignore` excludes these.
- Keep source assets and Godot resource metadata needed by the project. Commit intentional `*.import` and `*.uid` files; before adding new sidecars, check that their source files exist and that their paths are valid.
- Put concept art under `idea/`. The tracked `idea/.gdignore` tells Godot not to import that folder as project resources; do not add runtime references to files there.
- Avoid committing generated caches or unrelated editor changes after running Godot. Check `git status` before staging.

## Local validation

For GDScript syntax checks, install the parser and run it over the project:

```bash
python3 -m pip install gdtoolkit==4.5.0
find . -name '*.gd' -not -path './.godot/*' -print0 | xargs -0 gdparse
```

For a headless Godot editor import check, with Godot 4.7 or newer available on `PATH`:

```bash
godot --headless --editor --path . --quit
```

These checks do not replace an interactive playtest of gameplay changes. Include untested cases in the pull request description.

## Placeholder audio

The files in `assets/sounds/` are synthetic placeholders, not final sound design. To regenerate them, use `tools/audio/synth.py`; it requires Python packages `numpy` and `scipy`, plus `ffmpeg` with Vorbis encoding support on `PATH`:

```bash
python3 -m pip install numpy scipy
python3 tools/audio/synth.py
```

The script uses a fixed random seed and writes to `assets/sounds/` by default. Review the generated files before committing regenerated assets.
