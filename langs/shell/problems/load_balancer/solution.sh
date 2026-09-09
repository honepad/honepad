#!/usr/bin/env bash
# Reference load balancer. Shared public traces.

new() {
  unset BACKEND_ORDER HEALTH WEIGHT INFLIGHT STICKY
  declare -gA HEALTH WEIGHT INFLIGHT STICKY
  BACKEND_ORDER=()
  HEALTH=()
  WEIGHT=()
  INFLIGHT=()
  STICKY=()
  CURSOR=0
  USE_LEAST=0
}

add_backend() {
  local backend_id=$1
  if [[ -n "${HEALTH[$backend_id]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  BACKEND_ORDER+=("$backend_id")
  HEALTH[$backend_id]=1
  WEIGHT[$backend_id]=1
  INFLIGHT[$backend_id]=0
  hp_str "true"
}

_reset_cycle() {
  local id
  CURSOR=0
  USE_LEAST=0
  for id in "${BACKEND_ORDER[@]}"; do
    INFLIGHT[$id]=0
  done
}

set_health() {
  local backend_id=$1 flag=$2
  if [[ -z "${HEALTH[$backend_id]+x}" || ( "$flag" != "0" && "$flag" != "1" ) ]]; then
    hp_str "invalid_request"
    return 0
  fi
  HEALTH[$backend_id]=$flag
  _reset_cycle
  hp_str "true"
}

set_weight() {
  local backend_id=$1 weight=$2
  if [[ -z "${HEALTH[$backend_id]+x}" ]] || ((weight <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  WEIGHT[$backend_id]=$weight
  _reset_cycle
  hp_str "true"
}

_pick() {
  local id least first=1
  local healthy=()
  for id in "${BACKEND_ORDER[@]}"; do
    if [[ "${HEALTH[$id]}" == "1" ]]; then
      healthy+=("$id")
    fi
  done
  if ((${#healthy[@]} == 0)); then
    PICKED=""
    return 0
  fi
  local pool=("${healthy[@]}")
  if ((USE_LEAST)); then
    for id in "${healthy[@]}"; do
      if ((first)); then
        least=${INFLIGHT[$id]}
        first=0
      elif ((INFLIGHT[$id] < least)); then
        least=${INFLIGHT[$id]}
      fi
    done
    pool=()
    for id in "${healthy[@]}"; do
      if ((INFLIGHT[$id] == least)); then
        pool+=("$id")
      fi
    done
  fi
  local tickets=()
  local i w
  for id in "${pool[@]}"; do
    w=${WEIGHT[$id]}
    for ((i = 0; i < w; i++)); do
      tickets+=("$id")
    done
  done
  if ((${#tickets[@]} == 0)); then
    PICKED=""
    return 0
  fi
  local idx=$((CURSOR % ${#tickets[@]}))
  PICKED=${tickets[$idx]}
  CURSOR=$((CURSOR + 1))
}

_take() {
  _pick
  if [[ -z "$PICKED" ]]; then
    TAKEN=""
    return 0
  fi
  INFLIGHT[$PICKED]=$((INFLIGHT[$PICKED] + 1))
  TAKEN=$PICKED
}

route() {
  _take
  hp_str "$TAKEN"
}

sticky() {
  local client_id=$1
  local bound=${STICKY[$client_id]-}
  if [[ -n "$bound" && -n "${HEALTH[$bound]+x}" && "${HEALTH[$bound]}" == "1" ]]; then
    INFLIGHT[$bound]=$((INFLIGHT[$bound] + 1))
    hp_str "$bound"
    return 0
  fi
  _take
  if [[ -n "$TAKEN" ]]; then
    STICKY[$client_id]=$TAKEN
  fi
  hp_str "$TAKEN"
}

function done() {
  local backend_id=$1
  if [[ -z "${HEALTH[$backend_id]+x}" ]] || ((INFLIGHT[$backend_id] <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  INFLIGHT[$backend_id]=$((INFLIGHT[$backend_id] - 1))
  USE_LEAST=1
  hp_str "true"
}
