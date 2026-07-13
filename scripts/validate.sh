#!/usr/bin/env bash
# Validates cc-plugins-marketplace structure. Exits non-zero on first category of failure.
set -u
cd "$(dirname "$0")/.."
. "$(dirname "$0")/lib/plugin-checks.sh" || { echo "FAIL: scripts/lib/plugin-checks.sh missing" >&2; exit 1; }
fail=0
err() { echo "FAIL: $1" >&2; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }

MP=.claude-plugin/marketplace.json
[ -f "$MP" ] || { echo "FAIL: $MP missing" >&2; exit 1; }
jq empty "$MP" 2>/dev/null || { echo "FAIL: $MP is not valid JSON" >&2; exit 1; }

# Every marketplace entry must resolve to a directory with a valid plugin.json
while IFS=$'\t' read -r name source; do
  dir="${source#./}"
  [ -d "$dir" ] || { err "plugin '$name': directory $dir missing"; continue; }
  pj="$dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || { err "plugin '$name': $pj missing"; continue; }
  jq empty "$pj" 2>/dev/null || { err "plugin '$name': $pj invalid JSON"; continue; }
  jname=$(jq -r .name "$pj")
  [ "$jname" = "$name" ] || err "plugin '$name': plugin.json name is '$jname'"
done < <(jq -r '.plugins[] | [.name, .source] | @tsv' "$MP")

# Every plugin directory must be listed in the marketplace
for dir in plugins/*/; do
  name=$(basename "$dir")
  jq -e --arg n "$name" '.plugins[] | select(.name == $n)' "$MP" >/dev/null \
    || err "directory plugins/$name not listed in marketplace.json"
done

# Installer rejects string authors: author (and marketplace owner) must be an
# object with a string .name
author_ok='if type == "object" then (.name | type == "string") else false end'
for pj in plugins/*/.claude-plugin/plugin.json; do
  jq -e ".author | $author_ok" "$pj" >/dev/null 2>&1 \
    || err "$pj: author must be an object with a string .name"
done
jq -e ".owner | $author_ok" "$MP" >/dev/null 2>&1 \
  || err "$MP: owner must be an object with a string .name"

# Every skills/<name>/ directory must contain SKILL.md with terminated frontmatter,
# name: + description:, and a 100-150 line body
for d in plugins/*/skills/*/; do
  [ -d "$d" ] || continue
  f="${d}SKILL.md"
  [ -f "$f" ] || { err "$d: SKILL.md missing"; continue; }
  head -1 "$f" | grep -q '^---$' || { err "$f: missing frontmatter opener"; continue; }
  awk '/^---$/{c++} END{exit !(c>=2)}' "$f" || { err "$f: frontmatter not terminated"; continue; }
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
  echo "$fm" | grep -q '^name:' || err "$f: frontmatter missing name:"
  sname=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  [ "$sname" = "$(basename "$d")" ] || err "$f: name '$sname' does not match directory '$(basename "$d")'"
  echo "$fm" | grep -q '^description:' || err "$f: frontmatter missing description:"
  echo "$fm" | grep -q '^description:.*Use \(when\|before\|after\|during\)' || err "$f: description lacks trigger phrasing (Use when/before/after/during)"
  if lines=$(pc_skill_budget "$f"); then :; else err "$f: body is ${lines##* } lines, outside 100-150 budget"; fi
done

