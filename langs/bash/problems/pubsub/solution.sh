#!/usr/bin/env bash
# Reference topic inbox. Shared public traces.

new() {
  unset SUBS INBOX RETAINED
  declare -gA SUBS INBOX RETAINED
  SUBS=()
  INBOX=()
  RETAINED=()
}

_split_rs() {
  local raw=$1
  PARTS=()
  if [[ -z "$raw" ]]; then
    return 0
  fi
  local IFS=$'\x1e'
  read -r -a PARTS <<<"$raw"
}

_join_rs() {
  local out="" item
  for item in "$@"; do
    if [[ -n "$out" ]]; then
      out+=$'\x1e'
    fi
    out+="$item"
  done
  printf '%s' "$out"
}

subscribe() {
  local topic=$1 client=$2
  local raw=${SUBS[$topic]-}
  _split_rs "$raw"
  local existing
  for existing in "${PARTS[@]+"${PARTS[@]}"}"; do
    if [[ "$existing" == "$client" ]]; then
      hp_str "false"
      return 0
    fi
  done
  PARTS+=("$client")
  SUBS[$topic]=$(_join_rs "${PARTS[@]}")
  if [[ -n "${RETAINED[$topic]+x}" ]]; then
    local inbox_raw=${INBOX[$client]-}
    _split_rs "$inbox_raw"
    PARTS+=("$topic:${RETAINED[$topic]}")
    INBOX[$client]=$(_join_rs "${PARTS[@]}")
  fi
  hp_str "true"
}

unsubscribe() {
  local topic=$1 client=$2
  if [[ -z "${SUBS[$topic]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  _split_rs "${SUBS[$topic]}"
  local kept=() existing found=0
  for existing in "${PARTS[@]+"${PARTS[@]}"}"; do
    if [[ "$existing" == "$client" ]]; then
      found=1
    else
      kept+=("$existing")
    fi
  done
  if ((found == 0)); then
    hp_str "false"
    return 0
  fi
  if ((${#kept[@]} == 0)); then
    unset "SUBS[$topic]"
  else
    SUBS[$topic]=$(_join_rs "${kept[@]}")
  fi
  hp_str "true"
}

publish() {
  local topic=$1 message=$2
  local raw=${SUBS[$topic]-}
  _split_rs "$raw"
  local clients=("${PARTS[@]+"${PARTS[@]}"}")
  local payload="$topic:$message"
  local client inbox_raw
  for client in "${clients[@]+"${clients[@]}"}"; do
    inbox_raw=${INBOX[$client]-}
    _split_rs "$inbox_raw"
    PARTS+=("$payload")
    INBOX[$client]=$(_join_rs "${PARTS[@]}")
  done
  hp_str "${#clients[@]}"
}

inbox() {
  local client=$1
  if [[ -z "${INBOX[$client]+x}" ]]; then
    hp_str ""
    return 0
  fi
  _split_rs "${INBOX[$client]}"
  local out="" item
  for item in "${PARTS[@]+"${PARTS[@]}"}"; do
    if [[ -n "$out" ]]; then
      out+=", "
    fi
    out+="$item"
  done
  hp_str "$out"
}

list_topics() {
  local topics=() t
  if ((${#SUBS[@]} > 0)); then
    for t in "${!SUBS[@]}"; do
      topics+=("$t")
    done
  fi
  local out="" line
  if ((${#topics[@]} > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      if [[ -n "$out" ]]; then
        out+=", "
      fi
      out+="$line"
    done < <(printf '%s\n' "${topics[@]}" | sort)
  fi
  hp_str "$out"
}

subscribers() {
  local topic=$1
  if [[ -z "${SUBS[$topic]+x}" ]]; then
    hp_str ""
    return 0
  fi
  _split_rs "${SUBS[$topic]}"
  local out="" line
  if ((${#PARTS[@]} > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      if [[ -n "$out" ]]; then
        out+=", "
      fi
      out+="$line"
    done < <(printf '%s\n' "${PARTS[@]}" | sort)
  fi
  hp_str "$out"
}

peek() {
  local client=$1
  if [[ -z "${INBOX[$client]+x}" ]]; then
    hp_str ""
    return 0
  fi
  _split_rs "${INBOX[$client]}"
  if ((${#PARTS[@]} == 0)); then
    hp_str ""
    return 0
  fi
  hp_str "${PARTS[0]}"
}

ack() {
  local client=$1 n=$2
  if ((n <= 0)) || [[ -z "${INBOX[$client]+x}" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  _split_rs "${INBOX[$client]}"
  if ((n > ${#PARTS[@]})); then
    hp_str "invalid_request"
    return 0
  fi
  PARTS=("${PARTS[@]:n}")
  INBOX[$client]=$(_join_rs "${PARTS[@]+"${PARTS[@]}"}")
  hp_str "${#PARTS[@]}"
}

retain() {
  local topic=$1 message=$2
  RETAINED[$topic]=$message
  hp_str ""
}
