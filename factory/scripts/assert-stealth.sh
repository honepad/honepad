#!/usr/bin/env bash
# Check that a public launch has discovery metadata.
# Usage: assert-stealth.sh OWNER/REPO
# Exit 0 launched, 1 missing, 2 cannot query.
set -euo pipefail

echo "PLAN: assert launch metadata for ${1:-missing}"

if [[ $# -ne 1 || "$1" != */* ]]; then
  echo "FAIL: usage: assert-stealth.sh OWNER/REPO"
  echo "DONE: ok=false error=usage"
  exit 2
fi

repo="$1"
leaks=0

if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh not on PATH"
  echo "DONE: ok=false error=no-gh"
  exit 2
fi

echo "DO: query GitHub repo About"
if ! repo_json="$(gh repo view "$repo" --json description,homepageUrl,repositoryTopics,isPrivate 2>/dev/null)"; then
  echo "FAIL: gh repo view $repo"
  echo "DONE: ok=false error=gh-repo-view"
  exit 2
fi

check_set() {
  local label="$1" value="$2"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "FAIL: $label is empty"
    leaks=$((leaks + 1))
  else
    echo "OK: $label set"
  fi
}

desc="$(printf '%s' "$repo_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("description") or "")')"
home="$(printf '%s' "$repo_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("homepageUrl") or "")')"
topics="$(printf '%s' "$repo_json" | python3 -c 'import json,sys; t=json.load(sys.stdin).get("repositoryTopics") or []; print(",".join(x.get("name","") if isinstance(x,dict) else str(x) for x in t))')"
private="$(printf '%s' "$repo_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("isPrivate"))')"

check_set "description" "$desc"
check_set "homepage" "$home"
check_set "topics" "$topics"

if [[ "$private" == "True" || "$private" == "true" ]]; then
  echo "FAIL: repo is private"
  leaks=$((leaks + 1))
else
  echo "OK: repo is public"
fi

echo "DO: scan local tree if cwd is a git checkout"
if [[ -f README.md ]]; then
  if grep -Eiq 'not ready' README.md; then
    echo "FAIL: README still says Not ready"
    leaks=$((leaks + 1))
  fi
  if ! grep -Eiq 'pip install honepad|honepad start' README.md; then
    echo "FAIL: README missing install or start"
    leaks=$((leaks + 1))
  else
    echo "OK: README has install and start"
  fi
fi

if [[ ! -f .github/FUNDING.yml ]]; then
  echo "FAIL: .github/FUNDING.yml missing"
  leaks=$((leaks + 1))
else
  echo "OK: FUNDING.yml present"
fi

if [[ -f pyproject.toml ]]; then
  if grep -Eq 'description = "Reserved\."' pyproject.toml; then
    echo "FAIL: pyproject.toml description is still Reserved"
    leaks=$((leaks + 1))
  else
    echo "OK: pyproject.toml description is set"
  fi
fi

if [[ "$leaks" -gt 0 ]]; then
  echo "DONE: ok=false leaks=$leaks"
  echo "NEXT: fill the FAIL fields"
  exit 1
fi

echo "DONE: ok=true leaks=0"
echo "NEXT: keep the public README and About in sync"
exit 0