# Commands need frontmatter with description:; agents additionally need name:
for f in plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q '^---$' || { err "$f: missing frontmatter opener"; continue; }
  awk '/^---$/{c++} END{exit !(c>=2)}' "$f" || { err "$f: frontmatter not terminated"; continue; }
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
  echo "$fm" | grep -q '^description:' || err "$f: frontmatter missing description:"
  case "$f" in
    */agents/*)
      echo "$fm" | grep -q '^name:' || err "$f: frontmatter missing name:"
      echo "$fm" | grep -q '^model:' || err "$f: frontmatter missing model: (agents default to sonnet)"
      echo "$fm" | grep -q '^effort:' || err "$f: frontmatter missing effort: (agents default to xhigh)"
      echo "$fm" | grep -q '^description:.*\(PROACTIVELY\|Spawned by\)' || err "$f: agent description needs PROACTIVELY or a sub-dispatch marker (Spawned by)"
      ;;
  esac
done

# Every /plugin:command reference in docs must resolve to a listed plugin
known=$(jq -r '.plugins[].name' "$MP")
while IFS=: read -r file ref; do
  pname="${ref#/}"; pname="${pname%%:*}"
  echo "$known" | grep -qx "$pname" \
    || err "$file: reference '$ref' names unknown plugin '$pname'"
done < <(grep -roEH '/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' README.md plugins/*/README.md plugins/*/commands plugins/*/skills plugins/*/agents 2>/dev/null \
         | grep -v 'https\?:' | sort -u)

# hooks.json files must parse and referenced scripts must be executable
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null || { err "$f: invalid JSON"; continue; }
  plugroot=$(dirname "$(dirname "$f")")
  while IFS= read -r cmd; do
    script="${cmd/\$\{CLAUDE_PLUGIN_ROOT\}/$plugroot}"
    [ -x "$script" ] || err "$f: hook script $script missing or not executable"
  done < <(jq -r '.. | .command? // empty' "$f" | grep '^\${CLAUDE_PLUGIN_ROOT}')
done < <(find plugins -path '*/hooks/hooks.json')

# Plugins ship ONLY functional files. Task documentation, specs, and design/task
# history live in taskmaster-docs/ (or a repo-level location outside plugins/) —
# never inside a plugin. Allowed .md: README/CHANGELOG/ROADMAP at a plugin root,
# a skill's SKILL.md and its references/, commands/, and agents/.
allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$'
while IFS= read -r mdf; do
  pc_doc_location "$mdf" "$allow_md" >/dev/null \
    || err "$mdf: non-functional doc inside a plugin — specs/design/task history belong in taskmaster-docs/, not plugins/"
done < <(find plugins -name '*.md')

# The 'everything' bundle must depend on every non-suite (leaf) plugin — a leaf
# plugin.json has no .dependencies; a bundle has them. Prevents an aggregate
# install silently missing a plugin, and keeps the README count honest.
EV=plugins/everything/.claude-plugin/plugin.json
if [ -f "$EV" ]; then
  evdeps=$(jq -r '.dependencies[]?' "$EV")
  nonsuite=0
  for pj in plugins/*/.claude-plugin/plugin.json; do
    jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 && continue  # skip bundles
    nonsuite=$((nonsuite + 1))
    name=$(jq -r .name "$pj")
    printf '%s\n' "$evdeps" | grep -qx "$name" \
      || err "everything bundle missing dependency '$name' (must list every non-suite plugin)"
  done
  rc=$(grep -oE 'all [0-9]+ plugins' README.md | grep -oE '[0-9]+' | head -1)
  { [ -z "$rc" ] || [ "$rc" = "$nonsuite" ]; } \
    || err "README says 'all $rc plugins' but there are $nonsuite non-suite plugins"
fi

# Stack-authoring-gap guard: a worker agent declaring `bestpractices-skill: <dir[,dir]>`
# must name skill dirs that exist, and the delegation-contracts doctrine that
# resolves+injects them must be present.
for f in plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  marker=$(awk '/^---$/{c++; next} c==1 && /^bestpractices-skill:/{sub(/^bestpractices-skill:[[:space:]]*/,""); print; exit}' "$f")
  [ -n "$marker" ] || continue
  IFS=',' read -ra _bp <<< "$marker"
  for d in "${_bp[@]}"; do
    d=$(printf '%s' "$d" | tr -d '[:space:]')
    ls -d plugins/*/skills/"$d" >/dev/null 2>&1 \
      || err "$f: bestpractices-skill '$d' has no matching plugins/*/skills/$d"
  done
