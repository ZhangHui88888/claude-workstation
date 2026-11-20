#!/usr/bin/env bash
# Stop hook: if the project has a .claude/verify.sh and this session changed the working tree (ignoring
# .ai-* files) since its last clean stop, run it. On failure, exit 2 so Claude keeps working (max 3
# attempts per session), then send a failure toast. No toast on success.
# "This session changed the tree" takes all three: it used a tool that can write since its last clean
# stop, the tree differs from what it was when the turn began (turn-start.sh), and it differs from the
# last tree that passed. Other sessions share the folder, so a changed tree alone proves nothing.
input=$(cat)
hookdir=$(cd "$(dirname "$0")" && pwd)
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // "none"' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
verify=.claude/verify.sh
[ -f "$verify" ] && gd=$(git rev-parse --git-dir 2>/dev/null) || exit 0

turn="/tmp/claude-verify-$sid.turn"    # the tree as the turn began; turn-start.sh writes it when absent
seen="/tmp/claude-verify-$sid.seen"    # transcript lines already covered by a clean stop
count_file="/tmp/claude-verify-$sid.count"
lines=$(wc -l < "$transcript" 2>/dev/null || echo 0)
clean() { rm -f "$turn" "$count_file"; echo "$lines" > "$seen"; exit 0; }

# Only reading and searching since the last clean stop: nothing of this session's own to verify.
if [ -f "$transcript" ]; then
  tail -n +"$(( $(cat "$seen" 2>/dev/null || echo 0) + 1 ))" "$transcript" |
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null |
    grep -Eqx 'Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell|Agent|Task|Workflow' || clean
fi

. "$hookdir/verify-fp.sh"
fp=$(verify_fp)
[ "$(cat "$turn" 2>/dev/null)" = "$fp" ] && clean
[ "$(cat "$gd/claude-verify.ok" 2>/dev/null)" = "$fp" ] && clean
if out=$(timeout 900 bash "$verify" 2>&1); then
  echo "$fp" > "$gd/claude-verify.ok"
  clean
fi
n=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$count_file"
if [ "$n" -le 3 ]; then
  { echo "Project verification (.claude/verify.sh) failed, attempt $n/3. Fix it before finishing:"
    printf '%s\n' "$out" | tail -40; } >&2
  exit 2
fi
bash "$hookdir/notify.sh" fail
clean
