#!/usr/bin/env bash
# Stop hook: if the project has a .claude/verify.sh and the working tree (ignoring .ai-* files)
# changed since the last passing run and since this turn began, run it. On failure, exit 2 so Claude keeps
# working (max 3 attempts per session), then send a failure toast. No toast on success.
input=$(cat)
hookdir=$(cd "$(dirname "$0")" && pwd)
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // "none"' 2>/dev/null)
verify=.claude/verify.sh

if [ -f "$verify" ] && gd=$(git rev-parse --git-dir 2>/dev/null); then
  . "$hookdir/verify-fp.sh"
  fp=$(verify_fp)
  # The tree is as it was when this turn began (turn-start.sh): the turn changed nothing, so there is
  # nothing of its own to verify (a question asked after another session committed to the same folder, say).
  [ "$(cat "/tmp/claude-verify-$sid.turn" 2>/dev/null)" = "$fp" ] && exit 0
  if [ "$(cat "$gd/claude-verify.ok" 2>/dev/null)" != "$fp" ]; then
    count_file="/tmp/claude-verify-$sid.count"
    if out=$(timeout 900 bash "$verify" 2>&1); then
      echo "$fp" > "$gd/claude-verify.ok"
      rm -f "$count_file"
    else
      n=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
      echo "$n" > "$count_file"
      if [ "$n" -le 3 ]; then
        { echo "Project verification (.claude/verify.sh) failed, attempt $n/3. Fix it before finishing:"
          printf '%s\n' "$out" | tail -40; } >&2
        exit 2
      fi
      rm -f "$count_file"
      bash "$hookdir/notify.sh" fail
      exit 0
    fi
  fi
fi
exit 0
