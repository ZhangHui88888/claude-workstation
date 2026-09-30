#!/usr/bin/env bash
# Windows toast from WSL. Usage: notify.sh <done|input|fail>
kind=${1:-done}
proj=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")
ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
[ -x "$ps" ] || exit 0
script=$(wslpath -w "$(dirname "$(readlink -f "$0")")/notify.ps1")
setsid "$ps" -NoProfile -ExecutionPolicy Bypass -File "$script" \
  -Kind "$kind" -Project "$proj" >/dev/null 2>&1 < /dev/null &
exit 0
