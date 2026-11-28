#!/bin/bash

set -euo pipefail

EXECUTABLE=$(dirname $(realpath $0))/toylang.escript
BUILDSCRIPT=$(dirname $(realpath $0))/build.sh
RUNTIME=$(dirname $(realpath $0))/libruntime.a
COMMAND="${1:?usage: toylang run <input.toy> | build <input.toy> <output.toyx> | --help | --version}"

case $COMMAND in
    --help)
        $EXECUTABLE --help
        ;;
    --version)
        $EXECUTABLE --version
        ;;
    run)
        if [[ -z "$2" ]]
        then
            echo "You need to provide a ToyLang file to run"
            exit 2
        else
            $EXECUTABLE run $2
        fi
        ;;
    build)
        if [[ -z "$2" ]]
        then
            echo "You need to provide a ToyLang file to compile"
            exit 2
        else
            if [[ -z "$3" ]]
            then
                echo "You need to provide an output file to save the compiled code to"
                exit 2
            else
                $EXECUTABLE build $2 tmp.ssa
                export RUNTIME_PATH="$RUNTIME"
                $BUILDSCRIPT tmp.ssa $3 --delete-ssa
                unset RUNTIME_PATH
                echo "Compiled to $3"
            fi
        fi
        ;;
esac
