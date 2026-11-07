#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT
export GODOT_SILENCE_ROOT_WARNING=1

run_case() {
  local label="$1"
  shift
  local log_file="$LOG_DIR/${label//[^a-zA-Z0-9_-]/_}.log"
  printf 'CHECK %s\n' "$label"
  if ! "$GODOT_BIN" --headless --path "$ROOT" "$@" >"$log_file" 2>&1; then
    cat "$log_file"
    printf 'FAIL %s: Godot exited unsuccessfully\n' "$label" >&2
    return 1
  fi
  # Godot may report cached resources as still referenced at hard process exit;
  # this is distinct from script/scene loading errors and is not actionable here.
  if grep -E '(^|[[:space:]])(ERROR|SCRIPT ERROR):|Parse Error:|Animation not found|invalid UID' "$log_file" \
      | grep -Ev '^ERROR: [0-9]+ resources still in use at exit'; then
    cat "$log_file" >&2
    printf 'FAIL %s: error-level engine output found\n' "$label" >&2
    return 1
  fi
  printf 'PASS %s\n' "$label"
}

run_case editor-import --editor --quit
run_case main-menu --quit-after 5

while IFS= read -r scene; do
  relative="${scene#"$ROOT"/}"
  resource_path="res://${relative}"
  label="scene-${relative%.tscn}"
  run_case "$label" "$resource_path" --quit-after 3
done < <(find "$ROOT/scenes" -type f -name '*.tscn' -print | sort)

printf 'All Godot smoke checks passed.\n'
