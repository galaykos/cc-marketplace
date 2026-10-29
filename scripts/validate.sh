#!/usr/bin/env bash
# validate.sh — BLOCKING structure gate: marketplace and plugin.json parity, frontmatter and SKILL budgets, doc location, jargon and removed refs, routing, lanes, README counts and tables, chassis headers, and the pc_* battery (scripts/lib/plugin-checks.sh); a FAIL line per finding, exit 1 if any.
# Misses: behaviour (no hook or skill runs), cost (context-budget.sh), the host schema (official-validate.sh), history (check-version-bumps.sh), chassis drift (generate.sh --check); several checks only WARN, and each pc_* header names its own residuals.
# Why, limits, history: rationale/derivations/scripts.md § scripts/validate.sh
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

# Scratch dirs under plugins/ draw one FAIL and are skipped below (rule: pc_stray_dirs' header); a heredoc, not a pipe, so fail=1 and STRAY_DIRS survive.
STRAY_DIRS=""
stray_out=$(pc_stray_dirs plugins) || true
while IFS= read -r l; do
  case "$l" in
    'stray '*)
      name="${l#stray }"
      err "stray directory plugins/$name has no tracked files — delete it (a hook or editor left scratch here)"
      STRAY_DIRS="$STRAY_DIRS $name " ;;
  esac
done <<EOF
$stray_out
EOF
is_stray() { case "$STRAY_DIRS" in *" $1 "*) return 0 ;; esac; return 1; }

# Every plugin directory must be listed in the marketplace
for dir in plugins/*/; do
  name=$(basename "$dir")
  is_stray "$name" && continue
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

# pc_frontmatter's lines split: structural ones err per file, linter ones park in FM_LINT for the linter loop; an unrecognised line counts as structural.
FM_LINT=""
fm_is_linter() { # $1 file, $2 one pc_frontmatter line
  case "${2#"$1: "}" in
    'description or when_to_use uses a YAML block scalar — keep it a single line' \
    | 'description '[0-9]*' chars (max 500)' \
    | 'description + when_to_use '[0-9]*' chars (max 500)' \
    | "description carries a 'Trigger words:' list — fold terms into the trigger sentence" \
    | "description or when_to_use carries a 'Trigger words:' list — fold terms into the trigger sentence") return 0 ;;
  esac
  return 1
}
# Returns 1 when the file is missing, has no opener or is unterminated — the skill
# loop skips the budget check then.
fm_structural() {
  local f="$1" m stop=0
  while IFS= read -r m; do
    if fm_is_linter "$f" "$m"; then FM_LINT="$FM_LINT$f"$'\t'"$m"$'\n'; continue; fi
    err "$m"
    case "$m" in "$f: missing frontmatter opener"|"$f: frontmatter not terminated") stop=1 ;; esac
  done < <(pc_frontmatter "$f")
  [ -f "$f" ] || stop=1
  return $stop
}
fm_linter() {
  local f="$1" m
  # A symlinked skill dir is skipped by the skill loop, so nothing was parked for it.
  if [ "${f##*/}" = SKILL.md ] && [ -L "${f%/SKILL.md}" ]; then
    while IFS= read -r m; do err "$m"; done < <(pc_frontmatter "$f")
    return
  fi
  while IFS= read -r m; do
    [ "${m%%$'\t'*}" = "$f" ] && err "${m#*$'\t'}"
  done <<<"$FM_LINT"
}

