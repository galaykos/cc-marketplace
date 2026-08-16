#!/usr/bin/env bash
# Shared per-plugin checks, sourced by validate.sh (full sweep) and
# authoring-guard.sh (single edited file). Pure: sourcing runs no code, functions
# close over no caller globals (no err/fail/allow_md), and take all inputs as args.

# pc_skill_budget <skill_md_path>
# On a body-length violation: prints "budget <path> <n>" and returns 1.
# Clean or missing file: prints nothing, returns 0.
#
# CEILING ONLY (2026-07-27). The former 100-line FLOOR was removed: it failed the
# build for a skill that said its piece in 60 lines, so bodies were padded up to
# clear it — 58 of 139 skills sat pinned to a budget edge (35 at 100-109, 5 at
# exactly 100, 23 at exactly 150). The floor manufactured the bloat the ceiling
# exists to stop.
#
# LIMITATION (honest scope), two residuals:
#   1. Nothing replaces the floor as a stub guard. validate.sh's description
#      check reads the frontmatter `description:` line only and constrains body
#      length in no way, so a 3-line body with a trigger sentence now passes
#      every gate in this repo. Accepted, not covered.
#   2. n=0 (missing or unterminated frontmatter — the `c>=2` awk emits nothing)
#      now returns 0 instead of failing. This function is authoring-guard.sh's
#      ONLY SKILL.md check, so a malformed SKILL.md draws no in-session warning;
#      validate.sh's frontmatter-opener/terminator checks still catch it at CI.
pc_skill_budget() {
  local f="$1" n
  [ -f "$f" ] || return 0
  n=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -l | tr -d ' ')
  if [ "$n" -gt 150 ]; then
    printf 'budget %s %s\n' "$f" "$n"
    return 1
  fi
  return 0
}

