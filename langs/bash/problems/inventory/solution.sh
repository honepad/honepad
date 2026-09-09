#!/usr/bin/env bash
# Reference inventory register. Shared public traces.

new() {
  unset QTY RESERVED
  declare -gA QTY RESERVED
  QTY=()
  RESERVED=()
}

create_item() {
  local sku=$1
  if [[ -n "${QTY[$sku]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  QTY[$sku]=0
  RESERVED[$sku]=0
  hp_str "true"
}

stock() {
  local sku=$1 delta=$2
  if [[ -z "${QTY[$sku]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local nxt=$((QTY[$sku] + delta))
  if ((nxt < RESERVED[$sku])); then
    hp_str "invalid_request"
    return 0
  fi
  QTY[$sku]=$nxt
  hp_str "$nxt"
}

get_qty() {
  local sku=$1
  if [[ -z "${QTY[$sku]+x}" ]]; then
    hp_str ""
    return 0
  fi
  hp_str "${QTY[$sku]}"
}

list_low() {
  local threshold=$1
  local items=() sku qty
  if ((${#QTY[@]} > 0)); then
    for sku in "${!QTY[@]}"; do
      qty=${QTY[$sku]}
      if ((qty <= threshold)); then
        items+=("$qty $sku")
      fi
    done
  fi
  local out="" line
  if ((${#items[@]} > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      qty=${line%% *}
      sku=${line#* }
      if [[ -n "$out" ]]; then
        out+=", "
      fi
      out+="${sku}(${qty})"
    done < <(printf '%s\n' "${items[@]}" | sort -k1,1n -k2,2)
  fi
  hp_str "$out"
}

reserve() {
  local sku=$1 n=$2
  if [[ -z "${QTY[$sku]+x}" ]] || ((n <= 0 || RESERVED[$sku] + n > QTY[$sku])); then
    hp_str "invalid_request"
    return 0
  fi
  RESERVED[$sku]=$((RESERVED[$sku] + n))
  hp_str "true"
}

release() {
  local sku=$1 n=$2
  if [[ -z "${QTY[$sku]+x}" ]] || ((n <= 0 || n > RESERVED[$sku])); then
    hp_str "invalid_request"
    return 0
  fi
  RESERVED[$sku]=$((RESERVED[$sku] - n))
  hp_str "true"
}

ship() {
  local sku=$1 n=$2
  if [[ -z "${QTY[$sku]+x}" ]] || ((n <= 0 || n > RESERVED[$sku])); then
    hp_str "invalid_request"
    return 0
  fi
  RESERVED[$sku]=$((RESERVED[$sku] - n))
  QTY[$sku]=$((QTY[$sku] - n))
  hp_str "true"
}
