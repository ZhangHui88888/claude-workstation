#!/usr/bin/env bash
# UserPromptSubmit hook: record what the working tree looks like as this turn begins, for the Stop hook.
# A turn that leaves the tree as it found it has nothing to verify (stop.sh), whatever other sessions
# sharing the folder committed before it. Kept while present: stop.sh removes it at a clean stop, so a
# message delivered mid-turn or after an interrupted turn does not forget what the session changed before it.
# Prints nothing: this hook's stdout would be added to Claude's context.
input=$(cat)
hookdir=$(cd "$(dirname "$0")" && pwd)
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
[ -f .claude/verify.sh ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
turn="/tmp/claude-verify-$sid.turn"
[ -e "$turn" ] && exit 0
. "$hookdir/verify-fp.sh"
verify_fp > "$turn"
exit 0