# pc_jargon <md_path>
# Internal-taskmaster-vocabulary denylist with an ordinary-English rescue list.
# On a hit: prints the comma-joined matches and returns 1. Clean: prints nothing,
# returns 0. Lives here so validate.sh and the smoke fixtures share ONE source —
# a fixture that re-declared the patterns would drift from the gate it tests.
#
# LIMITATION (honest scope): a heuristic denylist over prose with a rescue list,
# not a parser. It converts "leak the internal vocabulary without noticing" into
# "leak it in a form that does not read as ordinary English". Two residuals:
# (1) a real leak sharing a line with a rescued phrase is missed; (2) unrescued
# ordinary English in these shapes still false-positives, and the author's only
# recourse is the <!-- jargon-ok --> marker.
pc_jargon() {
  local f="$1" hit jargon rescue
  [ -f "$f" ] || return 0
  # cards? — plural included (2026-07-28): "cards 03, 05" leaked past the
  # singular-only pattern in a shipped SKILL while reading as internal vocab.
  jargon='(^|[^[:alnum:]])(cards? #?[0-9][0-9]|finding #[0-9]|smoke[ -]test #?[0-9]|the back-?log)'
  # Ordinary English that these shapes WOULD reject. No shipped plugin .md
  # contains them — the gate would have failed CI — so these are probes from the
  # task card, not observed leaks. Stating it that way keeps the claim inside
  # its evidence, which is the same discipline the gate itself is about.
  #   "Use a credit card 16 digits long."            (payments)
  #   "The backlog of user stories is groomed."      (estimation / rollout)
  #   "See finding #2 in the OWASP report."          (security)
  #   "Run smoke test 3 in the regression suite."
  rescue='(credit|debit|gift|payment|loyalty|graphics|SIM|library|report) card|card (number|reader|holder)|(product|sprint|issue|story|user|work) backlog|backlog of|(finding|smoke[ -]test) #?[0-9]+ (in|of|from) '
  hit=$(grep -viF '<!-- jargon-ok -->' "$f" \
        | grep -ivE "$rescue" \
        | grep -iEo "$jargon" \
        | sed 's/^[^[:alnum:]]//' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$hit" ] && return 0
  printf '%s\n' "$hit"
  return 1
}

# pc_removed_refs <md_path>
# Removed-artifact reference denylist (ground truth: rationale/stack-skill-
# baselines.md, 2026-07-27). The typescript/javascript/vue2 plugins and the
# react/css-family best-practices skills were removed; design-patterns,
# intent-guard, rollout, error-handling and concurrency were merged away as
# plugins. simplicity-principles and surgical-coding (code-architecture,
# 2026-07-28) were merged into low-cognitive-load and plan-before-code as
# references — the material survives, the always-on trigger does not, so a doc
# still routing a reader to them by name is the same dangling pointer. A shipped doc still routing to one of them is a dangling pointer no
# other gate sees — validate.sh's reference check reads only the
# /plugin:command slash form. On a hit: prints the comma-joined matches and
# returns 1. Clean: prints nothing, returns 0. Lives here so validate.sh and
# the smoke fixtures share ONE source, same as pc_jargon.
#
# SHAPE-BOUNDED BY DESIGN: rollout, concurrency, error-handling, typescript
# and javascript are ordinary technical English as bare words ("migrations, or
# concurrency" appears in ~20 review commands), so PLUGIN names match only in
# reference shapes — a bolded member row (**vue2**), "<name> plugin(s)", a
# plugins/<name> path, an install target (<name>@…), a routing arrow
# (→ <name>), or the /<name>: command form. Removed SKILL names
# (react-best-practices, css3/css-grid/flexbox/bootstrap-best-practices) are
# unambiguous hyphenates and match word-bounded anywhere. claude-api is Claude
# Code's BUILT-IN skill, not a marketplace artifact: a line naming it as if it
# were one is a hit UNLESS that line says built-in, external or
# harness-provided (or carries the escape) — the honest wording stays legal.
# harness-provided is in the token list because the shipped llm-app disclosure
# wraps: "Claude Code's built-in" ends one line and "claude-api skill —
# harness-provided, not part of this marketplace" starts the next, and this
# check is line-scoped by design.
#
# LIMITATION (honest scope): a heuristic over prose, lowercase-only for plugin
# names (TitleCase "TypeScript" is the language, not the plugin), so a
# capitalized stale row would slip; capability-breadth staleness ("react
# reviews components") names no removed artifact and is invisible here. The
# rescue list frees lines DISCUSSING a removal; anything else needs the
# <!-- removed-ok --> marker.
pc_removed_refs() {
  local f="$1" b plug skills shapes rescue hit capi
  [ -f "$f" ] || return 0
  b='[^[:alnum:]-]'
  plug='typescript|javascript|vue2|design-patterns|intent-guard|rollout|error-handling|concurrency'
  skills='react-best-practices|css3-best-practices|css-grid-best-practices|flexbox-best-practices|bootstrap-best-practices|simplicity-principles|surgical-coding|strategy-catalog'
  shapes="\\*\\*($plug)\\*\\*|(^|$b)($plug)\`? plugins?($b|\$)|(^|$b)plugins/($plug)($b|\$)|(^|$b)($plug)@|(→|->) ?\`?($plug)($b|\$)|/($plug):|(^|$b)($skills)($b|\$)"
  # Lines legitimately discussing the removal itself stay legal without a
  # marker. Every phrase below is quoted from a shipped disclosure:
  #   "it was removed after baseline testing"          (plugin-scout flags.md)
  #   "`error-handling` and `concurrency` plugins were / merged into this one"
  #   "**vue2** (Vue 2 is EOL) is no longer bundled"   (frontend-suite README)
  rescue="(was|were|been|are|is) (removed|merged|retired)|merged into|no longer|plugins? (were|was)($b|\$)"
  hit=$(grep -vF '<!-- removed-ok -->' "$f" \
        | grep -viE "$rescue" \
        | grep -Eo "$shapes" \
        | sed -e 's/^[^[:alnum:]*]*//' -e 's/[^[:alnum:]*]*$//' | sort -u | tr '\n' ',' | sed 's/,$//')
  capi=$(grep -vF '<!-- removed-ok -->' "$f" \
        | grep -ivE 'built-in|external|harness-provided' \
        | grep -Eo "(^|$b)claude-api($b|\$)" \
        | sed -e 's/^[^[:alnum:]]*//' -e 's/[^[:alnum:]]*$//' | sort -u | tr '\n' ',' | sed 's/,$//')
  if [ -z "$hit" ] && [ -z "$capi" ]; then
    return 0
  fi
  printf '%s\n' "$hit${hit:+${capi:+,}}$capi"
  return 1
}

# pc_doc_location <plugins_relative_md> <allow_regex>
# $1 is a repo-relative path beginning "plugins/<name>/…". Mirrors validate.sh:
# strips "plugins/*/" and greps the caller-supplied allow regex.
# On violation: prints "doc-location <path>" and returns 1. Clean: returns 0.
pc_doc_location() {
  local mdf="$1" allow="$2" rel
  rel=${mdf#plugins/*/}
  printf '%s\n' "$rel" | grep -qE "$allow" && return 0
  printf 'doc-location %s\n' "$mdf"
  return 1
}

# pc_rules_cofire <rules_tsv_path> <corpus_dir>
# CONTENT-row co-firing gate. Two content rows co-fire when BOTH patterns match at
# least one file in a shared corpus of representative source snippets. Every such
# unordered pair must be blessed by a
#   "# co-fire-ok: content <skillA> <skillB>"
# directive in the same file — the same convention the glob axis already uses.
#
# WHY A CORPUS, not pattern equality: pc_rules_overlap flags glob rows that share an
# IDENTICAL pattern string. Content rows never do — all five are distinct regexes at
# low confidence — so extending that algorithm here would be vacuous, matching nothing
# ever. Content rows collide because two DIFFERENT regexes match the same text: one
# ordinary React component containing `await`, `catch`, `fetch(`, `console.error` and
# `token` fires four of them at once. Only a corpus can express that.
#
# LIMITATION (honest scope): the corpus is a fixed, hand-written sample. This converts
# "add a content row and never learn what it co-fires with" into "add one and the gate
# names every existing row it collides with on realistic code". It does NOT prove the
# absence of collisions on code shapes the corpus does not contain, and it says nothing
# about whether a blessed co-fire is a good idea — only that someone declared it.
#
# On violation: prints "cofire <skillA> <skillB> <file>" per unblessed pair, returns 1.
pc_rules_cofire() {
  local f="$1" corpus="$2" rc=0
  [ -f "$f" ] || return 0
  [ -d "$corpus" ] || return 0
  local blessed pats skills n i j
  blessed=$(grep '^# co-fire-ok:[[:space:]]*content ' "$f" 2>/dev/null \
            | sed 's/^# co-fire-ok:[[:space:]]*content //')
  # collect content rows
  local -a P S
  while IFS="$(printf '\t')" read -r kind pat skill rest; do
    [ "$kind" = content ] || continue
    P+=("$pat"); S+=("$skill")
  done < <(grep -v '^#' "$f")
  n=${#P[@]}
  for (( i=0; i<n; i++ )); do
    for (( j=i+1; j<n; j++ )); do
      local hit=""
      for c in "$corpus"/*; do
        [ -f "$c" ] || continue
        if grep -qE "${P[$i]}" "$c" 2>/dev/null && grep -qE "${P[$j]}" "$c" 2>/dev/null; then
          hit="$(basename "$c")"; break
        fi
      done
      [ -n "$hit" ] || continue
      printf '%s\n' "$blessed" | grep -qE "(^|[[:space:]])${S[$i]}([[:space:]]|$)" \
        && printf '%s\n' "$blessed" | grep -qE "(^|[[:space:]])${S[$j]}([[:space:]]|$)" \
        && printf '%s\n' "$blessed" | grep -q "${S[$i]} ${S[$j]}\|${S[$j]} ${S[$i]}" && continue
      printf 'cofire %s %s %s\n' "${S[$i]}" "${S[$j]}" "$hit"
      rc=1
    done
  done
  return $rc
}

# pc_rules_overlap <rules_tsv_path>
# Flags unresolved same-pattern collisions among high-confidence glob rows.
# Every unordered pair of rows sharing an identical pattern must be either
# marker-discriminated (both rows carry a stack_marker, and they differ) or
# covered by a pairwise "# co-fire-ok: <pattern> <skillA> <skillB>" directive
# (space-tokenized) in the same file. Content and low-confidence rows are
# never flagged; identical-pattern subsumption (*.php vs *.blade.php) is out
# of scope by design.
# On violation: prints "overlap <pattern> <skillA> <skillB>" per pair and
# returns 1. Clean or missing file: returns 0.
pc_rules_overlap() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk -F'\t' '
    { sub(/\r$/, "") }
    /^# co-fire-ok:/ {
      line = $0
      sub(/^# co-fire-ok:[[:space:]]*/, "", line)
      n = split(line, t, /[[:space:]]+/)
      if (n >= 3) {
        ok[t[1] SUBSEP t[2] SUBSEP t[3]] = 1
        ok[t[1] SUBSEP t[3] SUBSEP t[2]] = 1
      }
      next
    }
    /^#/ { next }
    $1 == "glob" && $5 == "high" {
      m = $6; if (m == "-") m = ""
      # mirror marker_ok fail-open: a marker route.sh would ignore (no "~",
      # empty manifest or regex) must not count as a discriminator here
      if (m != "" && m !~ /^!?[^~]+~.+/) m = ""
      k = $2; cnt[k]++
      skill[k, cnt[k]] = $3; mark[k, cnt[k]] = m
    }
    END {
      bad = 0
      for (k in cnt)
        for (i = 1; i <= cnt[k]; i++)
          for (j = i + 1; j <= cnt[k]; j++) {
            a = skill[k, i]; b = skill[k, j]
            if (a == b) continue
            am = mark[k, i]; bm = mark[k, j]
            if (am != "" && bm != "" && am != bm) continue
            if (ok[k SUBSEP a SUBSEP b]) continue
            printf "overlap %s %s %s\n", k, a, b
            bad = 1
          }
      exit bad
    }' "$f"
}

# pc_rules_reachable <rules_tsv>
# Every shipped routing row must be ABLE to fire. Prints one `unreachable <kind>
# <pattern> <skill>` line per dead row and returns 1; clean or missing file
# returns 0.
#
# WHY THIS EXISTS. skill-router's match_glob (plugins/skill-router/hooks/route.sh:42-53)
# understands exactly one multi-segment form, `**/dir/**`, which it tests against
# the full path. EVERY other pattern is matched against the BASENAME — so a
# pattern containing a `/` outside that one form is compared to a string that can
# never contain a `/`, and cannot match any file, ever. `**/routes/api.php`
# shipped in that state and routed api-design zero times for months. The three
# existing router harnesses could not see it: rules-overlap-tests.sh checks
# pattern COLLISIONS and route-marker-tests.sh checks MARKER semantics, and a row
# that never fires collides with nothing and reaches no marker. A rule nobody can
# prove fires is indistinguishable from a rule that was never written, which is
# also why nobody could ever justify deleting one.
#
# LIMITATION (honest scope). This is a STRUCTURAL check, not a corpus check: it
# proves a glob CAN match some path, never that any file in a real project does.
# For content rows it only compiles the regex (an invalid ERE can never match
# either); asserting that each content regex matches a real fixture would need a
# corpus covering all 31 glob rows, and expanding scripts/smoke/router-corpus
# re-runs pc_rules_cofire's O(n^2) pairing over every added file. Accepted, not
# covered — the dead-pattern class above is the one that actually shipped.
pc_rules_reachable() {
  local tsv="$1" bad=0 kind pattern skill rest
  [ -f "$tsv" ] || return 0
  while IFS=$'\t' read -r kind pattern skill rest; do
    case "$kind" in ''|'#'*) continue ;; esac
    [ -n "$pattern" ] || continue
    case "$kind" in
      glob)
        # The only path-aware form route.sh implements.
        case "$pattern" in '**/'*'/**') continue ;; esac
        # Anything else is basename-matched; a `/` makes it unmatchable.
        case "$pattern" in
          */*) printf 'unreachable glob %s %s\n' "$pattern" "$skill"; bad=1 ;;
        esac ;;
      content)
        printf '' | grep -qE "$pattern" 2>/dev/null
        [ $? -gt 1 ] && { printf 'unreachable content %s %s\n' "$pattern" "$skill"; bad=1; } ;;
    esac
  done < "$tsv"
  return $bad
}

# pc_host_overlap <md_path>
# Fails a shipped plugin .md that introduces a SKILL whose name collides with a
# skill Claude Code itself ships. Prints one `hostoverlap <path>
# <name>` line per hit and returns 1; clean returns 0.
#
# WHY THIS EXISTS. This marketplace already made the host-deferral decision twice
# and wrote it down twice — craft-layer/skills/information-design/SKILL.md defers
# chart form and colour to the built-in `dataviz` skill BY NAME ("Do not duplicate
# dataviz guidance in craft-layer files", and "Duplicating dataviz" listed as an
# anti-pattern), and llm-app defers provider API specifics to the built-in
# claude-api skill. Both are held together by prose. The one host boundary any
# script enforces runs the OTHER way: pc_removed_refs' rescue list forbids
# describing `claude-api` as a marketplace artifact. Nothing checked the direction
# that costs tokens — a plugin re-implementing a capability the user already has,
# paying always-on description cost to compete with it for the same trigger.
#
# The name list is the host skill roster as of 2026-08-02. It is a NAME collision
# check only: a plugin may still cover adjacent ground, and should say so as a
# deferral. Mark a legitimate mention with <!-- host-ok --> on the line, matching
# the rescue idiom pc_removed_refs already uses.
#
# LIMITATION (honest scope). Name equality only. A skill called `chart-styling`
# that silently restates dataviz trips nothing, and the roster is a hardcoded list
# that goes stale when the harness ships a new built-in — the same standing
# pc_removed_refs' hardcoded removal list already carries. Accepted, not covered.
pc_host_overlap() {
  local f="$1" bad=0 name host
  [ -f "$f" ] || return 0
  local hosts="dataviz artifact-design artifact-capabilities skill-creator claude-api update-config keybindings-help fewer-permission-prompts claude-in-chrome simplify"
  # SKILLS ONLY. Commands are namespaced at the call site (`/code-review:review`
  # cannot be typed for the host's bare `/review`), so a command-name collision is
  # not a collision. A skill competes on its DESCRIPTION for the same trigger
  # regardless of which plugin owns it, which is the cost this gate is about.
  case "$f" in
    */skills/*/SKILL.md) name=$(basename "$(dirname "$f")") ;;
    *) return 0 ;;
  esac
  grep -qF '<!-- host-ok -->' "$f" && return 0
  for host in $hosts; do
    if [ "$name" = "$host" ]; then
      printf 'hostoverlap %s %s\n' "$f" "$name"; bad=1
    fi
  done
  return $bad
}

# pc_handoff_refs <md_path> [plugins_root]
# Every bare `<plugin>:<name>` handoff in a shipped plugin doc must RESOLVE to a
# real artifact in that plugin: agents/<name>.md, skills/<name>/SKILL.md or
# commands/<name>.md. Prints one `handoff <path> <token>` line per unresolved
# reference and returns 1; clean returns 0.
#
# WHY THIS EXISTS. validate.sh has always gated the SLASH form `/plugin:command`
# globally, and pc_removed_refs knows a hardcoded list of plugins deleted from
# this marketplace. Neither sees the bare `plugin:agent` form — the one the
# routing chains, reviewer maps and worker handoffs are actually written in. So
# `ui-ux:ui-ux-enginer` (typo), `taskrunner:task-executor` (wrong plugin name) and
# a rename that missed one call site all shipped green, and the failure is silent
# at runtime: the model reads a name that does not exist and quietly does the work
# inline instead of delegating. About 90 such edges ship today across 37 distinct
# targets, and nothing checked any of them.
#
# TWO STRUCTURAL GUARDS, so there is no exclusion list to maintain:
#   1. LHS must be a real plugin directory. That drops `model:opus`, `http:` and
#      every YAML-ish token in one rule.
#   2. A token immediately preceded by `<` is markup, not a handoff. Blade and
#      Livewire component tags (`<livewire:item-row />`) share this syntax
#      exactly, and a cross-plugin handoff is never written as an opening tag.
#      Without this the three shipped Livewire examples fail, and the alternative
#      — an HTML comment escape inside a fenced Blade snippet — would corrupt the
#      example it is documenting.
# Fenced code is deliberately IN scope: the reviewer Resolution map and the worker
# chains live inside fences, and they are the edges most worth checking.
#
# LIMITATION (honest scope). Resolution only. It cannot tell whether the
# referenced plugin is INSTALLED in the reader's session — that is the degradation
# question, and the answer is prose ("if installed") that no script can verify
# means what it says. It also cannot see a deferral to a HOST skill, which is
# written as a bare name with no plugin prefix; pc_host_overlap covers the name
# collision, nothing covers a host deferral going stale.
#
# Mark a legitimate non-reference (a Blade tag, a quoted example of a bad name)
# with <!-- handoff-ok --> on the line, matching the rescue idiom the jargon and
# removed-artifact guards already use.
#
# SINGLE PASS, deliberately. The first implementation looped over every line and
# spawned grep+sed+sort per line; across ~400 shipped docs that took validate.sh
# from 30s to 110s, and role-floors-check — which runs validate.sh nine times —
# to seven minutes. A gate slow enough to discourage running it locally is a gate
# that only fires in CI. Two greps per file, then one filesystem probe per
# DISTINCT token.
pc_handoff_refs() {
  local f="$1" root="${2:-plugins}" bad=0 tok lhs rhs ln skiplines
  [ -f "$f" ] || return 0
  # Line numbers carrying the escape, as a space-padded set for O(1)-ish lookup.
  skiplines=" $(grep -nF '<!-- handoff-ok -->' "$f" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    tok="${ln#*:}"; ln="${ln%%:*}"
    case "$skiplines" in *" $ln "*) continue ;; esac
    lhs="${tok%%:*}"; rhs="${tok##*:}"
    [ -d "$root/$lhs" ] || continue
    [ -f "$root/$lhs/agents/$rhs.md" ] && continue
    [ -f "$root/$lhs/skills/$rhs/SKILL.md" ] && continue
    [ -f "$root/$lhs/commands/$rhs.md" ] && continue
    printf 'handoff %s %s\n' "$f" "$tok"
    bad=1
  done < <(grep -nEo '(^|[^/`<[:alnum:]_-])[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' "$f" 2>/dev/null \
    | sed -E 's/^([0-9]+):[^a-z]*/\1:/' | sort -u -t: -k1,1 -k2,2)
  return $bad
}

