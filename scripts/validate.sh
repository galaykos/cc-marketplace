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

# A plugins/<x>/ with no manifest, no tracked file and no *.md / *.json outside its
# dot-directories is not a plugin that forgot its paperwork — it is scratch.
# plugins/design-studio/ held only a hook's marker files (code-review/hooks/verbosity.sh
# writes under the payload cwd) and drew three FAILs about a plugin that never existed,
# on a clean checkout of master, while CI stayed green because it checks out only
# tracked files. One message, and the README and plugin-table loops below skip it. A
# half-scaffolded plugin — untracked, but carrying a README or a manifest-shaped file —
# is NOT scratch: it falls through to those three FAILs, which are its checklist.
STRAY_DIRS=""
for dir in plugins/*/; do
  name=$(basename "$dir")
  [ -f "${dir}.claude-plugin/plugin.json" ] && continue
  [ "$(git ls-files "$dir" 2>/dev/null | wc -l | tr -d ' ')" = 0 ] || continue
  find "$dir" -path '*/.*' -prune -o -type f \( -name '*.md' -o -name '*.json' \) -print 2>/dev/null | grep -q . && continue
  err "stray directory plugins/$name has no tracked files — delete it (a hook or editor left scratch here)"
  STRAY_DIRS="$STRAY_DIRS $name "
done
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