done
DC=plugins/orchestration/skills/delegation-contracts/SKILL.md
if [ -f "$DC" ]; then
  { grep -q 'Skill priming' "$DC" && grep -q 'find ~/.claude/plugins' "$DC"; } \
    || err "$DC: skill-priming doctrine (resolve+inject) missing"
fi

# Agent-routing: the tag vocabulary (task-cards), the implement-side map keys
# (routing.md), and the verify-side map keys (reviewer-routing.md) must stay in sync,
# and every reviewer-map RHS reference must resolve — drift/typos break routing silently.
VOCAB=plugins/taskmaster/skills/task-cards/references/agent-tags.md
MAP=plugins/task-runner/skills/task-execution/references/routing.md
RMAP=plugins/task-runner/skills/task-execution/references/reviewer-routing.md
if [ -f "$VOCAB" ] && [ -f "$MAP" ]; then
  v=$(awk '/^## Closed vocabulary/{w=1;next} w&&/^```/{if(o)exit;o=1;next} w&&o{print}' "$VOCAB" | tr -s ' \t' '\n' | grep -v '^$' | sort -u)
  m=$(awk '/^## Resolution map/{w=1;next} w&&/^```/{if(o)exit;o=1;next} w&&o&&/→/{print $1}' "$MAP" | sort -u)
  if [ "$v" != "$m" ]; then
    err "agent-tag vocab (task-cards) != resolution-map keys (routing.md); differ on [$(comm -3 <(printf '%s\n' "$v") <(printf '%s\n' "$m") | tr -d '\t' | tr '\n' ' ')]"
  fi
  if [ -f "$RMAP" ]; then
    r=$(awk '/^## Resolution map/{w=1;next} w&&/^```/{if(o)exit;o=1;next} w&&o&&/->/{print $1}' "$RMAP" | sort -u)
    if [ "$v" != "$r" ]; then
      err "agent-tag vocab (task-cards) != reviewer-routing map keys; differ on [$(comm -3 <(printf '%s\n' "$v") <(printf '%s\n' "$r") | tr -d '\t' | tr '\n' ' ')]"
    fi
    for ref in $(awk '/^## Resolution map/{w=1;next} w&&/^```/{if(o)exit;o=1;next} w&&o' "$RMAP" | grep -oE '[a-z0-9-]+:[a-z0-9-]+' | sort -u); do
      pl=${ref%%:*}; nm=${ref#*:}
      [ -f "plugins/$pl/agents/$nm.md" ] || [ -f "plugins/$pl/skills/$nm/SKILL.md" ] \
        || err "reviewer-routing.md references '$ref' which resolves to no agent or skill"
    done
  fi
elif [ -f "$VOCAB" ] || [ -f "$MAP" ]; then
  err "agent-routing: one of agent-tags.md / routing.md exists without the other"
fi

# Crew reference check: crew.md (the --crew contract) must exist, be linked from the
# task-execution SKILL, and every plugin:name it names must resolve — a dangling ref or a
# lost link breaks the crew wiring silently. Mirrors the reviewer-routing RHS check; the
# `-d plugins/$pl` guard skips line-number tokens (crew.md:44) and prose (model:opus).
CREW=plugins/task-runner/skills/task-execution/references/crew.md
CREW_SKILL=plugins/task-runner/skills/task-execution/SKILL.md
if [ -f "$CREW" ]; then
  grep -q 'crew\.md' "$CREW_SKILL" \
    || err "crew.md exists but is not linked from task-execution SKILL.md"
  for ref in $(grep -oE '[a-z0-9-]+:[a-z0-9-]+' "$CREW" | sort -u); do
    pl=${ref%%:*}; nm=${ref#*:}
    [ -d "plugins/$pl" ] || continue
    [ -f "plugins/$pl/agents/$nm.md" ] || [ -f "plugins/$pl/skills/$nm/SKILL.md" ] \
      || [ -f "plugins/$pl/commands/$nm.md" ] \
      || err "crew.md references '$ref' which resolves to no agent, skill, or command"
  done
fi

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