# Every skills/<name>/SKILL.md, in plugins and in .claude/skills (the tracked project skills): terminated frontmatter, name + description, a body within budget.
for d in plugins/*/skills/*/ .claude/skills/*/; do
  [ -d "$d" ] || continue
  # A symlinked project skill is someone else's file mounted here; only skills whose bytes live here are gated.
  [ -L "${d%/}" ] && continue
  f="${d}SKILL.md"
  fm_structural "$f" || continue
  if bud=$(pc_skill_budget "$f"); then :; else
    # "budget <path> <kind> <n> [:line]" -> one sentence naming the measure that
    # bit, since there are now three and "over the ceiling" no longer says which.
    bkind=$(printf '%s' "$bud" | awk '{print $3}')
    bval=$(printf '%s' "$bud" | awk '{print $4}')
    bwhere=$(printf '%s' "$bud" | awk '{print $5}')
    case "$bkind" in
      lines)       err "$f: body is $bval lines, over the 200-line ceiling" ;;
      bytes)       err "$f: body is $bval bytes, over the 14,000-byte ceiling — the line count stopped measuring growth, this is the replacement; move a section to references/" ;;
      line-length) err "$f: body line $bwhere is $bval characters, over the 300-char ceiling — reflow it; a jammed subsection is how content grows under a frozen line count" ;;
    esac
  fi
done

# Commands need frontmatter with description:; agents additionally need name:
for f in plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  fm_structural "$f"
done

# Description linter (hard). Why 500, why the pair, why no block scalar: rationale/derivations/scripts-lib.md § pc_frontmatter.
for f in plugins/*/skills/*/SKILL.md plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  fm_linter "$f"
done

# plugin.json description linter, WARN only: the clarity smell past 700 chars; always-on cost is context-budget.sh's.
for f in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$f" ] || continue
  dlen=$(jq -r '.description // ""' "$f" 2>/dev/null | wc -c | tr -d ' ')
  [ "$dlen" -le 700 ] || warn "$f: plugin description $dlen chars — over the 700-char clarity guideline; move detail to the README"
done

# Jargon and removed-artifact guards (HARD) over every functional .md, plugin-root doc and project skill; patterns, rescues and escapes live in pc_jargon and pc_removed_refs.
while IFS= read -r mdf; do
  # The jargon exemption is taskmaster's and task-runner's alone; every other check here walks them too.
  case "$mdf" in
    plugins/taskmaster/*|plugins/task-runner/*) ;;
    *) hit=$(pc_jargon "$mdf") \
         || err "$mdf: leaked internal taskmaster jargon [$hit] — scrub it or mark the line <!-- jargon-ok -->" ;;
  esac
  rhit=$(pc_removed_refs "$mdf") \
    || err "$mdf: references removed marketplace artifact [$rhit] — reroute to a live plugin/skill or mark the line <!-- removed-ok -->"
  ohit=$(pc_host_overlap "$mdf") \
    || err "$mdf: skill or command name collides with a built-in Claude Code skill [${ohit##* }] — defer to the host skill by name instead of re-implementing it, or mark the line <!-- host-ok -->"
  hhit=$(pc_handoff_refs "$mdf") \
    || err "$mdf: unresolved cross-plugin handoff [$(printf '%s' "$hhit" | awk '{print $3}' | sort -u | tr '\n' ' ')] — names no agents/, skills/ or commands/ file in that plugin; fix the name or mark the line <!-- handoff-ok -->"
done < <(
  {
    find plugins -type f \( -path '*/skills/*/SKILL.md' -o -path '*/skills/*/references/*.md' -o -path '*/commands/*.md' -o -path '*/agents/*.md' \)
    # the tracked project skills are held to the same jargon/removed-ref/handoff rules
    find .claude/skills -type f \( -path '*/SKILL.md' -o -path '*/references/*.md' \) 2>/dev/null
    # an unmatched glob prints its literal pattern; the pc_* [ -f ] guard skips it
    printf '%s\n' plugins/*/README.md plugins/*/CHANGELOG.md plugins/*/ROADMAP.md
  } | sort -u
)

# Dispatch binding (HARD): a shipped agent() sample spawning a marketplace agent passes agentType (pc_dispatch_binding); its own loop, for a narrower file set.
while IFS= read -r mdf; do
  dhit=$(pc_dispatch_binding "$mdf") \
    || err "$mdf: Workflow agent() sample spawns [$(printf '%s' "$dhit" | awk '{print $3}' | sort -u | tr '\n' ' ')] without agentType — the generic workflow subagent runs instead and the agent's contract never applies; pass agentType, or mark the sample <!-- dispatch-ok -->"
done < <(
  find plugins -type f \( -path '*/skills/*/SKILL.md' -o -path '*/skills/*/references/*.md' -o -path '*/commands/*.md' -o -path '*/agents/*.md' \) | sort -u
)

# Every /plugin:command reference in docs must resolve to a listed plugin
known=$(jq -r '.plugins[].name' "$MP")
while IFS=: read -r file ref; do
  pname="${ref#/}"; pname="${pname%%:*}"
  if ! echo "$known" | grep -qx "$pname"; then
    err "$file: reference '$ref' names unknown plugin '$pname'"
  else
    cname="${ref##*:}"
    # A /plugin:name reference resolves to a command file OR a same-named skill: custom commands merged into skills (code.claude.com/docs/en/skills).
    [ -f "plugins/$pname/commands/$cname.md" ] || [ -f "plugins/$pname/skills/$cname/SKILL.md" ] \
      || err "$file: reference '$ref' resolves to neither plugins/$pname/commands/$cname.md nor plugins/$pname/skills/$cname/SKILL.md"
  fi
done < <(grep -roEH '/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' README.md plugins/*/README.md plugins/*/commands plugins/*/skills plugins/*/agents 2>/dev/null \
         | grep -v 'https\?:' | grep -v '/preserve:' | sort -u)
         # /preserve:<name> is the template engine's preserve-block closer, not a plugin reference.

# hooks.json files must parse and referenced scripts must be executable. One
# pc_hook_exec call on plugins/, not one per plugin, so these FAILs keep find's order.
while IFS= read -r m; do err "$m"; done < <(pc_hook_exec plugins)
while IFS= read -r m; do err "$m"; done < <(pc_mod_modules plugins)
while IFS= read -r m; do err "$m"; done < <(pc_mod_kit plugins templates/mods/cc-kit.ts)