# pc_version_stamp <plugin_dir>
# A plugin whose OWN plugin.json description claims version leverage should carry
# a `> Last verified: YYYY-MM-DD — <url>` stamp somewhere in its skills, so
# check-doc-staleness.sh can see it decay. Prints `unstamped <plugin>` and returns
# 1 when the claim exists and no stamp does; returns 0 otherwise.
#
# STANDING: recorded, NOT gate — and the distinction is the point, per CLAUDE.md's
# has-teeth convention. validate.sh prints this as a WARN and never fails on it.
#
# WHY IT IS NOT BLOCKING YET. rationale/stack-skill-baselines.md exempts ~20
# tier-1 stack plugins from the baseline-redundancy loop on the explicit promise
# that they encode version leverage rather than idioms. Ten of them make that
# claim in their own description and none carries a stamp. Making this blocking
# today would force a stamp onto each — and a stamp is a claim that a human or a
# fetch actually verified the content on that date against that URL. Writing ten
# of those without doing the verification would be a fabricated provenance record
# in the one file whose entire purpose is provenance: the honest-limitation law
# forbids it more clearly than almost anything else in this repo.
#
# TO PROMOTE IT TO `gate`: run one real verification pass per claimant, stamp what
# was actually checked, then change validate.sh's warn to err. The list this
# prints IS the work queue for that pass.
pc_version_stamp() {
  local pdir="$1" pj="$1/.claude-plugin/plugin.json" desc name
  [ -f "$pj" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 && return 0
  name=$(jq -r '.name // empty' "$pj" 2>/dev/null)
  desc=$(jq -r '.description // empty' "$pj" 2>/dev/null)
  # `lockfile` was in this list and was WRONG: `packages` describes lockfile
  # DISCIPLINE — semver semantics, which do not drift — and was flagged as owing a
  # provenance stamp it has nothing to stamp. A detector that manufactures debt
  # teaches people to ignore it. Match only phrases that assert a moving fact.
  printf '%s' "$desc" | grep -qiE 'version-aware|version leverage|version-leverage|as of [0-9]|version[- ]conditional|[0-9]+\.[0-9]+\+' || return 0
  # find, not a glob: an unmatched glob is a literal path under bash and a hard
  # error under zsh, and this file is sourced by both validate.sh and a hook.
  find "$pdir/skills" -type f -name '*.md' -exec grep -lq '^> Last verified:' {} + 2>/dev/null && return 0
  printf 'unstamped %s\n' "$name"
  return 1
}

# ---- Lane declarations (plugins/<name>/lane.tsv) -----------------------------
#
# THE FORMAT, mirrored in every shipped lane.tsv header. Six TAB-separated
# fields, one row per artifact:
#
#   artifact  kind  phase  owns  definite_trigger  yields_to
#
#   artifact          <plugin>:<name> — taskmaster:task, code-review:code-reviewer
#   kind              command | hook | agent | skill
#   phase             understand|shape|decide|plan|build|verify|review|ship|any
#   owns              the territory noun (requirements-clarification, ...)
#   definite_trigger  a checkable condition, not prose
#   yields_to         comma-list of artifacts that outrank this one, or `-`
#
# Lines starting with `#` are comments. One comment shape is read by the gates:
#   # lane-cofire-ok: <artifact-a> <artifact-b>
# blesses one PAIR that shares a territory. It may sit in EITHER participant's
# file — pc_lanes_territory collects every blessing from every file before it
# evaluates anything, so neither side of a cross-plugin pair is privileged.
#
# `yields_to` IS TERRITORY-SCOPED: it names artifacts that outrank this one ON
# THEIR OWN `owns`, which is why a mutual pair between two DIFFERENT territories
# is coherent rather than a cycle — devops owns infra-layer wiring and yields
# in-code instrumentation to observability, which yields infra wiring back. Both
# statements ship in those plugins' descriptions today; the columns record them
# without inventing a winner neither plugin claims.
#
# WHY PER-PLUGIN AND NOT A CENTRAL REGISTRY. skill-router ships in 5 of 10
# bundles, so a registry under it would leave five bundles' artifacts with no
# lane at runtime. Collision detection needs every claim visible at once and
# runs HERE, at author time, over the repo — where every plugin is present
# regardless of what any user installed. Turn-taking needs only the artifact's
# OWN lane and reads `${CLAUDE_PLUGIN_ROOT}/lane.tsv` at runtime. Separating the
# two jobs is what removes the partial-install failure.
#
# LIMITATION (honest scope), shared by all five functions below: these gate what
# a plugin DECLARES, never what it does. Nothing here proves an agent confines
# itself to its `owns`, that a `definite_trigger` describes the code that fires,
# or that a `yields_to` edge is honoured at runtime — those stay agent-graded.
# What the gates convert is "two artifacts silently claim one job and nobody
# finds out" into "two artifacts claim one job and the build says so".

# _pc_lane_rows <lane_tsv>
# Emits "artifact<TAB>kind" for each well-formed data row. Private helper.
_pc_lane_rows() {
  [ -f "$1" ] || return 0
  awk -F'\t' '{ sub(/\r$/, "") } /^#/ { next } NF==6 { print $1 "\t" $2 }' "$1"
}

# _pc_lane_resolves <plugins_root> <plugin:name> <kind|any>
# True when the token names a real artifact of the declared kind. Private helper.
_pc_lane_resolves() {
  local root="$1" tok="$2" kind="${3:-any}" p n
  case "$tok" in *:*) ;; *) return 1 ;; esac
  p="${tok%%:*}"; n="${tok##*:}"
  [ -n "$p" ] && [ -n "$n" ] || return 1
  case "$kind" in
    agent)   [ -f "$root/$p/agents/$n.md" ] ;;
    command) [ -f "$root/$p/commands/$n.md" ] ;;
    skill)   [ -f "$root/$p/skills/$n/SKILL.md" ] ;;
    hook)    [ -f "$root/$p/hooks/$n.sh" ] ;;
    *)       [ -f "$root/$p/agents/$n.md" ] || [ -f "$root/$p/commands/$n.md" ] \
             || [ -f "$root/$p/skills/$n/SKILL.md" ] || [ -f "$root/$p/hooks/$n.sh" ] ;;
  esac
}