# Every skills/<name>/ directory must contain SKILL.md with terminated frontmatter,
# name: + description:, and a body within the 200-line ceiling (no floor).
# `.claude/skills/*/` — the repo's tracked PROJECT skills, where the authoring
# doctrine has lived since 2026-09-03 — is held to the same rules: a doctrine home
# outside every gate would be the "recorded" tier pretending to be "gate".
for d in plugins/*/skills/*/ .claude/skills/*/; do
  [ -d "$d" ] || continue
  # A symlinked project skill is somebody else's file mounted here, not authored
  # in this repo; its budget and phrasing are theirs to keep. Only skills whose
  # bytes live here are gated. None is symlinked today: the last one, a vendored
  # 476-line plugin-structure skill, duplicated authoring-plugins and was removed.
  [ -L "${d%/}" ] && continue
  f="${d}SKILL.md"
  [ -f "$f" ] || { err "$d: SKILL.md missing"; continue; }
  head -1 "$f" | grep -q '^---$' || { err "$f: missing frontmatter opener"; continue; }
  awk '/^---$/{c++} END{exit !(c>=2)}' "$f" || { err "$f: frontmatter not terminated"; continue; }
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
  echo "$fm" | grep -q '^name:' || err "$f: frontmatter missing name:"
  sname=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  [ "$sname" = "$(basename "$d")" ] || err "$f: name '$sname' does not match directory '$(basename "$d")'"
  echo "$fm" | grep -q '^description:' || err "$f: frontmatter missing description:"
  # Trigger phrasing is for skills the MODEL picks from a listing. A skill carrying
  # `disable-model-invocation: true` is invoked only by name (`/name`), never
  # matched on its description, so an imperative description ("Scaffold a …") is
  # its correct shape — the rule is kind-level, never plugin-level.
  if ! echo "$fm" | grep -q '^disable-model-invocation:[[:space:]]*true'; then
    echo "$fm" | grep -q '^description:.*Use \(when\|before\|after\|during\)' || err "$f: description lacks trigger phrasing (Use when/before/after/during) — a user-invoked skill sets disable-model-invocation: true instead"
  fi
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
# 500 is a HOUSE budget, not a host limit. The two host caps it sits under: the CLI
# truncates `description` + `when_to_use` together at 1,536 chars in the skill listing
# (code.claude.com/docs/en/skills), and the Agent Skills API rejects a description over
# 1,024. Both count the pair, so this does too — a `when_to_use:` line is added to the
# measured length when present (rationale/marketplace-trend-audit-2026-09-16.md D3).
# The pair is read through pc_listing_fields, the same walk context-budget.sh meters
# with, so what this caps is exactly what that charges.
for f in plugins/*/skills/*/SKILL.md plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  fields=$(pc_listing_fields "$f")
  dsc=${fields%%$'\t'*}
  wtu=${fields#*$'\t'}; wtu=${wtu%%$'\t'*}
  # Block-scalar (>/|) descriptions would evade both this cap and the token
  # accounting (each reads the first line only) — reject the form outright.
  printf '%s\n%s\n' "$dsc" "$wtu" | grep -qE '^[>|]' \
    && err "$f: description or when_to_use uses a YAML block scalar — keep it a single line"
  [ -n "$dsc" ] || continue
  dlen=$(printf '%s%s' "$dsc" "${wtu:+ - $wtu}" | wc -c | tr -d ' ')
  [ "$dlen" -le 500 ] || err "$f: description${wtu:+ + when_to_use} $dlen chars (max 500)"
  printf '%s\n%s\n' "$dsc" "$wtu" | grep -qE 'Trigger( words)?:' \
    && err "$f: description${wtu:+ or when_to_use} carries a 'Trigger words:' list — fold terms into the trigger sentence"
done

# plugin.json description linter (WARN, not err): the frontmatter cap above never
# covered plugin manifests, which is how a 1039-char description shipped unseen
# (craft-layer, trimmed 2026-08-11). Always-on cost is already metered by
# context-budget.sh, so this warns on the CLARITY smell only — a description too
# long to be an install decision. Promote to err only after the tail is clean.
for f in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$f" ] || continue
  dlen=$(jq -r '.description // ""' "$f" 2>/dev/null | wc -c | tr -d ' ')
  [ "$dlen" -le 700 ] || warn "$f: plugin description $dlen chars — over the 700-char clarity guideline; move detail to the README"
done

# Jargon-leak guard (HARD): internal taskmaster process vocabulary — "card NN" /
# "cards NN", "Finding #N", "smoke-test #N", "the backlog" — must not leak into
# shipped plugin prose (today's craft-layer review scrubbed 8 such leaks no gate
# saw). Scans every functional .md per plugin (SKILL.md, references/*.md, commands,
# agents) via find — NOT a `**` glob (globstar is off in scripts/) — with
# references/ INCLUDED (the 8 leaks lived there), PLUS the plugin-root docs
# (README/CHANGELOG/ROADMAP) via shell glob, which never crosses `/` — root docs
# previously escaped the scan entirely. Excludes the taskmaster + task-runner
# plugins, where these are legitimate domain vocab. The `taskmaster-docs` PATH is a
# legitimate working-dir ref in ~6 plugins and is deliberately NOT a pattern.
#
# Removed-artifact guard (HARD), same file set: references to plugins/skills
# removed or merged away in the W6.5 baseline sweep (typescript, vue2,
# react-best-practices, the css-family skills, …) are dangling pointers the
# /plugin:command check cannot see — ~10 plugins carried them undetected.
# claude-api must be described as Claude Code's built-in/external skill, never as
# a marketplace artifact.
#
# The patterns themselves, the rescue lists, the <!-- jargon-ok --> /
# <!-- removed-ok --> escapes and the honest-scope notes all live in
# scripts/lib/plugin-checks.sh (pc_jargon, pc_removed_refs) — one source shared by
# these gates and their smoke fixtures. Do not restate them here; two copies of a
# matcher is a guarantee one goes stale.
while IFS= read -r mdf; do
  # The jargon exemption is theirs alone. Until 2026-09-17 this `continue` sat before
  # every check, so the two plugins that fan out the most were never walked by the
  # removed-ref, host-overlap or handoff gates — task-runner/commands/run.md carried a
  # <!-- host-ok --> nothing had read.
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

# Dispatch-binding gate (HARD). A shipped `agent(<args>)` sample that spawns an agent
# this marketplace ships must bind it with `agentType`; without it `Workflow` spawns the
# generic subagent and the agent's contract silently does not apply. Detector, guards and
# honest scope live in pc_dispatch_binding (scripts/lib/plugin-checks.sh).
#
# Its own loop, NOT the one above. When this was written that loop skipped taskmaster and
# task-runner outright — the two plugins that fan out the most — and inheriting the skip
# would have blinded this gate to its likeliest offender. The skip is jargon-only since
# 2026-09-17; the loop stays separate for its narrower file set (no plugin-root docs, no
# project skills).
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
    # A `/plugin:name` reference resolves to a command file OR a same-named
    # skill. Claude Code merged custom commands into skills — "A file at
    # .claude/commands/deploy.md and a skill at .claude/skills/deploy/SKILL.md
    # both create /deploy and work the same way"
    # (https://code.claude.com/docs/en/skills) — so a plugin that ships only the
    # skill still answers the slash command. Before 2026-08-20 this gate knew
    # only about commands/, which is why deleting three commands that merely
    # restated their identically-named skill produced 12 FAILs about references
    # that had never stopped working.
    [ -f "plugins/$pname/commands/$cname.md" ] || [ -f "plugins/$pname/skills/$cname/SKILL.md" ] \
      || err "$file: reference '$ref' resolves to neither plugins/$pname/commands/$cname.md nor plugins/$pname/skills/$cname/SKILL.md"
  fi
done < <(grep -roEH '/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' README.md plugins/*/README.md plugins/*/commands plugins/*/skills plugins/*/agents 2>/dev/null \
         | grep -v 'https\?:' | grep -v '/preserve:' | sort -u)
         # /preserve:<name> is the template engine's preserve-block closer
         # (<!-- /preserve:NAME -->), not a plugin reference — see
         # scripts/lib/template-engine.sh merge_preserve_blocks.

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
# a skill's SKILL.md and its references/, commands/, and agents/ — plus evals/,
# which is functional despite being prose: `claude plugin eval` reads
# `<plugin>/evals/**/prompt.md` and `graders/*.md` as the case definition, the same
# way a skill reads references/. Added 2026-08-20 with the first four suites; a
# design doc parked under evals/ is still a doc-location violation in spirit, and
# nothing here can tell the two apart.
allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$|^evals/.+\.md$'
while IFS= read -r mdf; do
  pc_doc_location "$mdf" "$allow_md" >/dev/null \
    || err "$mdf: non-functional doc inside a plugin — specs/design/task history belong in taskmaster-docs/, not plugins/"
done < <(find plugins -name '*.md')

# README leaf-count honesty. This USED TO ride on the `everything` bundle: the
# check walked that bundle's dependencies, and the count check lived inside
# `if [ -f "$EV" ]`. When `everything` was removed (2026-08-31 — 224
# description-bearing artifacts against the host's ~15k-char skill listing meant
# two thirds of it arrived name-only, nondeterministically; see
# rationale/2026-08-31-token-cost-review.md), the count check would have died
# with it, silently. It did not, because it was rehomed here first. Deleting an
# artifact can delete a gate riding on it, and nothing warns you.
#
# What was LOST and is not replaced: nothing now asserts that a new leaf plugin
# joins any bundle. There is no aggregate install to omit it from, so the old
# failure mode is gone rather than unguarded — but a leaf that belongs in a
# themed suite and is left out of it is now a WARN nobody writes. Stated, not
# hidden.
nonsuite=0
for pj in plugins/*/.claude-plugin/plugin.json; do
  jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 && continue  # skip bundles
  nonsuite=$((nonsuite + 1))
