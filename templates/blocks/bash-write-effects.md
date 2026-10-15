# Shared block templates/blocks/bash-write-effects.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-effects.md
# cc_bash_effects_mark <root> <marker> rewrites <marker> when <root> holds a .git, making its directory with a `*` .gitignore.
# Call it on EVERY tool call the hook sees (Write, Edit, Bash alike), after cc_bash_write_effects read <marker>: the tool has
# finished before PostToolUse runs, so <marker> then post-dates every write of the last call this hook saw.
# cc_bash_write_effects <root> <marker> <command> <max> prints at most <max> absolute paths, one per line: files `git status`
# under <root> reports changed or untracked AND newer than <marker>. It runs git only when <command> holds python, node, php,
# ruby, perl (any version suffix or directory), nodejs, deno, bun, cp, mv, install or patch as a word, and <marker> exists.
# Misses: writers it does not name, gitignored files, no git, a file written then reverted, a mv or cp -p destination (it
# keeps the source's mtime), files past <max>. Reads too much: any change since <marker> — an IDE, a parallel agent, a job.
cc_bash_effects_mark() {
  [ -e "$1/.git" ] || return 0
  local d="${2%/*}"
  [ -d "$d" ] || { mkdir -p "$d" && printf '*\n' > "$d/.gitignore"; } 2>/dev/null || return 0
  printf '%s\n' "$$" > "$2" 2>/dev/null
  return 0
}
cc_bash_write_effects() {
  local re='(^|[;&|(`[:space:]])([^[:space:];&|()`<>]*/)?((python|php|ruby|perl|node)[0-9.]*|nodejs|deno|bun|cp|mv|install|patch)[[:space:]<]'
  local e f n=0
  local -a c
  [ -f "$2" ] && [[ $3 =~ $re ]] || return 0
  while [ "$n" -lt "$4" ] && IFS= read -r -d '' e; do
    f="$1/${e:3}"
    [ -f "$f" ] && ! [ "$2" -nt "$f" ] || continue
    c[n]=$f; n=$((n + 1))
  done < <(GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain -z --untracked-files=all --no-renames --ignore-submodules=all 2>/dev/null)
  [ "$n" -gt 0 ] && find "${c[@]}" -prune -newer "$2" -print 2>/dev/null
  return 0
}