# pc_lanes_schema <lane_tsv>
# Prints one `lane-schema <file>:<line> <reason>` per malformed row and returns
# 1; clean or missing file returns 0. Four reasons: a row without exactly 6
# tab-separated fields, an unknown `kind`, an unknown `phase`, and a duplicate
# artifact+owns pair within one file (the same artifact claiming one territory
# twice is a merge artifact, not a declaration).
pc_lanes_schema() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk -F'\t' -v file="$f" '
    { sub(/\r$/, "") }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    {
      if (NF != 6) {
        printf "lane-schema %s:%d %d fields (want 6)\n", file, FNR, NF; bad=1; next
      }
      if ($2 !~ /^(command|hook|agent|skill)$/) {
        printf "lane-schema %s:%d unknown kind %s\n", file, FNR, $2; bad=1
      }
      if ($3 !~ /^(understand|shape|decide|plan|build|verify|review|ship|any)$/) {
        printf "lane-schema %s:%d unknown phase %s\n", file, FNR, $3; bad=1
      }
      k = $1 SUBSEP $4
      if (k in seen) {
        printf "lane-schema %s:%d duplicate artifact+owns %s %s\n", file, FNR, $1, $4; bad=1
      }
      seen[k] = 1
    }
    END { exit bad+0 }' "$f"
}

