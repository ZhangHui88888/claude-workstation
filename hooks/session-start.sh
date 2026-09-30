#!/usr/bin/env bash
# SessionStart hook: stdout is added to Claude's context.
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "## Git"
  echo "branch: $(git branch --show-current)"
  git status -sb | head -25
  echo "recent commits:"
  git log --oneline -5
fi
if [ -f .ai-context.md ]; then
  echo "## .ai-context.md"
  head -40 .ai-context.md
fi
exit 0
