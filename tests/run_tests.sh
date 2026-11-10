#!/usr/bin/env bash
# Führt alle tests/test_*.gd headless aus (Godot 4.7 im PATH oder GODOT=/pfad/zu/godot).
# Rückgabewert 0 = alles grün.
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
# Klassencache/Importe aktualisieren (nötig, sobald neue class_name-Dateien existieren)
"$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
for t in tests/test_*.gd; do
  out=$("$GODOT" --headless --path . res://tests/host.tscn -- "$t" 2>&1); code=$?
  summary=$(echo "$out" | grep -E "^(PASS|FAIL)" | tr '\n' ' ')
  if [ $code -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
    echo "✗ $t  ${summary:-<keine Testausgabe>}"; echo "$out" | grep -E "FAIL|ERROR" | head -15 | sed 's/^/    /'; fail=1
  else
    echo "✓ $t  $summary"
  fi
done
exit $fail