# pc_lanes_authority <lane_tsv>
# A plugin may declare only its OWN artifacts. Prints one
# `lane-authority <file>:<line> <artifact> not owned by <plugin>` per violation
# and returns 1; clean or missing file returns 0.
#
# WHY IT EXISTS. Per-plugin files opened an authority hole the central-registry
# design did not have: nothing otherwise stopped plugins/foo/lane.tsv from
# declaring bar:baz's territory, or from writing bar a `yields_to` edge that
# makes bar stand down in foo's favour. The plugin directory name is the
# authority, so a row whose artifact is malformed (no `plugin:name` shape) is
# not owned by anyone and fails here too. Blessings are comments and are
# deliberately NOT checked: a blessing names two parties by design, and
# requiring it to sit in one specific file would privilege one side.
pc_lanes_authority() {
  local f="$1" plug
  [ -f "$f" ] || return 0
  plug=$(basename "$(dirname "$f")")
  awk -F'\t' -v file="$f" -v plug="$plug" '
    { sub(/\r$/, "") }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    NF != 6 { next }
    {
      lhs = $1; sub(/:.*$/, "", lhs)
      if ($1 !~ /^[a-z0-9-]+:[a-z0-9._-]+$/ || lhs != plug) {
        printf "lane-authority %s:%d %s not owned by %s\n", file, FNR, $1, plug; bad=1
      }
    }
    END { exit bad+0 }' "$f"
}

