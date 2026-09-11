#!/usr/bin/env bash
# Fresh HOME. No session. The tape starts honepad start and picks
# python3 + bank_system. keep-solution.sh recopies the official
# solution after each unlock merge.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOME_DIR="$ROOT/demo/home"
echo "PLAN: empty demo HOME at $HOME_DIR"
rm -rf "$HOME_DIR"
mkdir -p "$HOME_DIR"
if [[ ! -x "$ROOT/.venv/bin/honepad" ]]; then
  echo "FAIL: $ROOT/.venv/bin/honepad missing (pip install -e .)"
  exit 1
fi
echo "OK: empty home"
echo "DONE: demo home ready"
echo "NEXT: sed \"s|__ROOT__|$ROOT|g\" demo/demo.tape > /tmp/honepad-demo.tape && vhs /tmp/honepad-demo.tape"
echo "NOTE: brew vhs 0.12.0 writes no file. Use v0.11.0."