done
# Matches "all N plugins" AND "all N leaf plugins". The optional-word form is
# the point: the narrow original regex could not see README.md's actual wording
# ("all 72 leaf plugins"), so rc came back empty and the check passed vacuously
# — shipping the exact 72-vs-69 drift it was written to catch. A missing count
# is now an error too, not a silent pass.
# Widened again 2026-09-15, same lesson one layer down: this checked only the
# FIRST match and only the `all N …` wording, so README.md's opening line
# ("**27 leaf plugins**") was never covered. It carried 27 while the gated line
# carried 26 — one file disagreeing with itself, and the gate reporting green.
# Every leaf-count claim is now checked, not just the first one that parses.
rc_all=$(grep -oE '(all [0-9]+ (leaf )?plugins|[0-9]+ leaf plugins)' README.md | grep -oE '[0-9]+')
if [ -z "$rc_all" ]; then
  err "README.md has no 'all N leaf plugins' count — the leaf-count claim must exist to be checkable"
else
  while IFS= read -r rc; do
    [ -n "$rc" ] || continue
    [ "$rc" = "$nonsuite" ] \
      || err "README.md's leaf count says $rc but there are $nonsuite non-suite plugins"
  done <<< "$rc_all"
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
DC=plugins/task-runner/skills/delegation-contracts/SKILL.md
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
# commands/uninstall.md, commands/check.md, hooks/remind.sh — must EITHER carry the
# generate.sh header OR be named by an optout entry in its plugin's .chassis.json
# (object OR array form). Neither means the deterministic stamper never ran or was
# bypassed — drift the regenerate-and-diff gate must catch.
#
# The optout must name the file it exempts. The earlier test was
# `any(.chassis=="optout")` over the WHOLE manifest, so ONE opt-out entry exempted
# all four chassis-shaped kinds at once: api-design (docs-first) and build-vs-buy each hand-
# maintain commands/check.md while generating hooks/remind.sh, and a hand-edit that
# stripped the header off remind.sh would have been silently covered by check.md's
# exemption. An unscoped optout is now an error, not a blanket.
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
  # Reachability gate (hard): a row that CANNOT fire is worse than a missing row —
  # it reads as coverage. `**/routes/api.php` shipped for months matching nothing,
  # because route.sh basename-matches every pattern except the `**/dir/**` form.
  # The overlap and marker harnesses cannot see this class: a dead row collides
  # with nothing and reaches no marker.
  unreach=$(pc_rules_reachable "$SR/rules.tsv") || true
  if [ -n "$unreach" ]; then
    while IFS= read -r ur; do
      err "rules.tsv unreachable row ($ur) — route.sh matches non-'**/dir/**' patterns against the BASENAME, so this can never fire"
    done <<EOF_UNREACH