# pc_lanes_resolve <lane_tsv> [plugins_root]
# Every declared artifact must exist as its declared kind, and every `yields_to`
# token must name a real artifact of some kind. Prints one
# `lane-resolve <file>:<line> …` per dangling reference and returns 1.
#
# A lane row is the only place in this marketplace where one plugin names
# another as its better on a shared territory; a name that resolves to nothing
# is a deference to an artifact that cannot arrive, and it fails silently at
# runtime exactly the way a bad handoff does (pc_handoff_refs, same class,
# different file type — that one reads prose and cannot see a .tsv).
pc_lanes_resolve() {
  local f="$1" root="${2:-plugins}" bad=0 lineno=0 art kind ph owns trig yields tok
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r art kind ph owns trig yields || [ -n "$art" ]; do
    lineno=$((lineno + 1))
    case "$art" in '#'*|'') continue ;; esac
    _pc_lane_resolves "$root" "$art" "$kind" \
      || { printf 'lane-resolve %s:%d %s names no %s in the tree\n' "$f" "$lineno" "$art" "$kind"; bad=1; }
    case "$yields" in ''|'-') continue ;; esac
    for tok in $(printf '%s' "$yields" | tr ',' ' '); do
      _pc_lane_resolves "$root" "$tok" any \
        || { printf 'lane-resolve %s:%d yields_to %s resolves to nothing\n' "$f" "$lineno" "$tok"; bad=1; }
    done
  done < "$f"
  return $bad
}

