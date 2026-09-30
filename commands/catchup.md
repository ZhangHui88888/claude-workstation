---
description: Reload context after /clear — read everything changed on the current branch
---
Rebuild your picture of the work in progress without changing anything:

1. Run `git status` and `git diff --stat $(git merge-base HEAD main 2>/dev/null || echo HEAD)`.
2. Read every changed or untracked source file (skip lockfiles, build output and binaries).
3. Read `.ai-context.md` if it exists.
4. Summarize in at most 5 lines: what this branch is doing, what is done, what is left.
