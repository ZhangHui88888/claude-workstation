# Sourced by session-start.sh and stop.sh (run from the project root, inside a git checkout).
# verify_fp prints a fingerprint of the working tree: HEAD, the uncommitted diff and the untracked files.
# Session-memory files (.ai-context.md, .ai-worklog.md, ...) don't count as changes.
verify_fp() {
  local ps=(':/' ':(top,exclude,glob).ai-*' ':(top,exclude,glob)**/.ai-*')
  { git rev-parse HEAD; git -c core.safecrlf=false diff HEAD -- "${ps[@]}"; git ls-files --others --exclude-standard -z -- "${ps[@]}" | xargs -0 -r sha1sum; } 2>/dev/null | sha1sum | cut -c1-40
}
