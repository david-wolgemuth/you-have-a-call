#!/bin/sh
set -eu
cd "$(dirname "$0")"
log="$PWD/build/list.log"
: > "$log"
open -W -n --stdout "$log" --stderr "$log" "build/You Have a Call.app" --args --list
cat "$log"
