#!/usr/bin/env bash
# Reference text buffer. Shared public traces.

new() {
  BUF=""
  POS=0
  UNDO_BUF=()
  UNDO_POS=()
  REDO_BUF=()
  REDO_POS=()
  SEL_START=-1
  SEL_END=-1
  CLIP=""
}

_push() {
  UNDO_BUF+=("$BUF")
  UNDO_POS+=("$POS")
  REDO_BUF=()
  REDO_POS=()
  SEL_START=-1
  SEL_END=-1
}

insert() {
  local pos=$1 text=$2
  if ((pos < 0 || pos > ${#BUF})); then
    hp_str "invalid_request"
    return 0
  fi
  _push
  BUF="${BUF:0:pos}${text}${BUF:pos}"
  hp_str "${#BUF}"
}

erase() {
  local pos=$1 n=$2
  if ((n <= 0 || pos < 0 || pos + n > ${#BUF})); then
    hp_str "invalid_request"
    return 0
  fi
  _push
  local deleted=${BUF:pos:n}
  BUF="${BUF:0:pos}${BUF:pos+n}"
  if ((POS > ${#BUF})); then
    POS=${#BUF}
  fi
  hp_str "$deleted"
}

get_text() {
  hp_str "$BUF"
}

length() {
  hp_str "${#BUF}"
}

move() {
  local pos=$1
  if ((pos < 0 || pos > ${#BUF})); then
    hp_str "invalid_request"
    return 0
  fi
  POS=$pos
  hp_str "true"
}

type_text() {
  local text=$1
  _push
  local at=$POS
  BUF="${BUF:0:at}${text}${BUF:at}"
  POS=$((at + ${#text}))
  hp_str "${#BUF}"
}

cursor() {
  hp_str "$POS"
}

undo() {
  if ((${#UNDO_BUF[@]} == 0)); then
    hp_str "false"
    return 0
  fi
  REDO_BUF+=("$BUF")
  REDO_POS+=("$POS")
  local last=$((${#UNDO_BUF[@]} - 1))
  BUF=${UNDO_BUF[last]}
  POS=${UNDO_POS[last]}
  unset "UNDO_BUF[last]"
  unset "UNDO_POS[last]"
  UNDO_BUF=("${UNDO_BUF[@]+"${UNDO_BUF[@]}"}")
  UNDO_POS=("${UNDO_POS[@]+"${UNDO_POS[@]}"}")
  SEL_START=-1
  SEL_END=-1
  hp_str "true"
}

redo() {
  if ((${#REDO_BUF[@]} == 0)); then
    hp_str "false"
    return 0
  fi
  UNDO_BUF+=("$BUF")
  UNDO_POS+=("$POS")
  local last=$((${#REDO_BUF[@]} - 1))
  BUF=${REDO_BUF[last]}
  POS=${REDO_POS[last]}
  unset "REDO_BUF[last]"
  unset "REDO_POS[last]"
  REDO_BUF=("${REDO_BUF[@]+"${REDO_BUF[@]}"}")
  REDO_POS=("${REDO_POS[@]+"${REDO_POS[@]}"}")
  SEL_START=-1
  SEL_END=-1
  hp_str "true"
}

# select is a bash reserved word; define via eval so the adapter can call it.
eval 'function select {
  local start=$1 end=$2
  if ((start < 0 || end < 0 || start > end || end > ${#BUF})); then
    hp_str "invalid_request"
    return 0
  fi
  SEL_START=$start
  SEL_END=$end
  hp_str "true"
}'

cut() {
  if ((SEL_START < 0 || SEL_START == SEL_END)); then
    hp_str "invalid_request"
    return 0
  fi
  local start=$SEL_START end=$SEL_END
  local text=${BUF:start:end-start}
  BUF="${BUF:0:start}${BUF:end}"
  CLIP=$text
  POS=$start
  SEL_START=-1
  SEL_END=-1
  hp_str "$text"
}

copy_sel() {
  if ((SEL_START < 0 || SEL_START == SEL_END)); then
    hp_str "invalid_request"
    return 0
  fi
  CLIP=${BUF:SEL_START:SEL_END-SEL_START}
  hp_str "$CLIP"
}

paste() {
  if [[ -z "$CLIP" ]]; then
    hp_str "invalid_request"
    return 0
  fi
  local at=$POS
  BUF="${BUF:0:at}${CLIP}${BUF:at}"
  POS=$((at + ${#CLIP}))
  hp_str "${#BUF}"
}
