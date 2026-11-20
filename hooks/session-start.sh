#!/usr/bin/env bash
# SessionStart hook: stdout is added to Claude's context.
[ -t 0 ] || input=$(cat)
hookdir=$(cd "$(dirname "$0")" && pwd)
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "## Git"
  echo "branch: $(git branch --show-current)"
  git status -sb | head -25
  echo "recent commits:"
  git log --oneline -5
  # For the Stop hook: what the tree looked like when this session began. A session that changes
  # nothing has nothing of its own to verify (stop.sh). Kept from the first start, so a resume or a
  # compaction mid-session does not forget what the session changed before it.
  if [ -f .claude/verify.sh ]; then
    sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    start="/tmp/claude-verify-$sid.start"
    if [ -n "$sid" ] && [ ! -e "$start" ]; then
      . "$hookdir/verify-fp.sh"
      verify_fp > "$start"
    fi
  fi
fi
if [ -f .ai-context.md ]; then
  echo "## .ai-context.md"
  head -40 .ai-context.md
fi
exit 0