# pc_lanes_territory <lane_tsv> [lane_tsv …]
# THE GATE THAT CARRIES THE MISSION. Two artifacts must not silently claim the
# same job: any two rows sharing `owns` + `phase` fail unless one names the
# other in `yields_to`, or a `# lane-cofire-ok:` blessing names both. Prints one
# `lane-territory <owns> <phase> <artifact-a> <artifact-b>` per unresolved pair
# and returns 1.
#
# ALL FILES AT ONCE, deliberately. The collisions that matter are cross-plugin —
# 8 reviewer-class agents in 8 different plugins collide on ROLE while their
# filenames are distinct, so every other gate in this repo sees eight unrelated
# files. Same-file pairs are checked too: a plugin's own worker and reviewer
# claiming one territory is the same defect at shorter range.
#
# Blessings are collected from every file BEFORE any pair is evaluated, so
# either participant may carry it and neither side is privileged.
pc_lanes_territory() {
  local f had=0
  for f in "$@"; do [ -f "$f" ] && had=1; done
  [ "$had" -eq 1 ] || return 0
  awk -F'\t' '
    function yields(list, target,   m, parts, k) {
      if (list == "" || list == "-") return 0
      m = split(list, parts, ",")
      for (k = 1; k <= m; k++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[k])
        if (parts[k] == target) return 1
      }
      return 0
    }
    { sub(/\r$/, "") }
    /^#[[:space:]]*lane-cofire-ok:/ {
      line = $0
      sub(/^#[[:space:]]*lane-cofire-ok:[[:space:]]*/, "", line)
      n = split(line, t, /[[:space:]]+/)
      if (n >= 2) { ok[t[1] SUBSEP t[2]] = 1; ok[t[2] SUBSEP t[1]] = 1 }
      next
    }
    /^#/ { next }
    NF != 6 { next }
    { i = ++cnt; A[i] = $1; PH[i] = $3; OW[i] = $4; Y[i] = $6 }
    END {
      bad = 0
      for (i = 1; i <= cnt; i++)
        for (j = i + 1; j <= cnt; j++) {
          if (OW[i] != OW[j] || PH[i] != PH[j]) continue
          if (A[i] == A[j]) continue
          if (yields(Y[i], A[j]) || yields(Y[j], A[i])) continue
          if (ok[A[i] SUBSEP A[j]]) continue
          printf "lane-territory %s %s %s %s\n", OW[i], PH[i], A[i], A[j]
          bad = 1
        }
      exit bad
    }' "$@"
}

# pc_lanes_coverage [plugins_root]
# Every agent, and every UserPromptSubmit/Stop hook script, must carry a row in
# its own plugin's lane.tsv — those are the GATE tier. Commands and skills are
# WARN this run. Prints `lane-missing agent|hook <plugin>:<name>` (gate) and
# `lane-warn command|skill <plugin>:<name>` (advisory), and returns 1 only when
# something at gate tier is missing.
#
# WHY THOSE TWO ARE THE TEETH. Agents are the surface where ownership is
# contested by the MODEL rather than by a script: 8 of the 32 are reviewer-class
# with distinct filenames, and the model picks between them from descriptions
# alone. Prompt-channel and Stop hooks are the surface where two plugins speak
# on one turn and the winner is decided by scheduling order. Gating all 99
# commands instead would have forced ~66 version bumps in one change for rows
# nothing yet arbitrates.
#
# LIMITATION (honest scope), three residuals:
#   1. The hook half reads hooks.json with jq and understands one command shape,
#      `${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh`. A hook invoked any other way is
#      not counted — it draws no failure and no warning.
#   2. Coverage is existence, not agreement: a row may name the wrong phase or a
#      territory the agent does not work in, and this passes.
#   3. A scratch agent planted by another harness (role-floors-check.sh writes
#      three) is a real agent file with no row, so it draws a lane-missing line
#      during that harness's runs. Those harnesses assert by string presence and
#      never on exit code, so it costs nothing — but a future harness that
#      asserts "no FAILs" would trip on it.
pc_lanes_coverage() {
  local root="${1:-plugins}" bad=0 d p lane rows a n hj cmd TAB NL
  TAB=$(printf '\t'); NL='
'
  # find, not a glob, for the same reason pc_version_stamp uses it: an unmatched
  # glob is a literal path under bash and a hard error under zsh, and this file
  # is sourced by validate.sh and by a hook.
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p=$(basename "$d")
    lane="$d/lane.tsv"
    rows=$(_pc_lane_rows "$lane")
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$a" .md)
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}agent$NL"*) ;;
        *) printf 'lane-missing agent %s:%s\n' "$p" "$n"; bad=1 ;;
      esac
    done < <(find "$d/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
    hj="$d/hooks/hooks.json"
    if [ -f "$hj" ] && command -v jq >/dev/null 2>&1; then
      while IFS= read -r cmd; do
        case "$cmd" in '${CLAUDE_PLUGIN_ROOT}/hooks/'*.sh) ;; *) continue ;; esac
        n=$(basename "$cmd" .sh)
        case "$NL$rows$NL" in
          *"$NL$p:$n${TAB}hook$NL"*) ;;
          *) printf 'lane-missing hook %s:%s\n' "$p" "$n"; bad=1 ;;
        esac
      done < <(jq -r '.hooks | to_entries[]
                      | select(.key=="UserPromptSubmit" or .key=="Stop")
                      | .value[].hooks[].command // empty' "$hj" 2>/dev/null | sort -u)
    fi
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$a" .md)
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}command$NL"*) ;;
        *) printf 'lane-warn command %s:%s\n' "$p" "$n" ;;
      esac
    done < <(find "$d/commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$(dirname "$a")")
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}skill$NL"*) ;;
        *) printf 'lane-warn skill %s:%s\n' "$p" "$n" ;;
      esac
    done < <(find "$d/skills" -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null | sort)
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  return $bad
}