# Plugins ship only functional .md: root README/CHANGELOG/ROADMAP, SKILL.md and references/, commands/, agents/, evals/ (read by `claude plugin eval`).
allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$|^evals/.+\.md$'
while IFS= read -r mdf; do
  pc_doc_location "$mdf" "$allow_md" >/dev/null \
    || err "$mdf: non-functional doc inside a plugin — specs/design/task history belong in taskmaster-docs/, not plugins/"
done < <(find plugins -name '*.md')

# README leaf-count honesty: every plugin.json is a leaf (no plugin may declare dependencies).
leafcount=0
for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  leafcount=$((leafcount + 1))
done
# Every "all N [leaf] plugins" / "N leaf plugins" claim must equal the count, and a missing count is an error.
rc_all=$(grep -oE '(all [0-9]+ (leaf )?plugins|[0-9]+ leaf plugins)' README.md | grep -oE '[0-9]+')
if [ -z "$rc_all" ]; then
  err "README.md has no 'all N leaf plugins' count — the leaf-count claim must exist to be checkable"
else
  while IFS= read -r rc; do
    [ -n "$rc" ] || continue
    [ "$rc" = "$leafcount" ] \
      || err "README.md's leaf count says $rc but there are $leafcount plugins"
  done <<< "$rc_all"
fi

# A worker agent's `bestpractices-skill:` dirs must exist, and delegation-contracts must carry the priming doctrine.
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
DC=plugins/task-runner/skills/delegation-contracts/SKILL.md
if [ -f "$DC" ]; then
  { grep -q 'Skill priming' "$DC" && grep -q 'find ~/.claude/plugins' "$DC"; } \
    || err "$DC: skill-priming doctrine (resolve+inject) missing"
fi

# Agent routing: task-cards' tag vocabulary, routing.md and reviewer-routing.md keys agree, and every reviewer-map reference resolves.
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

# crew.md is linked from task-execution and every plugin:name in it resolves; the -d guard skips line-number and prose tokens.
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

# A chassis-shaped file carries the generate.sh header or an optout naming that exact file; an optout without `file` is an error, never a blanket.
for f in plugins/*/commands/review.md plugins/*/commands/uninstall.md plugins/*/commands/check.md plugins/*/hooks/remind.sh; do
  [ -f "$f" ] || continue
  grep -q 'generated from templates/' "$f" && continue
  pdir="$(dirname "$(dirname "$f")")"
  man="$pdir/.chassis.json"
  rel="${f#$pdir/}"
  if [ -f "$man" ] && jq -e --arg r "$rel" \
       '([.]|flatten)|any(.chassis=="optout" and .file==$r)' "$man" >/dev/null 2>&1; then
    continue
  fi
  if [ -f "$man" ] && jq -e '([.]|flatten)|any(.chassis=="optout" and (has("file")|not))' "$man" >/dev/null 2>&1; then
    err "$man: optout entry has no \"file\" — scope it to the chassis-shaped file it exempts (e.g. \"file\": \"$rel\"), or one exemption silently covers all four kinds"
    continue
  fi
  err "$f: chassis-shaped file has no generated header and no matching optout in .chassis.json (run scripts/generate.sh --write, or add {\"chassis\":\"optout\",\"file\":\"$rel\",\"reason\":\"…\"})"
done

# A worker-agent object's declared agentFile carries the generated header; keyed on that path, so hand-written agents beside it are untouched.
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

# ---- Governance gates ------------------------------------------------------

# Description parity (hard): marketplace.json and plugin.json descriptions are byte-identical.
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

# rules.tsv resolution (hard): every skill skill-router names (rules.tsv col 3, prime.sh `add` lines) exists.
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

  # rules.tsv overlap (hard): two high-confidence glob rows on one pattern need distinct stack_markers or a '# co-fire-ok:' directive.
  overlaps=$(pc_rules_overlap "$SR/rules.tsv") || true
  if [ -n "$overlaps" ]; then
    while IFS= read -r ol; do
      err "rules.tsv unresolved co-fire ($ol) — add distinct stack_markers or a '# co-fire-ok:' directive"
    done <<EOF_OVERLAPS
$overlaps
EOF_OVERLAPS
  fi
  # Reachability (hard): a row that cannot fire reads as coverage; route.sh basename-matches all but the `**/dir/**` form.
  unreach=$(pc_rules_reachable "$SR/rules.tsv") || true
  if [ -n "$unreach" ]; then
    while IFS= read -r ur; do
      err "rules.tsv unreachable row ($ur) — route.sh matches non-'**/dir/**' patterns against the BASENAME, so this can never fire"
    done <<EOF_UNREACH
$unreach
EOF_UNREACH
  fi

  # rules.tsv col 4 names a plugin directory; route.sh skips rows whose owner is not installed (pc_rules_owner's header).
  owners=$(pc_rules_owner "$SR/rules.tsv" plugins) || true
  if [ -n "$owners" ]; then
    while IFS= read -r ow; do
      err "rules.tsv owner missing ($ow) — col 4 must name the plugin that ships the col-3 skill; route.sh skips rows whose owner is not installed"
    done <<EOF_OWNER
