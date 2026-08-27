#!/usr/bin/env bash
# Reference cloud file storage. Shared public traces.

new() {
  unset FILES OWNER USERS CAPACITY BACKUPS
  declare -gA FILES OWNER USERS CAPACITY BACKUPS
  USERS[admin]=1
  CAPACITY[admin]=""
}

_used() {
  local user_id=$1 sum=0 name
  if ((${#FILES[@]} > 0)); then
    for name in "${!FILES[@]}"; do
      if [[ "${OWNER[$name]}" == "$user_id" ]]; then
        sum=$((sum + FILES[$name]))
      fi
    done
  fi
  printf '%s\n' "$sum"
}

_remaining() {
  local user_id=$1
  local cap=${CAPACITY[$user_id]}
  if [[ -z "$cap" ]]; then
    printf '%s\n' ""
    return 0
  fi
  local used
  used=$(_used "$user_id")
  printf '%s\n' "$((cap - used))"
}

add_file() {
  local name=$1 size=$2
  if [[ -n "${FILES[$name]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  FILES[$name]=$size
  OWNER[$name]=admin
  hp_str "true"
}

get_file_size() {
  local name=$1
  if [[ -z "${FILES[$name]+x}" ]]; then
    hp_str ""
    return 0
  fi
  hp_str "${FILES[$name]}"
}

delete_file() {
  local name=$1
  if [[ -z "${FILES[$name]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local size=${FILES[$name]}
  unset "FILES[$name]"
  unset "OWNER[$name]"
  hp_str "$size"
}

copy_file() {
  local source=$1 dest=$2
  if [[ -z "${FILES[$source]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local src_size=${FILES[$source]}
  if [[ "$source" == "$dest" ]]; then
    hp_str "$src_size"
    return 0
  fi
  local dest_exists=0 dest_size owner extra remaining
  if [[ -n "${FILES[$dest]+x}" ]]; then
    dest_exists=1
    dest_size=${FILES[$dest]}
    owner=${OWNER[$dest]}
    extra=$((src_size - dest_size))
  else
    owner=${OWNER[$source]}
    extra=$src_size
  fi
  remaining=$(_remaining "$owner")
  if [[ -n "$remaining" && "$extra" -gt "$remaining" ]]; then
    hp_str ""
    return 0
  fi
  if [[ "$dest_exists" -eq 0 ]]; then
    FILES[$dest]=$src_size
    OWNER[$dest]=$owner
  else
    FILES[$dest]=$src_size
  fi
  hp_str "$src_size"
}

get_n_largest() {
  local prefix=$1 n=$2
  local items=() name
  if ((${#FILES[@]} > 0)); then
    for name in "${!FILES[@]}"; do
      if [[ "$name" == "$prefix"* ]]; then
        items+=("${FILES[$name]} $name")
      fi
    done
  fi
  local out="" count=0 line size
  if ((${#items[@]} > 0 && n > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      if ((count >= n)); then
        break
      fi
      size=${line%% *}
      name=${line#* }
      if [[ -n "$out" ]]; then
        out+=", "
      fi
      out+="${name}(${size})"
      count=$((count + 1))
    done < <(printf '%s\n' "${items[@]}" | sort -k1,1nr -k2,2)
  fi
  hp_str "$out"
}

add_user() {
  local user_id=$1 capacity=$2
  if [[ -n "${USERS[$user_id]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  USERS[$user_id]=1
  CAPACITY[$user_id]=$capacity
  hp_str "true"
}

add_file_by() {
  local user_id=$1 name=$2 size=$3
  if [[ -z "${USERS[$user_id]+x}" || -n "${FILES[$name]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local remaining
  remaining=$(_remaining "$user_id")
  if [[ -n "$remaining" && "$size" -gt "$remaining" ]]; then
    hp_str ""
    return 0
  fi
  FILES[$name]=$size
  OWNER[$name]=$user_id
  remaining=$(_remaining "$user_id")
  hp_str "$remaining"
}

merge_user() {
  local user_id1=$1 user_id2=$2
  if [[ "$user_id1" == "$user_id2" ]]; then
    hp_str ""
    return 0
  fi
  if [[ -z "${USERS[$user_id1]+x}" || -z "${USERS[$user_id2]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local cap1=${CAPACITY[$user_id1]}
  local cap2=${CAPACITY[$user_id2]}
  if [[ -z "$cap1" || -z "$cap2" ]]; then
    hp_str ""
    return 0
  fi
  CAPACITY[$user_id1]=$((cap1 + cap2))
  local name
  if ((${#FILES[@]} > 0)); then
    for name in "${!FILES[@]}"; do
      if [[ "${OWNER[$name]}" == "$user_id2" ]]; then
        OWNER[$name]=$user_id1
      fi
    done
  fi
  unset "USERS[$user_id2]"
  unset "CAPACITY[$user_id2]"
  unset "BACKUPS[$user_id2]"
  hp_str "$(_remaining "$user_id1")"
}

backup_user() {
  local user_id=$1
  if [[ -z "${USERS[$user_id]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local snap='{}' name
  if ((${#FILES[@]} > 0)); then
    for name in "${!FILES[@]}"; do
      if [[ "${OWNER[$name]}" == "$user_id" ]]; then
        snap=$(jq -c --arg name "$name" --argjson size "${FILES[$name]}" '.[$name] = $size' <<<"$snap")
      fi
    done
  fi
  BACKUPS[$user_id]=$snap
  hp_str "$(jq 'length' <<<"$snap")"
}

restore_user() {
  local user_id=$1
  if [[ -z "${USERS[$user_id]+x}" ]]; then
    hp_str ""
    return 0
  fi
  local name
  if ((${#FILES[@]} > 0)); then
    for name in "${!FILES[@]}"; do
      if [[ "${OWNER[$name]}" == "$user_id" ]]; then
        unset "FILES[$name]"
        unset "OWNER[$name]"
      fi
    done
  fi
  if [[ -z "${BACKUPS[$user_id]+x}" ]]; then
    hp_str "0"
    return 0
  fi
  local snap=${BACKUPS[$user_id]}
  local restored=0 size remaining
  while IFS= read -r name; do
    if [[ -z "$name" ]]; then
      continue
    fi
    if [[ -n "${FILES[$name]+x}" ]]; then
      continue
    fi
    size=$(jq --arg name "$name" '.[$name]' <<<"$snap")
    remaining=$(_remaining "$user_id")
    if [[ -n "$remaining" && "$size" -gt "$remaining" ]]; then
      continue
    fi
    FILES[$name]=$size
    OWNER[$name]=$user_id
    restored=$((restored + 1))
  done < <(jq -r 'keys[]' <<<"$snap")
  hp_str "$restored"
}