$unreach
EOF_UNREACH
  fi

  # Col-4 owner must be a plugin directory. rules.tsv:124 named a plugin folded
  # away weeks earlier; route.sh's installed-plugin filter suppressed the row and
  # nothing at author time read the column. Derivation: pc_rules_owner's header.
  owners=$(pc_rules_owner "$SR/rules.tsv" plugins) || true
  if [ -n "$owners" ]; then
    while IFS= read -r ow; do
      err "rules.tsv owner missing ($ow) — col 4 must name the plugin that ships the col-3 skill; route.sh skips rows whose owner is not installed"
    done <<EOF_OWNER
$owners
EOF_OWNER
  fi

  # Content-row co-firing, against a corpus of representative snippets. Content rows
  # never share a literal pattern, so the glob-axis equality test above is vacuous for
  # them; two different regexes matching one file is the real collision.
  cofires=$(pc_rules_cofire "$SR/rules.tsv" scripts/smoke/router-corpus) || true
  if [ -n "$cofires" ]; then
    while IFS= read -r cf; do
      err "rules.tsv unblessed content co-fire ($cf) — add a '# co-fire-ok: content <a> <b>' directive with a reason, or narrow a pattern"
    done <<EOF_COFIRES
$cofires
EOF_COFIRES
  fi

  # Tool-fit check gate (hard). route-prompt.sh injects a catalog it builds at runtime
  # from the installed plugins' command frontmatter, and hands the ROUTING JUDGMENT to
  # the model. Two properties are mechanically checkable and both are load-bearing:
  #
  #   1. No literal command token in the hook. A hardcoded `/plugin:command` is a route
  #      the catalog never shows and nobody can audit — the same rule route.sh carries.
  #   2. No per-tool routing patterns. The hook is allowed exactly ONE prompt-matching
  #      grep (the work-shaped gate); a second would be a routing table growing back in
  #      shell, which is the mechanism this deliberately replaced.
  #
  # What is NOT gated, stated plainly: which command the model picks. That is a
  # judgment with real variance — agent-graded, not gated. See the has-teeth
  # convention in CLAUDE.md; do not describe this check as guaranteeing a route.
  RP="$SR/hooks/route-prompt.sh"
  if [ -f "$RP" ]; then
    prompt_lits=$(grep -v '^[[:space:]]*#' "$RP" 2>/dev/null \
      | grep -oE '/[a-z][a-z0-9-]+:[a-z][a-z0-9-]+' | sort -u || true)
    [ -z "$prompt_lits" ] \
      || err "skill-router route-prompt.sh carries literal command token(s): $(echo $prompt_lits) — the catalog is built from installed plugins, never hardcoded"
    # Count prompt-matching greps: `$head` is the scrubbed prompt, so every grep over it
    # is a prompt pattern. The narrowing refusals and the single work-shaped gate are the
    # budget; anything past it is a routing rule.
    head_greps=$(grep -c 'printf .%s. "\$head" | grep' "$RP" 2>/dev/null || echo 0)
    [ "$head_greps" -le 4 ] \
      || err "skill-router route-prompt.sh matches the prompt $head_greps times — at most 4 (three narrowing refusals + one work-shaped gate); a fifth is a routing table regrowing in shell"
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
# the generated scout catalog (stack-scan's plugin-scout skill) and keyword-driven discovery rely on it.
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
  is_stray "$(basename "$d")" && continue
  missing_readme="${missing_readme} $(basename "$d")"
  rm_count=$((rm_count + 1))
done
[ "$rm_count" -eq 0 ] \
  || err "$rm_count plugin(s) missing README.md:${missing_readme}"

# Version-leverage stamp coverage (HARD, promoted from WARN on 2026-08-02).
# rationale/stack-skill-baselines.md exempts ~20 stack plugins from the
# baseline-redundancy loop on the promise that they encode version leverage rather
# than idioms; check-doc-staleness.sh can only see that leverage decay where a
# `> Last verified: YYYY-MM-DD — <url>` stamp exists, and until this morning not
# one of those plugins carried one.
#
# It shipped as a WARN because promoting it first would have forced a fabricated
# provenance record onto nine plugins — a stamp asserts that someone checked the
# content against that URL on that date, and writing nine unchecked ones would be
# a lie in the one file whose entire purpose is provenance. The verification pass
# has now run: every claimant's load-bearing version claim was checked against
# upstream and stamped with the URL actually consulted, so the gate has teeth
# without anyone having to trust it on faith.
for d in plugins/*/; do
  us=$(pc_version_stamp "$d") \
    || err "plugin '${us##* }' claims version leverage with no \`> Last verified:\` stamp in any skill — check-doc-staleness.sh is structurally blind to its claims. Verify one load-bearing claim against upstream and stamp it, or narrow the plugin's description so it stops claiming version leverage."
done

# README-listing (HARD): every plugin must also be LISTED in the top-level
# README.md plugin tables — a bolded `**name**` or `**[name](...)` row. Presence
# of a per-plugin README is not discoverability; 9 plugins shipped invisible to
# the catalog before this gate (2026-07-23).
#
# TIGHTENED 2026-08-02: the previous form accepted the bolded name ANYWHERE in
# the file, so a plugin mentioned once in a prose paragraph counted as catalogued
# while appearing in no table a reader browses. The row must now actually be a
# table row — a line starting `| **name**` or `| **[name](`.
for d in plugins/*/; do
  lname=$(basename "$d")
  is_stray "$lname" && continue
  grep -qE "^\| \*\*(\[)?${lname}(\])?" README.md \
    || err "plugin '$lname' has no README.md plugin-table ROW (a prose mention is not a catalogue entry)"
