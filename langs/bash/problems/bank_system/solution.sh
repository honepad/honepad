#!/usr/bin/env bash
# Reference bank system. Shared public traces.

new() {
  unset BALANCE OUTGOING CREATED_AT PAYMENTS HISTORY
  declare -gA BALANCE OUTGOING CREATED_AT PAYMENTS HISTORY
  BALANCE=()
  OUTGOING=()
  CREATED_AT=()
  PAYMENTS=()
  HISTORY=()
  PAYMENT_COUNTER=0
  PENDING_TS=()
  PENDING_ACC=()
  PENDING_AMT=()
  PENDING_PAY=()
  CASHBACK_DELAY=$((24 * 60 * 60 * 1000))
}

_process() {
  local timestamp=$1
  while ((${#PENDING_TS[@]} > 0 && PENDING_TS[0] <= timestamp)); do
    local cb_ts=${PENDING_TS[0]}
    local acc=${PENDING_ACC[0]}
    local amt=${PENDING_AMT[0]}
    local pid=${PENDING_PAY[0]}
    PENDING_TS=("${PENDING_TS[@]:1}")
    PENDING_ACC=("${PENDING_ACC[@]:1}")
    PENDING_AMT=("${PENDING_AMT[@]:1}")
    PENDING_PAY=("${PENDING_PAY[@]:1}")
    if [[ -n "${BALANCE[$acc]+x}" ]]; then
      BALANCE[$acc]=$((BALANCE[$acc] + amt))
      PAYMENTS["$acc|$pid"]="CASHBACK_RECEIVED"
      HISTORY[$acc]+="$cb_ts ${BALANCE[$acc]}"$'\n'
    fi
  done
}

_record() {
  local account_id=$1 timestamp=$2
  HISTORY[$account_id]+="$timestamp ${BALANCE[$account_id]}"$'\n'
}

create_account() {
  local timestamp=$1 account_id=$2
  _process "$timestamp"
  if [[ -n "${BALANCE[$account_id]+x}" ]]; then
    hp_false
    return 0
  fi
  BALANCE[$account_id]=0
  OUTGOING[$account_id]=0
  CREATED_AT[$account_id]=$timestamp
  HISTORY[$account_id]="$timestamp 0"$'\n'
  hp_true
}

deposit() {
  local timestamp=$1 account_id=$2 amount=$3
  _process "$timestamp"
  if [[ -z "${BALANCE[$account_id]+x}" ]]; then
    hp_null
    return 0
  fi
  BALANCE[$account_id]=$((BALANCE[$account_id] + amount))
  _record "$account_id" "$timestamp"
  hp_num "${BALANCE[$account_id]}"
}

transfer() {
  local timestamp=$1 source_id=$2 target_id=$3 amount=$4
  _process "$timestamp"
  if [[ -z "${BALANCE[$source_id]+x}" || -z "${BALANCE[$target_id]+x}" ]]; then
    hp_null
    return 0
  fi
  if [[ "$source_id" == "$target_id" ]]; then
    hp_null
    return 0
  fi
  if ((BALANCE[$source_id] < amount)); then
    hp_null
    return 0
  fi
  BALANCE[$source_id]=$((BALANCE[$source_id] - amount))
  OUTGOING[$source_id]=$((OUTGOING[$source_id] + amount))
  BALANCE[$target_id]=$((BALANCE[$target_id] + amount))
  _record "$source_id" "$timestamp"
  _record "$target_id" "$timestamp"
  hp_num "${BALANCE[$source_id]}"
}

top_spenders() {
  local timestamp=$1 n=$2
  _process "$timestamp"
  local out=()
  if ((${#BALANCE[@]} > 0 && n > 0)); then
    local sorted line outgoing account_id count=0
    sorted=$(
      for account_id in "${!BALANCE[@]}"; do
        printf '%s %s\n' "${OUTGOING[$account_id]}" "$account_id"
      done | sort -k1,1nr -k2,2
    )
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      if ((count >= n)); then
        break
      fi
      outgoing=${line%% *}
      account_id=${line#* }
      out+=("${account_id}(${outgoing})")
      count=$((count + 1))
    done <<<"$sorted"
  fi
  if ((${#out[@]} == 0)); then
    hp_arr
  else
    hp_arr "${out[@]}"
  fi
}

pay() {
  local timestamp=$1 account_id=$2 amount=$3
  _process "$timestamp"
  if [[ -z "${BALANCE[$account_id]+x}" ]]; then
    hp_null
    return 0
  fi
  if ((BALANCE[$account_id] < amount)); then
    hp_null
    return 0
  fi
  BALANCE[$account_id]=$((BALANCE[$account_id] - amount))
  OUTGOING[$account_id]=$((OUTGOING[$account_id] + amount))
  PAYMENT_COUNTER=$((PAYMENT_COUNTER + 1))
  local payment_id="payment${PAYMENT_COUNTER}"
  PAYMENTS["$account_id|$payment_id"]="IN_PROGRESS"
  _record "$account_id" "$timestamp"
  PENDING_TS+=("$((timestamp + CASHBACK_DELAY))")
  PENDING_ACC+=("$account_id")
  PENDING_AMT+=("$((amount * 2 / 100))")
  PENDING_PAY+=("$payment_id")
  hp_str "$payment_id"
}

get_payment_status() {
  local timestamp=$1 account_id=$2 payment=$3
  _process "$timestamp"
  if [[ -z "${BALANCE[$account_id]+x}" ]]; then
    hp_null
    return 0
  fi
  if [[ -z "${PAYMENTS[$account_id|$payment]+x}" ]]; then
    hp_null
    return 0
  fi
  hp_str "${PAYMENTS[$account_id|$payment]}"
}

merge_accounts() {
  local timestamp=$1 keep_id=$2 drop_id=$3
  _process "$timestamp"
  if [[ "$keep_id" == "$drop_id" ]]; then
    hp_false
    return 0
  fi
  if [[ -z "${BALANCE[$keep_id]+x}" || -z "${BALANCE[$drop_id]+x}" ]]; then
    hp_false
    return 0
  fi
  BALANCE[$keep_id]=$((BALANCE[$keep_id] + BALANCE[$drop_id]))
  OUTGOING[$keep_id]=$((OUTGOING[$keep_id] + OUTGOING[$drop_id]))
  local keys=() k pid
  if ((${#PAYMENTS[@]} > 0)); then
    keys=("${!PAYMENTS[@]}")
    for k in "${keys[@]}"; do
      if [[ "$k" == "$drop_id|"* ]]; then
        pid=${k#*|}
        PAYMENTS["$keep_id|$pid"]=${PAYMENTS[$k]}
        unset "PAYMENTS[$k]"
      fi
    done
  fi
  HISTORY[$keep_id]="$(printf '%s%s' "${HISTORY[$keep_id]}" "${HISTORY[$drop_id]}" | sort -n)"$'\n'
  if ((CREATED_AT[$drop_id] < CREATED_AT[$keep_id])); then
    CREATED_AT[$keep_id]=${CREATED_AT[$drop_id]}
  fi
  _record "$keep_id" "$timestamp"
  local i
  for i in "${!PENDING_ACC[@]}"; do
    if [[ "${PENDING_ACC[$i]}" == "$drop_id" ]]; then
      PENDING_ACC[$i]=$keep_id
    fi
  done
  unset "BALANCE[$drop_id]"
  unset "OUTGOING[$drop_id]"
  unset "CREATED_AT[$drop_id]"
  unset "HISTORY[$drop_id]"
  hp_true
}

get_balance() {
  local timestamp=$1 account_id=$2 time_at=$3
  _process "$timestamp"
  if [[ -z "${BALANCE[$account_id]+x}" ]]; then
    hp_null
    return 0
  fi
  if ((time_at < CREATED_AT[$account_id])); then
    hp_null
    return 0
  fi
  local result="" line ts bal
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    ts=${line%% *}
    bal=${line#* }
    if ((ts <= time_at)); then
      result=$bal
    else
      break
    fi
  done <<<"${HISTORY[$account_id]}"
  if [[ -z "$result" ]]; then
    hp_null
  else
    hp_num "$result"
  fi
}
