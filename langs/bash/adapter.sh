#!/usr/bin/env bash
# Replay shared traces against a sourced bash solution.
# Functions print one JSON value. Bank booleans are true/false.
set -euo pipefail

hp_true() { HONEPAD_RESULT=true; }
hp_false() { HONEPAD_RESULT=false; }
hp_null() { HONEPAD_RESULT=null; }
hp_str() { HONEPAD_RESULT=$(jq -nc --arg s "${1-}" '$s'); }
hp_num() { HONEPAD_RESULT=$(jq -nc --argjson n "${1}" '$n'); }
hp_arr() { HONEPAD_RESULT=$(jq -nc --args '$ARGS.positional' -- "$@"); }

file=$1
cases_path=$3

exec 3>&1
exec 1>/dev/null

# shellcheck source=/dev/null
source "$file"

failed='[]'
passed=0

n_cases=$(jq 'length' "$cases_path")
ci=0
while ((ci < n_cases)); do
  cid=$(jq -r --argjson i "$ci" '.[$i].id' "$cases_path")
  n_calls=$(jq --argjson i "$ci" '.[$i].calls | length' "$cases_path")
  if declare -F new >/dev/null 2>&1; then
    new
  fi
  ok=1
  i=0
  while ((i < n_calls)); do
    method=$(jq -r --argjson ci "$ci" --argjson i "$i" '.[$ci].calls[$i].m' "$cases_path")
    expected=$(jq -c --argjson ci "$ci" --argjson i "$i" '.[$ci].calls[$i].e' "$cases_path")
    args=()
    while IFS= read -r line; do
      args+=("$line")
    done < <(jq -r --argjson ci "$ci" --argjson i "$i" '.[$ci].calls[$i].a[] | tostring' "$cases_path")

    if ! declare -F "$method" >/dev/null 2>&1; then
      actual=$(jq -n --arg s "exc:missing" '$s')
      failed=$(
        jq -c --arg case "$cid" --argjson index "$i" --arg method "$method" \
          --argjson expected "$expected" --argjson actual "$actual" \
          '. + [{case:$case, index:$index, method:$method, expected:$expected, actual:$actual}]' \
          <<<"$failed"
      )
      ok=0
      break
    fi

    HONEPAD_RESULT=""
    builtin set +e
    if ((${#args[@]} == 0)); then
      "$method"
    else
      "$method" "${args[@]}"
    fi
    rc=$?
    builtin set -e
    stdout=${HONEPAD_RESULT-}
    if ((rc != 0)); then
      actual=$(jq -n --arg s "exc:status" '$s')
      failed=$(
        jq -c --arg case "$cid" --argjson index "$i" --arg method "$method" \
          --argjson expected "$expected" --argjson actual "$actual" \
          '. + [{case:$case, index:$index, method:$method, expected:$expected, actual:$actual}]' \
          <<<"$failed"
      )
      ok=0
      break
    fi

    if ! actual=$(jq -nc --argjson v "$stdout" '$v' 2>/dev/null); then
      actual=$(jq -n --arg s "$stdout" '$s')
    fi

    if [[ "$(jq -nc --argjson a "$actual" --argjson e "$expected" '$a == $e')" != "true" ]]; then
      failed=$(
        jq -c --arg case "$cid" --argjson index "$i" --arg method "$method" \
          --argjson expected "$expected" --argjson actual "$actual" \
          '. + [{case:$case, index:$index, method:$method, expected:$expected, actual:$actual}]' \
          <<<"$failed"
      )
      ok=0
      break
    fi
    i=$((i + 1))
  done
  if ((ok == 1)); then
    passed=$((passed + 1))
  fi
  ci=$((ci + 1))
done

jq -nc --argjson passed "$passed" --argjson failed "$failed" '{passed:$passed, failed:$failed}' >&3
if [[ "$failed" != "[]" ]]; then
  exit 1
fi
exit 0
