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
      echo "$fm" | grep -q '^model:' || err "$f: frontmatter missing model: (pin a tier or use 'inherit')"
      echo "$fm" | grep -q '^effort:' || err "$f: frontmatter missing effort: (agents default to xhigh)"
      echo "$fm" | grep -q '^description:.*\(PROACTIVELY\|Spawned by\)' || err "$f: agent description needs PROACTIVELY or a sub-dispatch marker (Spawned by)"
      ;;
  esac
done

# Description linter (hard): a frontmatter description over 500 chars bloats the
# always-on context surface every session pays for; a literal "Trigger words:"
# list restates in-sentence terms. Both fail the build — trim, don't grandfather.
for f in plugins/*/skills/*/SKILL.md plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  # Block-scalar (>/|) descriptions would evade both this cap and the token
  # accounting (each reads the first line only) — reject the form outright.
  awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f" \
    | grep -qE '^description:[[:space:]]*[>|]' \
    && err "$f: description uses a YAML block scalar — keep it a single line"
  dsc=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f" | sed -n 's/^description:[[:space:]]*//p' | head -1)
  [ -n "$dsc" ] || continue
  dlen=$(printf '%s' "$dsc" | wc -c | tr -d ' ')
  [ "$dlen" -le 500 ] || err "$f: description $dlen chars (max 500)"
  printf '%s' "$dsc" | grep -qE 'Trigger( words)?:' \
    && err "$f: description carries a 'Trigger words:' list — fold terms into the trigger sentence"
done

# Every /plugin:command reference in docs must resolve to a listed plugin
known=$(jq -r '.plugins[].name' "$MP")
while IFS=: read -r file ref; do
  pname="${ref#/}"; pname="${pname%%:*}"
  if ! echo "$known" | grep -qx "$pname"; then
    err "$file: reference '$ref' names unknown plugin '$pname'"
  else
    cname="${ref##*:}"
    [ -f "plugins/$pname/commands/$cname.md" ] \
      || err "$file: reference '$ref' names no plugins/$pname/commands/$cname.md"
  fi
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

# Chassis agent-file header gate: every plugins/*/.chassis.json worker-agent object
# that declares an agentFile must have that EXACT file carry the generated header —
# keyed on the declared path only, never a plugins/*/agents/*.md glob, so hand-shaped
# reviewer agents next to migrated engineers (web-dev, ui-ux, devops) are untouched.
for man in plugins/*/.chassis.json; do
  [ -f "$man" ] || continue
  pdir="$(dirname "$man")"
  while IFS= read -r af; do
    [ -n "$af" ] || continue
    target="$pdir/$af"
    [ -f "$target" ] || continue
    grep -q 'generated from templates/worker-agent.md.tmpl' "$target" \
      || err "$target: declared agentFile has no generated header (run scripts/generate.sh --write)"
  done < <(jq -r '([.] | flatten) | .[] | select(.chassis=="worker-agent" and has("agentFile")) | .agentFile' "$man" 2>/dev/null)
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
  if [ -z "$mdesc" ] || [ -z "$pdesc" ]; then
    err "plugin '$name': empty .description (marketplace and plugin.json must both carry one)"
  elif [ "$mdesc" != "$pdesc" ]; then
    err "plugin '$name': marketplace.json .description != plugin.json .description"
  fi
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
      : # route.sh literals are checked separately below (a known-skill literal would
        # pass this resolution loop by definition — it needs its own err)
    } | sort -u
  )
  # route.sh must stay rules-driven: any literal known-skill name in it is an err
  route_lits=$(grep -v '^[[:space:]]*#' "$SR/hooks/route.sh" 2>/dev/null | grep -oE '[a-z][a-z0-9-]{3,}' | sort -u \
    | grep -xF -f <(for skd in plugins/*/skills/*/; do basename "$skd"; done | sort -u) || true)
  [ -z "$route_lits" ] \
    || err "skill-router route.sh carries literal skill name(s): $(echo $route_lits) — must stay rules.tsv-driven"

  # rules.tsv overlap gate (hard): two high-confidence glob rows sharing one
  # pattern must be stack_marker-discriminated or declared complementary via a
  # pairwise "# co-fire-ok:" directive — stack-exclusive pairs (vue2/vue3,
  # php/laravel) must never co-fire on a detectable stack.
  overlaps=$(pc_rules_overlap "$SR/rules.tsv") || true
  if [ -n "$overlaps" ]; then
    while IFS= read -r ol; do
      err "rules.tsv unresolved co-fire ($ol) — add distinct stack_markers or a '# co-fire-ok:' directive"
    done <<EOF_OVERLAPS
$overlaps
EOF_OVERLAPS
  fi
fi

# All-bundle dependency gate (hard): generalizes the everything-only completeness
# check above — every plugin.json that declares .dependencies (the bundles) must
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

# README-presence (HARD): every plugin ships a README.md. Backfilled 2026-07-14.
missing_readme=""
rm_count=0
for d in plugins/*/; do
  [ -f "${d}README.md" ] && continue
  missing_readme="${missing_readme} $(basename "$d")"
  rm_count=$((rm_count + 1))
