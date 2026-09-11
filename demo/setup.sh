#!/usr/bin/env bash
# Isolated HOME plus an official solution so key 1 PASSes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOME_DIR="$ROOT/demo/home"
SOLUTION="$ROOT/langs/python3/problems/bank_system/solution.py"
WORK="$HOME_DIR/.honepad/work/bank_system/python3/work.py"

echo "PLAN: demo HOME at $HOME_DIR"
rm -rf "$HOME_DIR"
mkdir -p "$HOME_DIR"
export HOME="$HOME_DIR"
export HONEPAD_ROOT="$ROOT"
export PATH="$ROOT/.venv/bin:$PATH"
if ! command -v honepad >/dev/null 2>&1; then
  echo "FAIL: honepad not on PATH (install the editable venv)"
  exit 1
fi
honepad start bank_system python3 --no-console --reset --yes >/dev/null
cp "$SOLUTION" "$WORK"
echo "OK: $WORK"
echo "DONE: demo home ready"
echo "NEXT: sed \"s|__ROOT__|$ROOT|g\" demo/demo.tape > /tmp/honepad-demo.tape && vhs /tmp/honepad-demo.tape"
echo "NOTE: brew vhs 0.12.0 prints Creating then writes nothing. Use v0.11.0."