done

# Empty-section gate (HARD): a `###` heading followed by a table header and its
# separator with ZERO data rows is a section that claims a category and lists
# nothing. `### Automation & browser` sat empty from 2026-07-06 until this gate
# landed, and every structural check in this repo passed it — an empty table is
# well-formed markdown.
awk '
  /^### / { heading=$0; state=1; next }
  state==1 && /^\| *Plugin/ { state=2; next }
  state==2 && /^\|[-| ]+\|$/ { state=3; next }
  state==3 { if ($0 ~ /^\|/) { state=0 } else if ($0 ~ /^[[:space:]]*$/) { print heading; state=0 } else { state=0 } }
  { if (state==1 && $0 !~ /^[[:space:]]*$/ && $0 !~ /^\| *Plugin/) state=0 }
' README.md | while IFS= read -r emptyheading; do
  err "README.md section '$emptyheading' has a table header with no rows — list something or remove the heading"
done

# Boost-preamble parity (HARD): the four full taskmaster commands carry one
# byte-identical boost preamble between the `boost-preamble:start/end` markers,
# and every trigger token the ultra hook greps for is named inside that block —
# the trigger logic exists twice (bash regex in hooks/ultra.sh + command prose)
# and this gate keeps the two implementations from diverging silently.
# taskmaster.md is NOT in the list: it is a thin alias of task.md (checked
# below), which is how it stays in parity — by carrying nothing to drift.
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
# Alias-shape gate (HARD): taskmaster.md must stay a thin delegation to task.md.
# It was a 105-line byte-copy kept in sync by the parity gate above; parity by
# duplication was the bug, not the fix. Thin = delegates with $ARGUMENTS, names
# commands/task.md, carries no preamble block of its own, stays under 25 lines.
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
# Every plugin declares, in its own plugins/<name>/lane.tsv, which territory each
# of its artifacts owns, at which phase of the arc it may speak, the condition
# that fires it, and who outranks it. The pc_lanes_* family reads those files by
# glob (recount: `grep -c '^pc_lanes_[a-z_]*() {' scripts/lib/plugin-checks.sh`)
# — there is deliberately no generated aggregate, because a concatenation would carry no
# rule this glob does not and would add a chassis-drift surface for nothing.
#
# THE ONE THAT CARRIES THE MISSION is pc_lanes_territory: it is the only
# mechanical statement in this marketplace that two artifacts must not silently
# claim the same job. The 8 reviewer-class agents live in 8 different plugins
# with 8 distinct filenames, so every other gate here sees eight unrelated files
# while the model picks between them from descriptions alone.
#
# TIERS, per the has-teeth convention: agents and UserPromptSubmit/Stop hooks are
# `gate`; commands and skills are `WARN` this run and are reported as a count,
# not 200 lines. The format, the blessing shape, and the honest-scope residuals
# all live in scripts/lib/plugin-checks.sh above pc_lanes_schema — one source
# shared with scripts/smoke/lanes-tests.sh, which asserts these FAIL strings.
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

# The territory gate above fires only on an exact `owns` collision, and the live
# vocabulary is 1:1 with the claimed nouns, so it has never had a pair. Crowding is
# the defect the probe actually priced (eight rivals on one territory: firing
# 100% → ~75%), and it is invisible to a string compare. WARN tier deliberately —
# the derivation, the six live clusters and the FAIL flip are in the function's
# header in scripts/lib/plugin-checks.sh.
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

# A description that promises "defers X to <plugin>" must be backed by a
# yields_to edge in the plugin's own lane.tsv; host-built-in and plugin-class
# targets are skipped by design. Derivation: pc_deference_edges' header.
def_gap=$(pc_deference_edges plugins) || true
[ -n "$def_gap" ] && lane_err "$def_gap" "plugin.json promises deference to a plugin that no lane row yields to — add the yields_to edge or reword the description"

# PostToolUse is the only channel that reaches subagents; a one-shot keyed on
# session_id is deduped by the parent's history and never speaks in the worker.
ctx_gap=$(pc_context_key plugins) || true
[ -n "$ctx_gap" ] && lane_err "$ctx_gap" "a PostToolUse one-shot must key on transcript_path (falling back to session_id) — or carry '# context-key-ok: <why>' when session scope is genuinely correct"