$owners
EOF_OWNER
  fi

  # Content rows co-fire when two regexes match one corpus snippet, which the glob equality test above cannot see.
  cofires=$(pc_rules_cofire "$SR/rules.tsv" scripts/smoke/router-corpus) || true
  if [ -n "$cofires" ]; then
    while IFS= read -r cf; do
      err "rules.tsv unblessed content co-fire ($cf) — add a '# co-fire-ok: content <a> <b>' directive with a reason, or narrow a pattern"
    done <<EOF_COFIRES
$cofires
EOF_COFIRES
  fi

  # route-prompt.sh: no literal command token, at most four prompt greps (pc_route_prompt_literals/_greps); which command the model picks is agent-graded.
  RP="$SR/hooks/route-prompt.sh"
  if [ -f "$RP" ]; then
    prompt_lits=$(pc_route_prompt_literals "$RP") \
      || err "skill-router route-prompt.sh carries literal command token(s): $prompt_lits — the catalog is built from installed plugins, never hardcoded"
    head_greps=$(pc_route_prompt_greps "$RP") \
      || err "skill-router route-prompt.sh matches the prompt $head_greps times — at most 4 (three narrowing refusals + one work-shaped gate); a fifth is a routing table regrowing in shell"
  fi
fi

# No plugin may declare `dependencies` (hard): an update that adds one leaves it uninstalled (pc_plugin_dependencies' header).
deps_gap=$(pc_plugin_dependencies plugins) || true
while IFS= read -r l; do
  [ -n "$l" ] || continue
  err "$l — no plugin may declare dependencies: an update that adds one leaves it uninstalled and the plugin fails to load; express a companion as a README notice and a plugin-scout row instead"
done <<EOF_DEPS
$deps_gap
EOF_DEPS

# CHANGELOG parity (hard): the first `## [X.Y.Z]` heading equals marketplace metadata.version.
if [ -f CHANGELOG.md ]; then
  cl_ver=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  mp_ver=$(jq -r '.metadata.version // empty' "$MP")
  [ "$cl_ver" = "$mp_ver" ] \
    || err "CHANGELOG.md top version '$cl_ver' != marketplace metadata.version '$mp_ver'"
fi

# ---- keywords[] taxonomy gate --------------------------------------------------

# keywords (hard): every plugin.json carries non-empty keywords[] from scripts/taxonomy.txt; an unused term is a WARN.
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
  is_stray "$(basename "$d")" && continue
  missing_readme="${missing_readme} $(basename "$d")"
  rm_count=$((rm_count + 1))
done
[ "$rm_count" -eq 0 ] \
  || err "$rm_count plugin(s) missing README.md:${missing_readme}"

# Version-leverage stamp (HARD): a plugin claiming version leverage carries a `> Last verified:` stamp, or check-doc-staleness.sh cannot see it decay.
for d in plugins/*/; do
  us=$(pc_version_stamp "$d") \
    || err "plugin '${us##* }' claims version leverage with no \`> Last verified:\` stamp in any skill — check-doc-staleness.sh is structurally blind to its claims. Verify one load-bearing claim against upstream and stamp it, or narrow the plugin's description so it stops claiming version leverage."
done

# README listing (HARD): every plugin has a table ROW in README.md (`| **name**` or `| **[name](`); a prose mention does not count.
for d in plugins/*/; do
  lname=$(basename "$d")
  is_stray "$lname" && continue
  grep -qE "^\| \*\*(\[)?${lname}(\])?" README.md \
    || err "plugin '$lname' has no README.md plugin-table ROW (a prose mention is not a catalogue entry)"
done

# Empty sections (HARD): a `###` table header with zero rows claims a category and lists nothing.
awk '
  /^### / { heading=$0; state=1; next }
  state==1 && /^\| *Plugin/ { state=2; next }
  state==2 && /^\|[-| ]+\|$/ { state=3; next }
  state==3 { if ($0 ~ /^\|/) { state=0 } else if ($0 ~ /^[[:space:]]*$/) { print heading; state=0 } else { state=0 } }
  { if (state==1 && $0 !~ /^[[:space:]]*$/ && $0 !~ /^\| *Plugin/) state=0 }
' README.md | while IFS= read -r emptyheading; do
  err "README.md section '$emptyheading' has a table header with no rows — list something or remove the heading"
done

