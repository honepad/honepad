#!/usr/bin/env bash
# Reference GPU scheduler. Shared public traces.

new() {
  unset GPU_MEM GPU_JOB GPU_ORDER
  unset JOB_MEM JOB_SEQ JOB_PRI JOB_STATE JOB_GPU
  declare -gA GPU_MEM GPU_JOB JOB_MEM JOB_SEQ JOB_PRI JOB_STATE JOB_GPU
  GPU_MEM=()
  GPU_JOB=()
  GPU_ORDER=()
  JOB_MEM=()
  JOB_SEQ=()
  JOB_PRI=()
  JOB_STATE=()
  JOB_GPU=()
  NEXT_SEQ=0
}

add_gpu() {
  local gpu_id=$1 mem=$2
  if ((mem <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  if [[ -n "${GPU_MEM[$gpu_id]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  GPU_MEM[$gpu_id]=$mem
  GPU_JOB[$gpu_id]=""
  GPU_ORDER+=("$gpu_id")
  hp_str "true"
}

submit_job() {
  local job_id=$1 mem=$2
  if ((mem <= 0)); then
    hp_str "invalid_request"
    return 0
  fi
  if [[ -n "${JOB_STATE[$job_id]+x}" ]]; then
    hp_str "false"
    return 0
  fi
  JOB_MEM[$job_id]=$mem
  JOB_SEQ[$job_id]=$NEXT_SEQ
  JOB_PRI[$job_id]=0
  JOB_STATE[$job_id]="queued"
  JOB_GPU[$job_id]=""
  NEXT_SEQ=$((NEXT_SEQ + 1))
  hp_str "true"
}

status() {
  local job_id=$1
  if [[ -z "${JOB_STATE[$job_id]+x}" ]]; then
    hp_str ""
    return 0
  fi
  hp_str "${JOB_STATE[$job_id]}"
}

assign() {
  local items=() job_id
  if ((${#JOB_STATE[@]} > 0)); then
    for job_id in "${!JOB_STATE[@]}"; do
      if [[ "${JOB_STATE[$job_id]}" == "queued" ]]; then
        items+=("${JOB_PRI[$job_id]} ${JOB_SEQ[$job_id]} $job_id")
      fi
    done
  fi
  local line pri seq gpu_id
  if ((${#items[@]} > 0)); then
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then
        continue
      fi
      pri=${line%% *}
      rest=${line#* }
      seq=${rest%% *}
      job_id=${rest#* }
      for gpu_id in "${GPU_ORDER[@]}"; do
        if [[ -z "${GPU_JOB[$gpu_id]}" && ${GPU_MEM[$gpu_id]} -ge ${JOB_MEM[$job_id]} ]]; then
          JOB_STATE[$job_id]="running"
          JOB_GPU[$job_id]=$gpu_id
          GPU_JOB[$gpu_id]=$job_id
          hp_str "$job_id"
          return 0
        fi
      done
    done < <(printf '%s\n' "${items[@]}" | sort -k1,1nr -k2,2n)
  fi
  hp_str ""
}

complete() {
  local job_id=$1
  if [[ -z "${JOB_STATE[$job_id]+x}" || "${JOB_STATE[$job_id]}" != "running" || -z "${JOB_GPU[$job_id]}" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  GPU_JOB[${JOB_GPU[$job_id]}]=""
  JOB_GPU[$job_id]=""
  JOB_STATE[$job_id]="done"
  hp_str "true"
}

cancel() {
  local job_id=$1
  if [[ -z "${JOB_STATE[$job_id]+x}" || "${JOB_STATE[$job_id]}" == "done" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  local was_running=0
  if [[ "${JOB_STATE[$job_id]}" == "running" ]]; then
    was_running=1
    if [[ -n "${JOB_GPU[$job_id]}" ]]; then
      GPU_JOB[${JOB_GPU[$job_id]}]=""
    fi
  fi
  unset "JOB_MEM[$job_id]" "JOB_SEQ[$job_id]" "JOB_PRI[$job_id]" "JOB_STATE[$job_id]" "JOB_GPU[$job_id]"
  if ((was_running)); then
    assign
  fi
  hp_str "true"
}

set_priority() {
  local job_id=$1 priority=$2
  if [[ -z "${JOB_STATE[$job_id]+x}" || "${JOB_STATE[$job_id]}" != "queued" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  JOB_PRI[$job_id]=$priority
  hp_str "true"
}