# Reading the context key is half the job; the value is normally an absolute PATH, so a
# hook that pastes it into a filename writes to parents that do not exist and loses the
# bound it claims to keep. pc_context_key cannot see the difference — both hooks mention
# transcript_path. This is the half that can.
marker_gap=$(pc_marker_key plugins) || true
[ -n "$marker_gap" ] && lane_err "$marker_gap" "a context key reaching a filesystem path must be hashed first (cksum/shasum, as in code-review/hooks/conventions.sh:59) — or carry '# marker-key-ok: <why>'"

# A SKILL that names a reference as SOURCE OF TRUTH for its figures must not carry
# a figure that reference lacks. Converts a mirror the skill itself declared
# "recorded — no gate checks the two agree" into one that is checked. Scope and
# limits are stated ONCE, in pc_source_of_truth's own header, and pinned by
# scripts/smoke/source-of-truth-tests.sh.
sot_gap=$(pc_source_of_truth plugins) || true
[ -n "$sot_gap" ] && err "$sot_gap"

# Adding a gate silently falsifies standing claims elsewhere. Scope, preconditions
# and limits are stated ONCE, in pc_false_standing's header.
fs_gap=$(pc_false_standing plugins) || true
[ -n "$fs_gap" ] && err "$fs_gap"

# And the condition that let pc_marker_key's defect hide for a release: a harness
# that only ever sends session_id grades the fallback branch, so the branch the host
# actually takes is never executed. pc_marker_key gates the hook; this gates the
# test that would have caught it.
harness_gap=$(pc_harness_payload .) || true
[ -n "$harness_gap" ] && lane_err "$harness_gap" "this harness exercises a hook that reads transcript_path but never sends one — add a case with a path-shaped transcript_path, or carry '# harness-payload-ok: <why>'"

# The SessionStart index must not claim a skill the documented manifest map never
# sanctioned — that is how prime.sh came to assert tailwind on any React dependency.
# ...and, since 2026-09-22, the reverse: the map must not declare a repository signal
# the probe never emits. WARN TIER for that direction only — the two it found are in
# skill-router's hook, another hand than the one adding the check, and the forward
# direction stays a FAIL. Derivation and the matcher blind spot: pc_prime_coverage's header.
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

# A hook runs inside the user's turn, so the plugin must say how long it may hold
# it. Gates that a number EXISTS, not that it is right, and says nothing about
# what a killed hook does — both residuals are stated in pc_hook_timeout's header.
hook_to_gap=$(pc_hook_timeout plugins) || true
[ -n "$hook_to_gap" ] && lane_err "$hook_to_gap" "every hook entry in hooks.json must declare a timeout (seconds) — size it to what the script does, not to a house default"

# The slash-command menu shows `argument-hint` as the user types; without it a
# command that reads $ARGUMENTS asks for input it never names. Derivation and
# residuals: pc_command_arg_hint's header.
arghint_gap=$(pc_command_arg_hint plugins) || true
[ -n "$arghint_gap" ] && lane_err "$arghint_gap" "a command whose body reads \$ARGUMENTS must declare argument-hint: in its frontmatter — the host shows it in the slash-command menu"

# The fail-open guarantee six hook headers assert in their own words, read back. FAIL
# TIER as of 2026-09-22: all 11 offenders counted that day are fixed — eight were chassis
# output and went with one line each in templates/reminder-hook.sh.tmpl and
# templates/boost-hook.sh.tmpl, three (ui-ux and taskmaster preview-guard.sh, design-kit
# unread-pick.sh) by hand. The check shipped at WARN for exactly as long as the tree
# disagreed with it. `# env-shebang-ok: <reason>` is the escape for a host with no
# /bin/bash; the residuals are in pc_hook_shebang's header.
shebang_gap=$(pc_hook_shebang plugins) || true
[ -n "$shebang_gap" ] && lane_err "$shebang_gap" "a registered hook must start #!/bin/bash so the fail-open guarantee holds under a stripped PATH where \`env bash\` exits 127; or carry '# env-shebang-ok: <reason>'"

# A hook may not `mkdir -p` a path built from the payload's cwd without first proving
# that directory still exists — the shape that rebuilt a deleted three-level project
# tree to hold a state dir. FAIL tier: the live tree passes it as it lands. What it
# cannot see (a cwd that exists but is not this project) is in pc_cwd_validated's header.
cwdval_gap=$(pc_cwd_validated plugins) || true
[ -n "$cwdval_gap" ] && lane_err "$cwdval_gap" "a hook mkdir -p's a path built from the payload cwd with nothing proving that directory still exists — add [ -d \"\$cwd\" ] (or a test on a path inside it) before the write, or carry '# cwd-mkdir-ok: <why>'"