# pc_dispatch_binding <md_path> [plugins_root]
# A shipped `agent(<args>)` code sample that spawns an agent this marketplace ships
# must name it with `agentType`. Prints one `dispatch <path> <agent>` line per
# unbound reference and returns 1; clean returns 0.
#
# WHY THIS EXISTS. `Workflow`'s `agent()` spawns the GENERIC workflow subagent unless
# `agentType` is passed. A recipe that says "spawn one `researcher` per facet" in prose
# and then shows `agent(researcherPrompt(facet), {schema, phase})` in its code block
# dispatches something else entirely: the prompt arrives, the agent's own system prompt
# does not, and the transcript is indistinguishable from a run that bound it correctly.
# The word `agentType` appeared ZERO times across every plugin in this marketplace when
# this check was written, while ~10 plugins ship agents and several fan out through
# `Workflow` — so every one of those agent contracts was decorative on that path. The
# cost is not theoretical: a 30-card run fanned out with no `agentType`, and
# `task-executor`'s "match the surrounding file's comment density" never reached a
# single writing agent (see task-execution/references/routing.md step 5).
#
# TWO STRUCTURAL GUARDS, so there is no exclusion list to maintain:
#   1. A REAL CALL, not an API mention. `agent(` must be followed by something other
#      than `)`. `dispatch-tiers.md` discusses "the `Workflow` `agent()` path" as a tier
#      concept and names two agents in a table; it is documentation about dispatch, not
#      a dispatch, and empty parens are exactly what tells the two apart.
#   2. The referenced agent must RESOLVE — `<root>/<plugin>/agents/<name>.md` must
#      exist. A bare backticked token counts only against the file's OWN plugin, so a
#      common word (`verifier`, `researcher`) cannot match some other plugin's agent by
#      accident; cross-plugin references use the `plugin:agent` form and are resolved
#      against it directly.
#
# LIMITATION (honest scope — the four laws). CODE SAMPLES ONLY. It cannot read a prose
# instruction ("dispatch the resolved worker") and confirm an orchestrator obeyed it at
# runtime, and it cannot see a `Workflow` script the model composes on the fly — which is
# how the original failure actually happened. It gates the recipes this marketplace
# SHIPS, which is the part a repo can hold; the runtime half stays `agent-graded` and the
# run-report line in routing.md step 5 is what makes it visible after the fact.
#
# BOUNDARY. `orchestration/scripts/dispatch-lint.sh` checks the CONTENT of a drafted
# prompt (absolute path, scope lock, return shape, closing data instruction). This checks
# WHICH AGENT the call binds. A prompt can pass all four of those elements and still be
# handed to the wrong agent — that is the gap here, and nothing else looks at it.
#
# Mark a sample that deliberately wants the generic subagent with <!-- dispatch-ok -->.
pc_dispatch_binding() {
  local f="$1" root="${2:-plugins}" bad=0 plug a n tok lhs rhs
  [ -f "$f" ] || return 0
  grep -qE 'agent\([^)]' "$f" || return 0          # guard 1: a call, not a mention
  grep -qF '<!-- dispatch-ok -->' "$f" && return 0
  grep -qF 'agentType' "$f" && return 0

  plug=${f#"$root"/}; plug=${plug%%/*}
  if [ -d "$root/$plug/agents" ]; then
    for a in "$root/$plug/agents"/*.md; do
      [ -f "$a" ] || continue
      n=$(basename "$a" .md)
      grep -qE "\`$n\`|\`$plug:$n\`|\[$plug:$n\]" "$f" || continue
      printf 'dispatch %s %s\n' "$f" "$plug:$n"; bad=1
    done
  fi
  for tok in $(grep -oE '`[a-z0-9-]+:[a-z0-9-]+`|\[[a-z0-9-]+:[a-z0-9-]+\]' "$f" 2>/dev/null \
                 | tr -d '`[]' | sort -u); do
    lhs=${tok%%:*}; rhs=${tok#*:}
    [ "$lhs" = "$plug" ] && continue              # already covered by the own-plugin pass
    [ -f "$root/$lhs/agents/$rhs.md" ] || continue
    printf 'dispatch %s %s\n' "$f" "$tok"; bad=1
  done
  return $bad
}

# pc_phase_guard <plugins-root> — spec §4.3, C4.
# A script wired to UserPromptSubmit or Stop must READ the phase sentinel, or it
# cannot take turns: it speaks in every phase forever, which is the defect the
# sentinel exists to fix (taskmaster's "before the first code edit" directive
# firing on turn 40 of a registered execution run).
#
# Scope is per SCRIPT, not per plugin. An earlier cut keyed on "this plugin has a
# prompt hook somewhere" and flagged 16 scripts, most of them PostToolUse or
# PreToolUse (skill-router:route.sh, taskmaster:preview-guard.sh) with no business
# reading a prompt-phase sentinel. jq walks the two events and resolves only their
# own commands.
#
# HONEST LIMITATION: this proves the sentinel PATH appears in the script. It cannot
# prove the script honours the verdict on every branch — a hook could read it and
# ignore it. Gate on the read; the behaviour half is agent-graded. Claiming
# otherwise would be the tier over-claim CLAUDE.md's has-teeth convention forbids.
#
# Prints `phase-unguarded <plugin>:<script>` per offender; returns 1 if any.
pc_phase_guard() {
  local root="${1:-plugins}" bad=0 hj d p sh rel lane_phase
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=${sh//\$\{CLAUDE_PLUGIN_ROOT\}/$d}
      [ -f "$sh" ] || continue
      rel=$(basename "$sh")
      grep -qF 'cc-phase.json' "$sh" 2>/dev/null && continue
      # EXEMPTION, tied to the declaration rather than to a hand-kept list: an
      # artifact whose lane says `any` is a guard, not a phase step, and guards
      # must fire in every phase. The boost hooks (ultra, ultra-craft,
      # ultra-assess) answer an explicit user keyword and terse:mode is an
      # output-shape contract — none of them takes a turn, so demanding a
      # sentinel read would be ceremony that catches nothing. An artifact with no
      # row at all is pc_lanes_coverage's problem, not this gate's.
      lane_phase=$(awk -F'\t' -v a="$p:${rel%.sh}" '$1==a {print $3; exit}' \
                    "$d/lane.tsv" 2>/dev/null)
      [ -z "$lane_phase" ] && continue
      [ "$lane_phase" = any ] && continue
      printf 'phase-unguarded %s:%s\n' "$p" "$rel"
      bad=1
    done <<EOF
$(jq -r '((.hooks.UserPromptSubmit // []) + (.hooks.Stop // []))
         | .[]? | .hooks[]? | select(.type=="command") | .command' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  return $bad
}
