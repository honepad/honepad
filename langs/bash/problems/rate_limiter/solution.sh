#!/usr/bin/env bash
# Reference rate limiter. Shared public traces.

new() {
  unset LIMIT WINDOW WID USED
  declare -gA LIMIT WINDOW WID USED
  LIMIT=()
  WINDOW=()
  WID=()
  USED=()
}

_state() {
  local key=$1
  if [[ -z "${LIMIT[$key]+x}" ]]; then
    LIMIT[$key]=3
    WINDOW[$key]=10
    USED[$key]=0
  fi
}

_used_at() {
  local key=$1 timestamp=$2 persist=$3
  local window=${WINDOW[$key]}
  local window_id=$((timestamp / window))
  if [[ -z "${WID[$key]+x}" || "${WID[$key]}" -ne $window_id ]]; then
    if ((persist)); then
      WID[$key]=$window_id
      USED[$key]=0
    fi
    echo 0
    return 0
  fi
  echo "${USED[$key]}"
}

allow() {
  allow_weighted "$1" 1 "$2"
}

configure() {
  local key=$1 limit=$2 window=$3
  if ((limit <= 0 || window <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  LIMIT[$key]=$limit
  WINDOW[$key]=$window
  unset "WID[$key]"
  USED[$key]=0
  hp_str "true"
}

remaining() {
  local key=$1 timestamp=$2
  _state "$key"
  local used
  used=$(_used_at "$key" "$timestamp" 0)
  hp_str "$((LIMIT[$key] - used))"
}

allow_weighted() {
  local key=$1 cost=$2 timestamp=$3
  if ((cost <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  _state "$key"
  _used_at "$key" "$timestamp" 1 >/dev/null
  if ((USED[$key] + cost > LIMIT[$key])); then
    hp_str "false"
    return 0
  fi
  USED[$key]=$((USED[$key] + cost))
  hp_str "true"
}
