#!/bin/bash

set -euo pipefail

SSA_FILE="${1:?usage: $0 <input.ssa> <output> [--delete-ssa]}"
OUT_FILE="${2:?usage: $0 <input.ssa> <output> [--delete-ssa]}"
DELETE_SSA="${3:---no-delete-ssa}"
RUNTIME_LIB="${RUNTIME_PATH:-$(pwd)/runtime/target/release/libruntime.a}"

qbe -o tmp.s $SSA_FILE
cc -o $OUT_FILE tmp.s $RUNTIME_LIB

if [[ "$DELETE_SSA" == "--delete-ssa" ]]
then
    rm $SSA_FILE
fi

rm tmp.s