done
[ "$rm_count" -eq 0 ] \
  || err "$rm_count plugin(s) missing README.md:${missing_readme}"

# README-listing (HARD): every plugin must also be LISTED in the top-level
# README.md plugin tables — a bolded `**name**` or `**[name](...)` row. Presence
# of a per-plugin README is not discoverability; 9 plugins shipped invisible to
# the catalog before this gate (2026-07-23).
for d in plugins/*/; do
  lname=$(basename "$d")
  grep -qF "**${lname}**" README.md || grep -qF "**[${lname}](" README.md \
    || err "plugin '$lname' not listed in any top-level README.md plugin table"
done

# Boost-preamble parity (HARD): the five taskmaster commands carry one
# byte-identical boost preamble between the `boost-preamble:start/end` markers,
# and every trigger token the ultra hook greps for is named inside that block —
# the trigger logic exists twice (bash regex in hooks/ultra.sh + command prose)
# and this gate keeps the two implementations from diverging silently.
TM_CMDS=plugins/taskmaster/commands
pre_ref=""
pre_ref_file=""
for c in task taskmaster brainstorm coverage redteam; do
  f="$TM_CMDS/$c.md"
  [ -f "$f" ] || { err "boost-preamble: missing command file $f"; continue; }
  blk=$(awk '/boost-preamble:start/{grab=1} grab{print} /boost-preamble:end/{exit}' "$f")
  if [ -z "$blk" ]; then
    err "boost-preamble: $f carries no boost-preamble marker block"
    continue
  fi
  h=$(printf '%s' "$blk" | cksum)
  if [ -z "$pre_ref" ]; then
    pre_ref="$h"; pre_ref_file="$f"
  elif [ "$h" != "$pre_ref" ]; then
    err "boost-preamble: $f block differs from $pre_ref_file — the five commands must be byte-identical between markers"
  fi
done
ULTRA_HOOK=plugins/taskmaster/hooks/ultra.sh
if [ -f "$ULTRA_HOOK" ] && [ -f "$TM_CMDS/task.md" ]; then
  canon_blk=$(awk '/boost-preamble:start/{grab=1} grab{print} /boost-preamble:end/{exit}' "$TM_CMDS/task.md")
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    plain=${tok//\?/}           # ultra-?task -> ultra-task
    printf '%s' "$canon_blk" | grep -qF "$plain" \
      || err "boost-preamble: hook token '$plain' (from $ULTRA_HOOK) not named in the command preamble block"
  done < <(grep -oE 'ultra-\?[a-z]+' "$ULTRA_HOOK" | sort -u)
fi

# ---- Role-floor registry gate ------------------------------------------------
# role-floors.md rows must agree with agent frontmatter, and every agent pinning a
# real tier must be CLASSIFIED: either a registry row (floored) or `floor: none`
# plus a `floor-reason:` (deliberately unfloored). The nine FAIL strings below are
# frozen — scripts/smoke/validate-fixtures/role-floors-check.sh asserts each one.
# House rules obeyed on purpose: err() only (never exit; $fail governs :380+),
# `done < <(...)` not `| while read` (a subshell would discard fail=1), grep -qxF
# not `case` (a key containing * would glob-match in pattern position), and bash
# 3.2 / BSD-safe constructs only.
RF=plugins/orchestration/skills/delegation-contracts/references/role-floors.md
rf_rows=""; rf_keys=""; rf_ok=1; rf_exempt=""
if [ -f "$RF" ]; then
  rf_rows=$(awk '/^```/{f=!f; next} f' "$RF" | grep -v '^[[:space:]]*$' || true)
fi
if [ -z "$rf_rows" ]; then
  err "role-floors registry: $RF missing, empty, or has no parseable rows"
  rf_ok=0
fi
if [ "$rf_ok" -eq 1 ]; then
  rf_seen=""; rf_dup=""
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    nf=$(printf '%s\n' "$row" | awk '{print NF}')
    key=$(printf '%s\n' "$row" | awk '{print $1}')
    tier=$(printf '%s\n' "$row" | awk '{print $2}')
    if printf '%s\n' "$rf_seen" | grep -qxF "$key"; then
      printf '%s\n' "$rf_dup" | grep -qxF "$key" \
        || { err "role-floors registry: $key appears more than once"; rf_dup="$rf_dup
$key"; }
    else
      rf_seen="$rf_seen
$key"
    fi
    if [ "$nf" -ne 2 ] || ! printf '%s' "$key" | grep -qE '^[a-z0-9-]+:[a-z0-9-]+$'; then
      err "role-floors registry: $key tier '$tier' is not one of haiku|sonnet|opus|fable"
      continue
    fi
    case "$tier" in
      haiku|sonnet|opus|fable) ;;
      *) err "role-floors registry: $key tier '$tier' is not one of haiku|sonnet|opus|fable"
         continue ;;
    esac
    rf_pl="${key%%:*}"; rf_nm="${key##*:}"; rf_ap="plugins/$rf_pl/agents/$rf_nm.md"
    if [ ! -f "$rf_ap" ]; then
      err "role-floors registry: $key resolves to no agent file ($rf_ap)"
      continue
    fi
    rf_fm=$(awk '/^---$/{c++; next} c==1' "$rf_ap" \
            | sed -n 's/^model:[[:space:]]*//p' | head -1 \
            | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ "$tier" = "$rf_fm" ] \
      || err "role-floors registry: $key tier '$tier' != $rf_ap frontmatter model '$rf_fm'"
    rf_keys="$rf_keys