# Boost-preamble parity (HARD): task, brainstorm, coverage, redteam carry one byte-identical block naming every ultra.sh token; taskmaster.md is an alias.
TM_CMDS=plugins/taskmaster/commands
pre_ref=""
pre_ref_file=""
for c in task brainstorm coverage redteam; do
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
    err "boost-preamble: $f block differs from $pre_ref_file — the four full commands (task, brainstorm, coverage, redteam) must be byte-identical between markers; the taskmaster.md alias is gated separately"
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
# Alias shape (HARD): taskmaster.md stays a thin delegation to task.md ($ARGUMENTS, no preamble block, at most 25 lines).
TM_ALIAS="$TM_CMDS/taskmaster.md"
if [ -f "$TM_ALIAS" ]; then
  grep -q 'boost-preamble:start' "$TM_ALIAS" \
    && err "boost-preamble: $TM_ALIAS is an alias — it must not carry its own preamble block (delegate to task.md)"
  grep -qF 'commands/task.md' "$TM_ALIAS" && grep -qF '$ARGUMENTS' "$TM_ALIAS" \
    || err "$TM_ALIAS: alias shape broken — must delegate to commands/task.md passing \$ARGUMENTS"
  alias_lines=$(wc -l < "$TM_ALIAS" | tr -d ' ')
  [ "$alias_lines" -le 25 ] \
    || err "$TM_ALIAS: $alias_lines lines — an alias regressing into a copy (ceiling 25)"
fi

# ---- Lane declarations: who owns which territory -----------------------------
# Lanes: each plugin's lane.tsv, read by glob (no aggregate); agents and prompt/Stop/deny hooks are gate, commands and skills WARN; format and residuals above pc_lanes_schema.
lane_err() {   # lane_err <gate output> <one-line hint>; one err() per line
  local l
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    err "$l — $2"
  done <<EOF_LANE_ERR
$1
EOF_LANE_ERR
}
LANE_FILES=$(find plugins -maxdepth 2 -name lane.tsv | sort)
while IFS= read -r lf; do
  [ -n "$lf" ] || continue
  lo=$(pc_lanes_schema "$lf")    || lane_err "$lo" "a lane row is 6 tab-separated fields (artifact kind phase owns definite_trigger yields_to)"
  lo=$(pc_lanes_authority "$lf") || lane_err "$lo" "a plugin may declare only its own artifacts; a yields_to edge written for a sibling makes that sibling stand down"
  lo=$(pc_lanes_resolve "$lf")   || lane_err "$lo" "a lane row names an artifact that does not exist — fix the name or drop the row"
done <<EOF_LANE_FILES
$LANE_FILES
EOF_LANE_FILES
if [ -n "$LANE_FILES" ]; then
  lo=$(pc_lanes_territory $LANE_FILES) \
    || lane_err "$lo" "two artifacts claim one territory in one phase — give one a distinct owns, add a yields_to edge, or bless the PAIR with '# lane-cofire-ok: <a> <b>' in either file"
fi
lane_cov=$(pc_lanes_coverage plugins) || true
lane_gap=$(printf '%s\n' "$lane_cov" | grep '^lane-missing ' || true)
[ -n "$lane_gap" ] && lane_err "$lane_gap" "every agent, every UserPromptSubmit/Stop hook, and every deny-capable Pre/PostToolUse hook needs a row in its own plugin's lane.tsv"
lane_wc=$(printf '%s\n' "$lane_cov" | grep -c '^lane-warn command ' || true)
lane_ws=$(printf '%s\n' "$lane_cov" | grep -c '^lane-warn skill ' || true)
[ "$lane_wc" -gt 0 ] && warn "$lane_wc command(s) have no lane row — WARN tier this run; agents, prompt/Stop hooks and deny-capable Pre/PostToolUse hooks are the gate"
[ "$lane_ws" -gt 0 ] && warn "$lane_ws skill(s) have no lane row — WARN tier this run; agents, prompt/Stop hooks and deny-capable Pre/PostToolUse hooks are the gate"

