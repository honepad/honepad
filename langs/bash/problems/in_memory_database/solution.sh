#!/usr/bin/env bash
# Reference in-memory database. Shared public traces.

new() {
  unset DB EXPIRY
  declare -gA DB EXPIRY
  DB=()
  EXPIRY=()
  BACKUP_TS=()
  BACKUP_STATE=()
}

_key() {
  printf '%s\x1f%s' "$1" "$2"
}

_set_internal() {
  local key=$1 field=$2 value=$3 expiry=$4
  local k
  k=$(_key "$key" "$field")
  DB[$k]=$value
  EXPIRY[$k]=$expiry
  hp_str ""
}

_is_alive() {
  local key=$1 field=$2 timestamp=$3
  local k
  k=$(_key "$key" "$field")
  if [[ -z "${DB[$k]+x}" ]]; then
    return 1
  fi
  local expiry=${EXPIRY[$k]}
  if [[ -z "$expiry" ]]; then
    return 0
  fi
  if ((timestamp < expiry)); then
    return 0
  fi
  return 1
}

set() {
  _set_internal "$1" "$2" "$3" ""
}

get() {
  local key=$1 field=$2
  local k
  k=$(_key "$key" "$field")
  if [[ -z "${DB[$k]+x}" ]]; then
    hp_str ""
    return 0
  fi
  hp_str "${DB[$k]}"
}

delete() {
  local key=$1 field=$2
  local k
  k=$(_key "$key" "$field")
  if [[ -z "${DB[$k]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  unset "DB[$k]"
  unset "EXPIRY[$k]"
  hp_str "true"
}

_scan_join() {
  local -a items=("$@")
  if ((${#items[@]} == 0)); then
    hp_str ""
    return 0
  fi
  local sorted item out=""
  sorted=$(printf '%s\n' "${items[@]}" | sort)
  while IFS= read -r item; do
    if [[ -z "$item" ]]; then
      continue
    fi
    if [[ -n "$out" ]]; then
      out+=", "
    fi
    out+="$item"
  done <<<"$sorted"
  hp_str "$out"
}

scan() {
  local key=$1
  local k field items=()
  if ((${#DB[@]} > 0)); then
    for k in "${!DB[@]}"; do
      if [[ "$k" == "$key"$'\x1f'* ]]; then
        field=${k#*$'\x1f'}
        items+=("${field}(${DB[$k]})")
      fi
    done
  fi
  _scan_join "${items[@]+"${items[@]}"}"
}

scan_by_prefix() {
  local key=$1 prefix=$2
  local k field items=()
  if ((${#DB[@]} > 0)); then
    for k in "${!DB[@]}"; do
      if [[ "$k" == "$key"$'\x1f'* ]]; then
        field=${k#*$'\x1f'}
        if [[ "$field" == "$prefix"* ]]; then
          items+=("${field}(${DB[$k]})")
        fi
      fi
    done
  fi
  _scan_join "${items[@]+"${items[@]}"}"
}

set_at() {
  _set_internal "$1" "$2" "$3" ""
}

set_at_with_ttl() {
  local key=$1 field=$2 value=$3 timestamp=$4 ttl=$5
  _set_internal "$key" "$field" "$value" "$((timestamp + ttl))"
}

delete_at() {
  local key=$1 field=$2 timestamp=$3
  if ! _is_alive "$key" "$field" "$timestamp"; then
    hp_str "false"
    return 0
  fi
  local k
  k=$(_key "$key" "$field")
  unset "DB[$k]"
  unset "EXPIRY[$k]"
  hp_str "true"
}

get_at() {
  local key=$1 field=$2 timestamp=$3
  if ! _is_alive "$key" "$field" "$timestamp"; then
    hp_str ""
    return 0
  fi
  local k
  k=$(_key "$key" "$field")
  hp_str "${DB[$k]}"
}

scan_at() {
  local key=$1 timestamp=$2
  local k field items=()
  if ((${#DB[@]} > 0)); then
    for k in "${!DB[@]}"; do
      if [[ "$k" == "$key"$'\x1f'* ]]; then
        field=${k#*$'\x1f'}
        if _is_alive "$key" "$field" "$timestamp"; then
          items+=("${field}(${DB[$k]})")
        fi
      fi
    done
  fi
  _scan_join "${items[@]+"${items[@]}"}"
}

scan_by_prefix_at() {
  local key=$1 prefix=$2 timestamp=$3
  local k field items=()
  if ((${#DB[@]} > 0)); then
    for k in "${!DB[@]}"; do
      if [[ "$k" == "$key"$'\x1f'* ]]; then
        field=${k#*$'\x1f'}
        if [[ "$field" == "$prefix"* ]] && _is_alive "$key" "$field" "$timestamp"; then
          items+=("${field}(${DB[$k]})")
        fi
      fi
    done
  fi
  _scan_join "${items[@]+"${items[@]}"}"
}

backup() {
  local timestamp=$1
  local state='{}'
  local k key field value expiry remaining
  local -A seen=()
  if ((${#DB[@]} > 0)); then
    for k in "${!DB[@]}"; do
      key=${k%%$'\x1f'*}
      field=${k#*$'\x1f'}
      if _is_alive "$key" "$field" "$timestamp"; then
        value=${DB[$k]}
        expiry=${EXPIRY[$k]}
        if [[ -z "$expiry" ]]; then
          remaining=null
        else
          remaining=$((expiry - timestamp))
        fi
        state=$(
          jq -c --arg key "$key" --arg field "$field" --arg value "$value" \
            --argjson remaining "$remaining" \
            '.[$key][$field] = [$value, $remaining]' <<<"$state"
        )
        seen[$key]=1
      fi
    done
  fi
  BACKUP_TS+=("$timestamp")
  BACKUP_STATE+=("$state")
  hp_str "${#seen[@]}"
}

restore() {
  local timestamp=$1 timestamp_to_restore=$2
  local idx=-1 i
  for i in "${!BACKUP_TS[@]}"; do
    if ((BACKUP_TS[i] <= timestamp_to_restore)); then
      idx=$i
    fi
  done
  local backup=${BACKUP_STATE[$idx]}
  unset DB EXPIRY
  declare -gA DB EXPIRY
  DB=()
  EXPIRY=()
  local pair key field value remaining expiry
  while IFS= read -r pair; do
    if [[ -z "$pair" ]]; then
      continue
    fi
    key=$(jq -r '.[0]' <<<"$pair")
    field=$(jq -r '.[1]' <<<"$pair")
    value=$(jq -r '.[2]' <<<"$pair")
    remaining=$(jq -c '.[3]' <<<"$pair")
    if [[ "$remaining" == "null" ]]; then
      expiry=""
    else
      expiry=$((timestamp + remaining))
    fi
    _set_internal "$key" "$field" "$value" "$expiry" >/dev/null
  done < <(jq -c 'to_entries[] | .key as $k | .value | to_entries[] | [$k, .key, .value[0], .value[1]]' <<<"$backup")
  hp_str ""
}
