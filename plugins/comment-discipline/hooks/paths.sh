# Shared path scoping for comment-discipline's two file guards (scan.sh, density.sh).
# Not executable and has no shebang: it is only ever sourced.
#
# WHY THIS EXISTS. Both guards skip `*/.claude/*` — meant to exempt the Claude
# configuration directory, whose contents nobody edits for readability. The pattern
# also matched every source file inside a git worktree, because this marketplace's own
# skills place worktrees at `.claude/worktrees/<branch>`: `worktree-isolation` says so,
# and `track-orchestration/references/algorithm.md` literally runs
# `git worktree add .claude/worktrees/<run-branch>-track-<slug>`. So the parallel-track
# execution path wrote all of its code into the one directory the comment guard was
# hardcoded to ignore, and a 73-file run drew not a single warning — one of two
# independent reasons that guard was silent (the other being that scan.sh detects
# comment KINDS, which is what density.sh was added to complement).
#
# The fix is scoping, not deleting the exemption: `.claude/settings.json` should still
# be exempt when it sits in a worktree. So the exclusion test runs against a LOGICAL
# path with any worktree prefix stripped — inside a worktree, a file is judged by where
# it sits in the checkout, exactly as the same file would be judged in the main tree.
#
# LIMITATION (honest scope): the `.claude/worktrees/<name>/` shape is a convention this
# marketplace states, not one git enforces. A worktree placed anywhere else was never
# excluded and is unaffected; a worktree placed at `.claude/wt/<name>` would still be
# skipped, and nothing here can detect that without probing the filesystem for a `.git`
# file on every edit, which is a cost this hook does not want on its hot path.

# cd_logical_path <path> — prints the path with every leading
# `…/.claude/worktrees/<name>/` segment removed, so exclusion patterns see the
# checkout-relative shape. Loops: a worktree checked out inside a worktree is
# unusual but the nesting is what the pattern would otherwise trip on.
cd_logical_path() {
  local p="$1" rest
  while :; do
    case "$p" in
      */.claude/worktrees/*/*)
        rest="${p#*/.claude/worktrees/}"   # <name>/<rest>
        rest="${rest#*/}"                  # <rest>
        [ -n "$rest" ] || break
        p="/$rest"
        ;;
      *) break ;;
    esac
  done
  printf '%s\n' "$p"
}
