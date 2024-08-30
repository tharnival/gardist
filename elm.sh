#!/usr/bin/env bash

MAKE_ELM='elm make src-elm/Main.elm --output=dist/main.js'

if [[ $1 == 'dev' ]]; then
    watchexec -e elm -w src-elm -- "$MAKE_ELM" &
    WEID=$!
    cargo tauri dev
    kill $WEID
elif [[ $1 == 'build' ]]; then
    $MAKE_ELM
elif [[ $1 == 'release' ]]; then
    $MAKE_ELM --optimize
fi
