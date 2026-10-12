#!/bin/sh
set -eu
base_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Applies to Mesa's software renderer only; callers can override it.
: "${LP_NUM_THREADS:=3}"
export LP_NUM_THREADS
exec "$base_dir/godot" --main-pack "$base_dir/game.pck" "$@"