# Adjacency (WARN): crowding on one phase and file shape, which the exact-`owns` territory gate cannot see (pc_lanes_adjacency's header).
lane_adj=$(pc_lanes_adjacency plugins) || true
if [ -n "$lane_adj" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — artifacts sharing one phase and one file shape; give one a narrower trigger, add a yields_to edge, or bless the pairs with '# lane-cofire-ok: <a> <b>'"
  done <<EOF_LANE_ADJ
$lane_adj
EOF_LANE_ADJ
fi

# A prompt/Stop hook that declared a SPECIFIC phase must read the sentinel, or it
# speaks in every phase forever. `any` lanes are guards and exempt by declaration.
phase_gap=$(pc_phase_guard plugins) || true
[ -n "$phase_gap" ] && lane_err "$phase_gap" "a hook whose lane names one phase must read .claude/cc-phase.json — declare the lane 'any' if it is a guard that must fire in every phase"

# A "defers X to <plugin>" description needs a yields_to edge in its own lane.tsv (pc_deference_edges' header).
def_gap=$(pc_deference_edges plugins) || true
[ -n "$def_gap" ] && lane_err "$def_gap" "plugin.json promises deference to a plugin that no lane row yields to — add the yields_to edge or reword the description"

# PostToolUse is the only channel that reaches subagents; a one-shot keyed on
# session_id is deduped by the parent's history and never speaks in the worker.
ctx_gap=$(pc_context_key plugins) || true
[ -n "$ctx_gap" ] && lane_err "$ctx_gap" "a PostToolUse one-shot must key on transcript_path (falling back to session_id) — or carry '# context-key-ok: <why>' when session scope is genuinely correct"

# A context key is usually an absolute path, so pasted raw into a filename it writes nowhere; pc_context_key cannot tell (pc_marker_key).
marker_gap=$(pc_marker_key plugins) || true
[ -n "$marker_gap" ] && lane_err "$marker_gap" "a context key reaching a filesystem path must be hashed first (cksum/shasum, as the `seen=` line in code-review/hooks/conventions.sh does) — or carry '# marker-key-ok: <why>'"

# A SKILL naming a reference as SOURCE OF TRUTH carries no figure that reference lacks (pc_source_of_truth's header).
sot_gap=$(pc_source_of_truth plugins) || true
[ -n "$sot_gap" ] && err "$sot_gap"

# Adding a gate silently falsifies standing claims elsewhere. Scope, preconditions
# and limits are stated ONCE, in pc_false_standing's header.
fs_gap=$(pc_false_standing plugins) || true
[ -n "$fs_gap" ] && err "$fs_gap"

# An agent told to do what its tools: cannot improvises; what is read and missed: pc_agent_tool_fit's header.
toolfit_gap=$(pc_agent_tool_fit plugins) || true
[ -n "$toolfit_gap" ] && lane_err "$toolfit_gap" "an agent is told to do what its tools: cannot — move the step to the main thread and pass the agent its result, name that actor in the sentence, grant the tool, or mark the paragraph or list (for a \`\`\`shell block, the one above it) '<!-- tool-fit-ok: <why> -->'"

# A harness sending only session_id grades the fallback branch, where pc_marker_key's defect hid (pc_harness_payload).
harness_gap=$(pc_harness_payload .) || true
[ -n "$harness_gap" ] && lane_err "$harness_gap" "this harness exercises a hook that reads transcript_path but never sends one — add a case with a path-shaped transcript_path, or carry '# harness-payload-ok: <why>'"

# prime.sh claims no skill the manifest map never sanctioned (FAIL), nor the map a signal prime.sh never emits (WARN); pc_prime_coverage's header.
prime_gap=$(pc_prime_coverage plugins) || true
prime_fwd=$(printf '%s\n' "$prime_gap" | grep '^prime-unmapped ') || true
prime_rev=$(printf '%s\n' "$prime_gap" | grep '^map-unprimed ') || true
[ -n "$prime_fwd" ] && lane_err "$prime_fwd" "prime.sh names a skill coding-entry/references/skill-map.md does not — add the row to that map, or mark the line '# prime-ok: <skill>' in prime.sh"
if [ -n "$prime_rev" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — coding-entry/references/skill-map.md declares this row and prime.sh emits nothing for it; add the branch to prime.sh, drop the row, or mark '# prime-ok: <skill>'"
  done <<EOF
$prime_rev
EOF
fi

# Every hook entry declares a timeout — that a number exists, not that it is right (pc_hook_timeout).
hook_to_gap=$(pc_hook_timeout plugins) || true
[ -n "$hook_to_gap" ] && lane_err "$hook_to_gap" "every hook entry in hooks.json must declare a timeout (seconds) — size it to what the script does, not to a house default"

# A command reading $ARGUMENTS declares argument-hint, shown in the slash-command menu (pc_command_arg_hint).
arghint_gap=$(pc_command_arg_hint plugins) || true
[ -n "$arghint_gap" ] && lane_err "$arghint_gap" "a command whose body reads \$ARGUMENTS must declare argument-hint: in its frontmatter — the host shows it in the slash-command menu"

# A registered hook starts #!/bin/bash so fail-open holds under a stripped PATH; escape `# env-shebang-ok: <reason>` (pc_hook_shebang).
shebang_gap=$(pc_hook_shebang plugins) || true
[ -n "$shebang_gap" ] && lane_err "$shebang_gap" "a registered hook must start #!/bin/bash so the fail-open guarantee holds under a stripped PATH where \`env bash\` exits 127; or carry '# env-shebang-ok: <reason>'"

# No `mkdir -p` under a payload cwd not proven to exist; a cwd that exists but is not this project is missed (pc_cwd_validated).
cwdval_gap=$(pc_cwd_validated plugins) || true
[ -n "$cwdval_gap" ] && lane_err "$cwdval_gap" "a hook mkdir -p's a path built from the payload cwd with nothing proving that directory still exists — add [ -d \"\$cwd\" ] (or a test on a path inside it) before the write, or carry '# cwd-mkdir-ok: <why>'"

# No state built from `$cwd/.claude` — cwd follows the model's cd; use the cc_state_root block (pc_state_root).
stroot_gap=$(pc_state_root plugins) || true
[ -n "$stroot_gap" ] && lane_err "$stroot_gap" "a hook builds a path from \$cwd/.claude — the payload cwd follows the model's cd; resolve root=\$(cc_state_root \"\$cwd\") (paste templates/blocks/state-root.md) and use \$root/.claude, or carry '# state-root-ok: <why this state is per-directory>'"

# A hook that defines a shared-block helper must carry the block byte-for-byte: plugins
# install alone, so the helper is copied, and an edited copy is a fix the others never got.
shblk_gap=$(pc_shared_blocks plugins templates/blocks) || true
[ -n "$shblk_gap" ] && lane_err "$shblk_gap" "a copy of a shared block differs from templates/blocks/<name>.md — paste the block file unchanged; change the block itself (and every copy) if the helper must change"

# A guard that can refuse names its off switch (WARN; per-message attribution is agent-graded — pc_offswitch_named).
offsw_gap=$(pc_offswitch_named plugins) || true
if [ -n "$offsw_gap" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — this hook can deny or block and reads that env switch, but names it in no text it emits; put '<VAR>=off disables this for the session' in the reason, or carry '# offswitch-ok: <why>'"
  done <<EOF
$offsw_gap
EOF
fi

# A version-pinning skill's stamp carries an npm:/composer:/pypi: tail for --live (WARN; the tail, never its truth — pc_version_stamp_tail).
stamptail_gap=$(pc_version_stamp_tail plugins) || true
if [ -n "$stamptail_gap" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — its frontmatter promises version pinning, so its 'Last verified' stamp needs an npm:/composer:/pypi: tail for check-doc-staleness.sh --live to read; or carry '<!-- version-tail-ok: <why> -->'"
  done <<EOF
$stamptail_gap
EOF
fi

# A scripts/glossary-watchlist.txt term in installer text with no row under README.md "## Words we use" (WARN only; pc_undefined_terms).
term_gap=$(pc_undefined_terms plugins scripts/glossary-watchlist.txt README.md) || true
while IFS= read -r l; do
  [ -n "$l" ] || continue
  warn "$l"
done <<EOF
$term_gap
EOF

# An unquoted `${CLAUDE_PLUGIN_ROOT}/…` run from a command or skill splits on a space; the host checks only hooks.json. One FAIL per plugin.
quote_gap=$(pc_plugin_root_quoting plugins) || true
if [ -n "$quote_gap" ]; then
  while IFS=$'\t' read -r qp qlocs; do
    err "plugin-root-unquoted $qp: $qlocs — a runnable line runs an unquoted \${CLAUDE_PLUGIN_ROOT} path (as the command, or as an interpreter's script), so an install path holding a space splits it; quote it: \"\${CLAUDE_PLUGIN_ROOT}/…\""
  done < <(printf '%s\n' "$quote_gap" | awk '{ a[$2] = a[$2] (a[$2] == "" ? "" : " ") $3 } END { for (p in a) print p "\t" a[p] }' | sort)
fi

# A ratchet on how many SKILL bodies crowd the 200-line ceiling (pc_budget_crowding's header).
crowd_gap=$(pc_budget_crowding plugins scripts/skill-crowding-baseline.json) || true
[ -n "$crowd_gap" ] && lane_err "$crowd_gap" "more SKILL bodies are now within 3 lines of the 200-line ceiling than the committed baseline — cut a body, do not raise scripts/skill-crowding-baseline.json"

# A ratchet on plugins over the per-plugin prose corpus cap, the channel neither per-file budget sees (pc_plugin_corpus's header).
corpus_gap=$(pc_plugin_corpus plugins scripts/plugin-corpus-baseline.json) || true
[ -n "$corpus_gap" ] && lane_err "$corpus_gap" "more plugins now exceed the per-plugin on-invoke prose corpus cap than the committed baseline — cut or split a plugin's skills, do not raise scripts/plugin-corpus-baseline.json"

# An `owns` noun is declared in scripts/lane-vocabulary.txt; the gate is on bookkeeping, the catch is social (pc_lanes_vocabulary).
vocab_gap=$(pc_lanes_vocabulary plugins scripts/lane-vocabulary.txt) || true
[ -n "$vocab_gap" ] && lane_err "$vocab_gap" "a lane row uses an owns noun that scripts/lane-vocabulary.txt does not declare — add it under its phase, next to the nouns it sits beside, or reuse one of those"

# A self-declared twin must still be identical: the pair's shared marker key is what
# makes exactly one of them ask. pc_twin_files' header carries the residuals.
twin_gap=$(pc_twin_files plugins) || true
[ -n "$twin_gap" ] && lane_err "$twin_gap" "a file declaring itself a TWIN has drifted from its partner — re-copy it so both differ only in the TWIN line"

# plugin-scout's tables feed --yes, which installs what they name, so each name must be live (pc_scout_names' header).
scout_name_gap=$(pc_scout_names .) || true
[ -n "$scout_name_gap" ] && lane_err "$scout_name_gap" "the plugin-scout skill suggests a plugin marketplace.json does not list — retarget the row, use the '—' no-plugin idiom, or mark the line '<!-- scout-name-ok: <why> -->'"

# A same-name command/skill pair: the listing keeps only the command's description.
# Residuals live in pc_cmd_skill_shadow's header.
shadow_gap=$(pc_cmd_skill_shadow plugins) || true
[ -n "$shadow_gap" ] && lane_err "$shadow_gap" "a plugin ships commands/<name>.md and skills/<name>/SKILL.md — the command's description shadows the skill's in the listing; fold one into the other, or mark the command '<!-- shadow-ok: <why> -->'"

# The host migrates installs from renames alone; the TSV is the same fact kept for the repo's
# own checks. Residuals live in pc_renames_ledger's header.
renames_gap=$(pc_renames_ledger .) || true
[ -n "$renames_gap" ] && lane_err "$renames_gap" "scripts/removed-plugins.tsv and marketplace.json renames disagree — every removed name needs a renames entry equal to its TSV successor, every chain must end at a current plugin or null without a cycle, and no renames key may be a live plugin; for renames-missing, add the entry (the jq command in scripts/removed-plugins.tsv's header rewrites the whole map, so run it only when every finding is renames-missing); for renames-orphan or renames-mismatch, add or correct the TSV row — never drop or retarget a committed renames key"

# pc_handoff_refs over plugin.json descriptions, the deference claims a user reads first; removed-ref and host-overlap would misfire there.
for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  pjhit=$(pc_handoff_refs "$pj") \
    || err "$pj: description names an unresolved handoff [$(printf '%s' "$pjhit" | awk '{print $3}' | sort -u | tr '\n' ' ')] — a deference claim a user reads before installing must point at something that exists"
done

# ---- Role-floor registry gate ------------------------------------------------
# role-floors.md agrees with agent frontmatter and every pinned agent is classified; FAIL strings frozen by role-floors-check.sh; a heredoc keeps fail=1.
RF=plugins/task-runner/skills/delegation-contracts/references/role-floors.md
rf_out=$(pc_role_floors "$RF" plugins) || true
rf_exempt=""
while IFS= read -r l; do
  case "$l" in
    'fail '*)   err "${l#fail }" ;;
    'exempt '*) rf_exempt="$rf_exempt
  ${l#exempt }" ;;
  esac
done <<EOF
$rf_out
EOF
printf '== role-floor exemptions ==\n'
if [ -n "$(printf '%s' "$rf_exempt" | tr -d '[:space:]')" ]; then
  printf '%s\n' "$rf_exempt" | grep -v '^[[:space:]]*$'
else
  printf '  (none)\n'
fi

# ---- No session tooling state inside a plugin --------------------------------
# Nothing under a plugin's `.claude/` may be tracked: plugins ship to users, and the root .gitignore rule is anchored.
while IFS= read -r f; do
  err "$f: session tooling state tracked inside a plugin — 'git rm -r --cached' it"
done < <(git ls-files 'plugins/*' 2>/dev/null | grep '/\.claude/' || true)

# ---- One severity vocabulary on review surfaces --------------------------------
# One severity scale (critical/high/medium/low) on review surfaces: divergent format definitions fail, words do not; spec-adversary is exempt.
while IFS= read -r f; do
  case "$f" in plugins/taskmaster/agents/spec-adversary.md) continue ;; esac
  err "${f%%:*}: divergent severity scale on a review surface — use critical/high/medium/low (line: ${f#*:})"
done < <(grep -rnE 'merge-after-blockers|Severities:[^\n]*blocker|[Bb]lockers first|critical → high → moderate' plugins/*/commands/*.md plugins/*/agents/*.md 2>/dev/null | cut -d: -f1,2 || true)

# ---- Dated-fact staleness report ---------------------------------------------
# `Last verified:` dates past STALE_DAYS are reported, WARN-only by design: a fact does not expire on a schedule.
STALE_DAYS=180
cutoff=$(date -u -v-${STALE_DAYS}d +%F 2>/dev/null || date -u -d "${STALE_DAYS} days ago" +%F 2>/dev/null || echo '')
printf '== dated-fact staleness (>%sd) ==\n' "$STALE_DAYS"
if [ -z "$cutoff" ]; then
  warn "cannot compute a staleness cutoff on this platform; dated facts unchecked"
else
  stale_n=0
  while IFS= read -r f; do
    d=$(grep -oiE 'last verified:?[^0-9]{0,3}[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" \
          | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | head -1)
    [ -n "$d" ] || continue
    if [ "$d" \< "$cutoff" ]; then
      warn "$f: 'Last verified: $d' is older than ${STALE_DAYS}d — re-verify or re-date"
      stale_n=$((stale_n + 1))
    fi
  done < <(grep -rliE 'last verified' --include='*.md' plugins 2>/dev/null | sort)
  [ "$stale_n" -eq 0 ] && printf '  (none stale)\n'
fi

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
