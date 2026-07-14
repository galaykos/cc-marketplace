#!/usr/bin/env bash
# Validates cc-plugins-marketplace structure. Exits non-zero on first category of failure.
set -u
cd "$(dirname "$0")/.."
. "$(dirname "$0")/lib/plugin-checks.sh" || { echo "FAIL: scripts/lib/plugin-checks.sh missing" >&2; exit 1; }
fail=0
err() { echo "FAIL: $1" >&2; fail=1; }
warn() { echo "WARN: $1" >&2; }

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

# Chassis generated-header gate: every chassis-shaped file — commands/review.md,
# commands/uninstall.md, hooks/remind.sh — must EITHER carry the generate.sh header
# OR have its plugin's .chassis.json declare an optout entry (object OR array form).
# Neither header nor an optout manifest (or no manifest at all) means the deterministic
# stamper never ran or was bypassed — drift the regenerate-and-diff gate must catch.
for f in plugins/*/commands/review.md plugins/*/commands/uninstall.md plugins/*/commands/check.md plugins/*/hooks/remind.sh; do
  [ -f "$f" ] || continue
  grep -q 'generated from templates/' "$f" && continue
  man="$(dirname "$(dirname "$f")")/.chassis.json"
  if [ -f "$man" ] && jq -e '([.]|flatten)|any(.chassis=="optout")' "$man" >/dev/null 2>&1; then
    continue
  fi
  err "$f: chassis-shaped file has no generated header and no optout in .chassis.json (run scripts/generate.sh --write)"
done

# ---- W2-M2 governance gates ------------------------------------------------

# Description-parity gate (hard): a plugin's marketplace.json .description must be
# byte-identical to its plugin.json .description — a discovery listing that lies
# about what a plugin does is a silent rot the chassis system cannot catch.
while IFS=$'\t' read -r name source; do
  dir="${source#./}"
  pj="$dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || continue
  mdesc=$(jq -r --arg n "$name" '.plugins[] | select(.name==$n) | .description // ""' "$MP")
  pdesc=$(jq -r '.description // ""' "$pj")
  [ "$mdesc" = "$pdesc" ] \
    || err "plugin '$name': marketplace.json .description != plugin.json .description"
done < <(jq -r '.plugins[] | [.name, .source] | @tsv' "$MP")

# rules.tsv resolution gate (hard): every skill token the skill-router references —
# rules.tsv column 3, prime.sh `add <skill> <plugin>` lines, and any literal skill
# name in route.sh — must resolve to a real plugins/*/skills/<skill>/SKILL.md.
# route.sh sources its skills from rules.tsv at runtime and carries no literals
# post-W2-M1; the grep catches any that get re-introduced. Locks A1's phantom fix.
SR=plugins/skill-router
if [ -d "$SR" ]; then
  while IFS= read -r sk; do
    [ -n "$sk" ] || continue
    ls plugins/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 \
      || err "skill-router references skill '$sk' with no matching plugins/*/skills/$sk/SKILL.md"
  done < <(
    {
      awk -F'\t' '$1=="glob"||$1=="content"{print $3}' "$SR/rules.tsv" 2>/dev/null
      grep -oE '\badd [a-z][a-z0-9-]+ ' "$SR/hooks/prime.sh" 2>/dev/null | awk '{print $2}'
      grep -oE '[a-z][a-z0-9]*-(best-practices|audit|review|design|safety|hygiene)' "$SR/hooks/route.sh" 2>/dev/null
    } | sort -u
  )
fi

# All-bundle dependency gate (hard): generalizes the everything-only completeness
# check above — every plugin.json that declares .dependencies (the 8 bundles) must
# list only real marketplace plugin names, so no bundle silently ships a dangling
# or misspelled dependency.
mp_names=$(jq -r '.plugins[].name' "$MP")
for pj in plugins/*/.claude-plugin/plugin.json; do
  jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 || continue
  bname=$(jq -r .name "$pj")
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    printf '%s\n' "$mp_names" | grep -qx "$dep" \
      || err "bundle '$bname': dependency '$dep' is not a marketplace plugin name"
  done < <(jq -r '.dependencies[]?' "$pj")
done

# CHANGELOG-parity gate (hard): the first `## [X.Y.Z]` heading in CHANGELOG.md must
# equal the marketplace metadata.version — a released version with no matching
# changelog top entry (or vice versa) is undocumented drift.
if [ -f CHANGELOG.md ]; then
  cl_ver=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  mp_ver=$(jq -r '.metadata.version // empty' "$MP")
  [ "$cl_ver" = "$mp_ver" ] \
    || err "CHANGELOG.md top version '$cl_ver' != marketplace metadata.version '$mp_ver'"
fi

# ---- W2-M5 keywords[] taxonomy gate --------------------------------------------

# keywords gate (hard): scripts/taxonomy.txt is the controlled discovery vocabulary.
# Every plugin.json must carry a non-empty keywords[] whose every element is a
# taxonomy term. A missing/empty keywords[] or an off-vocab term fails the build —
# the generated plugin-scout catalog and keyword-driven discovery rely on it.
# Orphan taxonomy terms (declared but used by no plugin) are WARN only.
TAX=scripts/taxonomy.txt
if [ ! -f "$TAX" ]; then
  err "$TAX missing (keywords taxonomy is the controlled vocabulary)"
else
  for d in plugins/*/; do
    pj="${d}.claude-plugin/plugin.json"
    [ -f "$pj" ] || continue
    kname=$(basename "$d")
    if ! jq -e '(.keywords // null) | (type=="array" and length>0)' "$pj" >/dev/null 2>&1; then
      err "plugin '$kname': keywords[] missing or empty in plugin.json"
      continue
    fi
    while IFS= read -r kw; do
      [ -n "$kw" ] || continue
      grep -qxF "$kw" "$TAX" \
        || err "plugin '$kname': keyword '$kw' not in $TAX vocabulary"
    done < <(jq -r '.keywords[]' "$pj")
  done
  # orphan check (WARN only): every taxonomy term used by >=1 plugin.
  all_kw=$(jq -r '.keywords[]?' plugins/*/.claude-plugin/plugin.json 2>/dev/null | sort -u)
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    printf '%s\n' "$all_kw" | grep -qxF "$term" \
      || warn "taxonomy term '$term' in $TAX is used by no plugin (orphan)"
  done < "$TAX"
fi

# README-presence (HARD): every plugin ships a README.md. Backfilled 2026-07-14
# (was warn-only while 31/82 were missing one).
missing_readme=""
rm_count=0
for d in plugins/*/; do
  [ -f "${d}README.md" ] && continue
  missing_readme="${missing_readme} $(basename "$d")"
  rm_count=$((rm_count + 1))
done
[ "$rm_count" -eq 0 ] \
  || err "$rm_count plugin(s) missing README.md:${missing_readme}"

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