# The person who needs to know a guard has an off switch is the person it just refused.
# WARN TIER THIS RUN — five hooks in four plugins fail it the moment it ships, and they
# are other hands than the one adding the check. Per-message attribution is out of reach
# for a static reader; that half is agent-graded, and pc_offswitch_named's header says so.
offsw_gap=$(pc_offswitch_named plugins) || true
if [ -n "$offsw_gap" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — this hook can deny or block and reads that env switch, but names it in no text it emits; put '<VAR>=off disables this for the session' in the reason, or carry '# offswitch-ok: <why>'"
  done <<EOF
$offsw_gap
EOF
fi

# A skill that promises version pinning must leave check-doc-staleness.sh --live
# something to compare: an npm:/composer:/pypi: tail on its stamp. WARN TIER THIS RUN
# (two offenders, both other plugins'). It gates the TAIL, never its truth —
# pc_version_stamp_tail's header.
stamptail_gap=$(pc_version_stamp_tail plugins) || true
if [ -n "$stamptail_gap" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    warn "$l — its frontmatter promises version pinning, so its 'Last verified' stamp needs an npm:/composer:/pypi: tail for check-doc-staleness.sh --live to read; or carry '<!-- version-tail-ok: <why> -->'"
  done <<EOF
$stamptail_gap
EOF
fi

# Corpus-level companion to the per-file SKILL budget: a ceiling authors write TO
# stops being a ceiling, and no per-file check can see that. Ratchet, not
# threshold — the reasoning is in pc_budget_crowding's header.
crowd_gap=$(pc_budget_crowding plugins scripts/skill-crowding-baseline.json) || true
[ -n "$crowd_gap" ] && lane_err "$crowd_gap" "more SKILL bodies are now within 3 lines of the 200-line ceiling than the committed baseline — cut a body, do not raise scripts/skill-crowding-baseline.json"

# The third budget instrument: pc_skill_budget bounds one FILE, pc_budget_crowding
# bounds the distribution of file lengths, and NEITHER can see a plugin that stays
# under both while shipping a 100k-token prose corpus across a dozen skills. That
# channel is unmetered everywhere else — context-budget.sh gates three channels and
# CLAUDE.md says bodies loaded by a routing rule are "unmetered by nature". Prose
# only (.md, generated files excluded): counting runtime assets read taskmaster at
# 70,664 against a real 36,037. Ratchet, not ceiling — reasoning in the header.
corpus_gap=$(pc_plugin_corpus plugins scripts/plugin-corpus-baseline.json) || true
[ -n "$corpus_gap" ] && lane_err "$corpus_gap" "more plugins now exceed the per-plugin on-invoke prose corpus cap than the committed baseline — cut or split a plugin's skills, do not raise scripts/plugin-corpus-baseline.json"

# A bundle that overflows the FLOOR skill-listing budget (200k window, 3 B/tok,
# 1% = 6,000 chars) must tell the installer, because the failure is silent on
# their machine and invisible on a 1M maintainer's. Gates that the declaration
# STRING exists, not that its numbers are right — pc_listing_declaration's header
# carries the formula and the residuals.
listing_decl_gap=$(pc_listing_declaration plugins) || true
[ -n "$listing_decl_gap" ] && lane_err "$listing_decl_gap" "bundle overflows the 6,000-char floor listing budget without declaring it — mention skillListingBudgetFraction in its README (or bless with <!-- listing-floor-ok: why -->)"

# A bundle's README must name every plugin it installs. Two commits added a
# dependency to four bundles and updated zero READMEs; the all-bundle dependency
# gate above proved the deps RESOLVED and said nothing about whether a user could
# discover them. Presence only — nothing here gates that the description is true.
bundle_readme_gap=$(pc_bundle_readme_members plugins) || true
[ -n "$bundle_readme_gap" ] && lane_err "$bundle_readme_gap" "bundle README does not name a plugin its plugin.json installs — add a line for each name listed"

# An `owns` noun must be declared in scripts/lane-vocabulary.txt, so inventing one is a
# reviewed act rather than the invisible default. pc_lanes_vocabulary's header is candid
# that the catch is social; the gate is only on the bookkeeping.
vocab_gap=$(pc_lanes_vocabulary plugins scripts/lane-vocabulary.txt) || true
[ -n "$vocab_gap" ] && lane_err "$vocab_gap" "a lane row uses an owns noun that scripts/lane-vocabulary.txt does not declare — add it under its phase, next to the nouns it sits beside, or reuse one of those"

# A self-declared twin must still be identical: the pair's shared marker key is what
# makes exactly one of them ask. pc_twin_files' header carries the residuals.
twin_gap=$(pc_twin_files plugins) || true
[ -n "$twin_gap" ] && lane_err "$twin_gap" "a file declaring itself a TWIN has drifted from its partner — re-copy it so both differ only in the TWIN line"

# The plugin-scout skill's suggestion tables are hand-written and feed `--yes`, which
# INSTALLS what they name — so a name that outlived its plugin is an install command
# against nothing. Repo root, not `plugins`: the live set comes from marketplace.json.
# Column-scoped and liveness-only; both residuals are in pc_scout_names' header.
scout_name_gap=$(pc_scout_names .) || true
[ -n "$scout_name_gap" ] && lane_err "$scout_name_gap" "the plugin-scout skill suggests a plugin marketplace.json does not list — retarget the row, use the '—' no-plugin idiom, or mark the line '<!-- scout-name-ok: <why> -->'"

# Handoff resolution over plugin.json DESCRIPTIONS. Ten of them carry "Defers X to Y"
# claims — the densest ownership statements the marketplace ships, and the only ones a
# USER reads before installing. They were the one surface pc_handoff_refs never scanned,
# so a rename could orphan a user-facing deference claim silently.
# Only this check, not the three siblings in the loop above: pc_removed_refs and
# pc_host_overlap read prose intent and would misfire on a description that legitimately
# names a removed plugin or a host skill.
for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  pjhit=$(pc_handoff_refs "$pj") \
    || err "$pj: description names an unresolved handoff [$(printf '%s' "$pjhit" | awk '{print $3}' | sort -u | tr '\n' ' ')] — a deference claim a user reads before installing must point at something that exists"
done

# ---- Role-floor registry gate ------------------------------------------------
# role-floors.md rows must agree with agent frontmatter, and every agent pinning a
# real tier must be CLASSIFIED: either a registry row (floored) or `floor: none`
# plus a `floor-reason:` (deliberately unfloored). The nine FAIL strings below are
# frozen — scripts/smoke/validate-fixtures/role-floors-check.sh asserts each one.
# House rules obeyed on purpose: err() only (never exit; $fail governs :380+),
# `done < <(...)` not `| while read` (a subshell would discard fail=1), grep -qxF
# not `case` (a key containing * would glob-match in pattern position), and bash
# 3.2 / BSD-safe constructs only.
RF=plugins/task-runner/skills/delegation-contracts/references/role-floors.md
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

# ---- No session tooling state inside a plugin --------------------------------
# A plugin ships to users, so anything tracked under it is distributed. Local
# Claude Code state under a `.claude/` dir is per-session
# and per-machine and must never be part of that. The root .gitignore rule is
# anchored to the repo root, so nested `.claude/` dirs slipped through unnoticed
# until they were already committed; this is the check that would have caught it.
while IFS= read -r f; do
  err "$f: session tooling state tracked inside a plugin — 'git rm -r --cached' it"
done < <(git ls-files 'plugins/*' 2>/dev/null | grep '/\.claude/' || true)

# ---- One severity vocabulary on review surfaces --------------------------------
# Every finding-emitting command and reviewer agent sorts on ONE scale —
# critical/high/medium/low — so fan-in output merges without translation. Four
# scales coexisted (blocker/major/minor, moderate, blockers-then-minors, none),
# which made "Apply critical+high only" and "Fix blockers only" non-interoperable
# on the same diff. This bans the divergent FORMAT-DEFINITION shapes, not the
# words: prose like "a wrong mental model is the real blocker" stays legal.
# taskmaster's spec-adversary is exempt — its blocker/major/minor grades SPEC
# HOLES inside a closed pipeline, never code findings a fan-in merges.
while IFS= read -r f; do
  case "$f" in plugins/taskmaster/agents/spec-adversary.md) continue ;; esac
  err "${f%%:*}: divergent severity scale on a review surface — use critical/high/medium/low (line: ${f#*:})"
done < <(grep -rnE 'merge-after-blockers|Severities:[^\n]*blocker|[Bb]lockers first|critical → high → moderate' plugins/*/commands/*.md plugins/*/agents/*.md 2>/dev/null | cut -d: -f1,2 || true)

# ---- Dated-fact staleness report ---------------------------------------------
# Files that assert an observed fact about the world carry `Last verified: <date>`.
# A date nothing reads is a convention that dies quietly, so this reads them.
# WARN-ONLY BY DESIGN: a fact does not become wrong on a schedule, and a
# time-based failure would break CI on a quiet repo with no defect to fix.
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

# ---- Context-budget report ---------------------------------------------------
# Per-plugin session-start description-token surface vs committed baseline.
# The BLOCKING gate runs as its own CI step (Context-budget gate in
# validate.yml); here it is informational only — `|| true` keeps this script's
# exit governed solely by $fail.
bash scripts/context-budget.sh || true

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
