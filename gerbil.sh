#!/bin/bash
dir=$(dirname "$0")
export GERBIL_LOADPATH=${GERBIL_LOADPATH:-$dir}
gxi $GERBIL_HOME/lib/gxi-interactive -e '(import :drewc/r7rs/gerbil-swank)' -e '(start-swank)'
