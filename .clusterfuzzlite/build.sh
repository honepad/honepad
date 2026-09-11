#!/bin/bash -eu
# Build the minijson parse/free libFuzzer target.

$CC $CFLAGS \
  -I"$SRC/honepad/langs/c" \
  "$SRC/honepad/.clusterfuzzlite/minijson_fuzzer.c" \
  "$SRC/honepad/langs/c/minijson.c" \
  -o "$OUT/minijson_fuzzer" \
  $LIB_FUZZING_ENGINE

if [ -d "$SRC/honepad/.clusterfuzzlite/seeds" ]; then
  zip -q -j "$OUT/minijson_fuzzer_seed_corpus.zip" \
    "$SRC/honepad/.clusterfuzzlite/seeds"/*
fi
