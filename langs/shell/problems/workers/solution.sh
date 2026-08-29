#!/usr/bin/env bash
# Reference workers register. Shared public traces.

new() {
  unset POSITION COMP IN_OFFICE ENTERED FINISHED PENDING
  declare -gA POSITION COMP IN_OFFICE ENTERED FINISHED PENDING
  POSITION=()
  COMP=()
  IN_OFFICE=()
  ENTERED=()
  FINISHED=()
  PENDING=()
}

add_worker() {
  local worker_id=$1 position=$2 compensation=$3
  if [[ -n "${POSITION[$worker_id]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  POSITION[$worker_id]=$position
  COMP[$worker_id]=$compensation
  IN_OFFICE[$worker_id]=0
  ENTERED[$worker_id]=""
  FINISHED[$worker_id]=""
  PENDING[$worker_id]=""
  hp_str "true"
}

_apply_promo() {
  local worker_id=$1 timestamp=$2
  local pending=${PENDING[$worker_id]}
  if [[ -z "$pending" ]]; then
    return 0
  fi
  local new_pos new_comp start_ts
  IFS=$'\x1f' read -r new_pos new_comp start_ts <<<"$pending"
  if ((timestamp >= start_ts)); then
    POSITION[$worker_id]=$new_pos
    COMP[$worker_id]=$new_comp
    PENDING[$worker_id]=""
  fi
}

_total_time() {
  local worker_id=$1 sum=0 line start end
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    start=${line%% *}
    rest=${line#* }
    end=${rest%% *}
    sum=$((sum + end - start))
  done <<<"${FINISHED[$worker_id]}"
  printf '%s\n' "$sum"
}

_position_time() {
  local worker_id=$1 position=$2 sum=0 line start end rate pos
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    start=${line%% *}
    rest=${line#* }
    end=${rest%% *}
    rest=${rest#* }
    rate=${rest%% *}
    pos=${rest#* }
    if [[ "$pos" == "$position" ]]; then
      sum=$((sum + end - start))
    fi
  done <<<"${FINISHED[$worker_id]}"
  printf '%s\n' "$sum"
}

register() {
  local worker_id=$1 timestamp=$2
  if [[ -z "${POSITION[$worker_id]+x}" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  if ((IN_OFFICE[$worker_id] == 1)); then
    FINISHED[$worker_id]+="${ENTERED[$worker_id]} $timestamp ${COMP[$worker_id]} ${POSITION[$worker_id]}"$'\n'
    IN_OFFICE[$worker_id]=0
    ENTERED[$worker_id]=""
    hp_str "registered"
    return 0
  fi
  _apply_promo "$worker_id" "$timestamp"
  IN_OFFICE[$worker_id]=1
  ENTERED[$worker_id]=$timestamp
  hp_str "registered"
}

get() {
  local worker_id=$1
  if [[ -z "${POSITION[$worker_id]+x}" ]]; then
    hp_str ""
    return 0
  fi
  hp_str "$(_total_time "$worker_id")"
}

top_n_workers() {
  local n=$1 position=$2
  local items=() worker_id ptime
  if ((${#POSITION[@]} > 0)); then
    for worker_id in "${!POSITION[@]}"; do
      if [[ "${POSITION[$worker_id]}" == "$position" ]]; then
        ptime=$(_position_time "$worker_id" "$position")
        items+=("$ptime $worker_id")
      fi
    done
  fi
  local out="" count=0 line
  if ((${#items[@]} > 0 && n > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      if ((count >= n)); then
        break
      fi
      ptime=${line%% *}
      worker_id=${line#* }
      if [[ -n "$out" ]]; then
        out+=", "
      fi
      out+="${worker_id}(${ptime})"
      count=$((count + 1))
    done < <(printf '%s\n' "${items[@]}" | sort -k1,1nr -k2,2)
  fi
  hp_str "$out"
}

promote() {
  local worker_id=$1 new_position=$2 new_compensation=$3 start_timestamp=$4
  if [[ -z "${POSITION[$worker_id]+x}" || -n "${PENDING[$worker_id]}" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  PENDING[$worker_id]="${new_position}"$'\x1f'"${new_compensation}"$'\x1f'"${start_timestamp}"
  hp_str "success"
}

calc_salary() {
  local worker_id=$1 start_timestamp=$2 end_timestamp=$3
  if [[ -z "${POSITION[$worker_id]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local total=0 line session_start session_end rate lo hi
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    session_start=${line%% *}
    rest=${line#* }
    session_end=${rest%% *}
    rest=${rest#* }
    rate=${rest%% *}
    if ((session_start > start_timestamp)); then
      lo=$session_start
    else
      lo=$start_timestamp
    fi
    if ((session_end < end_timestamp)); then
      hi=$session_end
    else
      hi=$end_timestamp
    fi
    if ((hi > lo)); then
      total=$((total + (hi - lo) * rate))
    fi
  done <<<"${FINISHED[$worker_id]}"
  hp_str "$total"
}
