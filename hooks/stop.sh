#!/usr/bin/env bash
# Stop hook: if the project has a .claude/verify.sh and the working tree (ignoring .ai-* files)
# changed since the last passing run, run it. On failure, exit 2 so Claude keeps
# working (max 3 attempts per session), then send a failure toast. No toast on success.
input=$(cat)
hookdir=$(cd "$(dirname "$0")" && pwd)
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // "none"' 2>/dev/null)
verify=.claude/verify.sh

if [ -f "$verify" ] && gd=$(git rev-parse --git-dir 2>/dev/null); then
  # Session-memory files (.ai-context.md, .ai-worklog.md, ...) don't count as changes.
  ps=(':/' ':(top,exclude,glob).ai-*' ':(top,exclude,glob)**/.ai-*')
  fp=$( { git rev-parse HEAD; git -c core.safecrlf=false diff HEAD -- "${ps[@]}"; git ls-files --others --exclude-standard -z -- "${ps[@]}" | xargs -0 -r sha1sum; } 2>/dev/null | sha1sum | cut -c1-40)
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