$key"
  done < <(printf '%s\n' "$rf_rows")
fi
while IFS= read -r af; do
  [ -f "$af" ] || continue
  rf_fmb=$(awk '/^---$/{c++; next} c==1' "$af")
  rf_m=$(printf '%s\n' "$rf_fmb" | sed -n 's/^model:[[:space:]]*//p' | head -1 \
         | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
  [ -n "$rf_m" ] || continue          # a missing model: is validate.sh's own check, above
  [ "$rf_m" = "inherit" ] && continue # inherit is never floored and never needs a row
  rf_key="$(printf '%s' "$af" | cut -d/ -f2):$(basename "$af" .md)"
  rf_fl=$(printf '%s\n' "$rf_fmb" | sed -n 's/^floor:[[:space:]]*//p' | head -1 \
          | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
  rf_fr=$(printf '%s\n' "$rf_fmb" | sed -n 's/^floor-reason:[[:space:]]*//p' | head -1 \
          | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
  rf_has=0
  printf '%s\n' "$rf_keys" | grep -qxF "$rf_key" && rf_has=1
  if [ "$rf_has" -eq 1 ] && [ "$rf_fl" = "none" ]; then
    err "$af: has a role-floors row AND 'floor: none' - a row means floored"
    continue
  fi
  if [ "$rf_fl" = "none" ]; then
    if [ -z "$(printf '%s' "$rf_fr" | tr -d '[:space:]')" ]; then
      err "$af: 'floor: none' requires a non-empty floor-reason:"
    else
      rf_exempt="$rf_exempt
  $af: $rf_fr"
    fi
    continue
  fi
  case "$rf_m" in
    haiku|sonnet|opus|fable) ;;
    *) err "$af: frontmatter model '$rf_m' is not inherit or one of haiku|sonnet|opus|fable"
       continue ;;
  esac
  [ "$rf_has" -eq 1 ] \
    || err "$af: pins model '$rf_m' but has neither a role-floors row nor 'floor: none'"
done < <(find plugins -path '*/agents/*.md' -type f | sort)
printf '== role-floor exemptions ==\n'
if [ -n "$(printf '%s' "$rf_exempt" | tr -d '[:space:]')" ]; then
  printf '%s\n' "$rf_exempt" | grep -v '^[[:space:]]*$'
else
  printf '  (none)\n'
fi

# ---- Context-budget report ---------------------------------------------------
# Per-plugin session-start description-token surface vs committed baseline.
# The BLOCKING gate runs as its own CI step (Context-budget gate in
# validate.yml); here it is informational only — `|| true` keeps this script's
# exit governed solely by $fail.
bash scripts/context-budget.sh || true

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
