#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
#
# UserPromptSubmit tool-fit check. This hook does NOT decide which command fits —
# it hands the model the catalog of installed commands and the rules for judging.
# A previous version matched prompt patterns to commands in a table; a table only
# ever routes the phrasings its author thought of, and every new plugin needed a
# new row. The judgment belongs to the model, which reads meaning; the hook's job
# is to make sure the model has the list and the discipline to use it.
#
# The catalog is built at runtime from the SIBLING plugins' commands/*.md
# frontmatter, so it reflects what is actually installed — nothing generated,
# nothing to drift, and no row naming a command the user does not have.
#
# Fires once per session, on the first work-shaped prompt: a chat-only session
# pays nothing, and once injected the catalog stays in context for later prompts.
# Fail-open: any error, or a missing jq, exits silently and never blocks.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "") exit 0 ;; esac

  # OFF SWITCHES. CC_REMIND=off silences every advisory nudge in the marketplace
  # (this is one); CC_ROUTE=off silences only this check. Environment is the one
  # state independently-installed plugins genuinely share.
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_ROUTE:-on}" in off) exit 0 ;; esac

  # ---- pending-signal flush. Low-confidence signals route.sh accumulated are
  # surfaced on the NEXT prompt — a channel the model receives in time to act —
  # instead of only at SessionEnd, an event after which no model turn exists.
  # Each entry surfaces once (marked flushed in the state file); summary.sh's
  # SessionEnd ledger still records everything. Runs before every later exit —
  # slash-command prompts included (a /task-runner:run session must still see a
  # pending security signal), and "looks good, continue" is exactly the prompt
  # where one must not stay buried. Honest limitation: if the state file is
  # unwritable the flushed flag cannot persist and entries re-surface next
  # prompt — fail-open toward repetition, never toward losing a signal.
  sid_f=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  cwd_f=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -n "$sid_f" ] && [ -n "$cwd_f" ] && [ -r "$cwd_f/.claude/skill-router/fired-$sid_f.json" ]; then
    state_f="$cwd_f/.claude/skill-router/fired-$sid_f.json"
    digest=$(jq -r '
      [ (.pending_low // [])[] | select(.flushed != true) ]
      | group_by(.skill)
      | map(.[0].skill + " (" + ([.[].file | split("/") | last] | unique | join(", ")) + ")")
      | join("; ")
    ' "$state_f" 2>/dev/null)
    if [ -n "$digest" ]; then
      printf '[skill-router] Signals from recent edits — judge each in one line before continuing, load the skill only if it applies: %s.\n' "$digest"
      upd=$(jq '(.pending_low // []) |= map(.flushed = true)' "$state_f" 2>/dev/null) \
        && [ -n "$upd" ] && printf '%s\n' "$upd" > "$state_f" 2>/dev/null
    fi
  fi

  # Slash commands manage their own flow — but only AFTER the flush above ran.
  case "$prompt" in "/"*) exit 0 ;; esac

  # TRIGGER NARROWING, identical in shape to the reminder hooks': drop fenced and
  # backticked spans, read only the head, refuse prompts ABOUT this machinery, and
  # refuse this hook's own output echoed back. LIMITATION (honest scope): heuristic,
  # not parsing — CC_ROUTE=off is the reliable control, this is the cheap one.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit' && exit 0
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix|update|change|write|rewrite|edit)[a-z -]{0,40}(plugin|hook|reminder|router|route|trigger|catalog)' && exit 0
  printf '%s' "$head" | grep -qF '[skill-router]' && exit 0

  # WORK-SHAPED GATE. The one pattern left, and deliberately not a routing table:
  # it asks "is this a request to do work?", never "which tool". Everything about
  # WHICH is the model's, downstream. A miss here costs a check, not a wrong route.
  #
  # ONE grep, three tiers: validate.sh budgets four prompt-matching greps here and
  # calls a fifth a routing table regrowing in shell, so the tiers are alternations
  # inside this pattern rather than lines of their own.
  #
  #   MAKING VERBS — build, refactor, deploy … : match bare. Unchanged.
  #   STRONG symptom — error, crash, 500s, regressed, why is, investigate, not
  #     working: match bare. A prompt carrying one of these is about a defect
  #     whatever the surrounding grammar.
  #   WEAK symptom — down, slow, broken, failing, fails, leak, stuck: match ONLY
  #     after a state verb (is/are/went/keeps/got/…), with at most one word
  #     between. These are ordinary English before they are incident vocabulary.
  #
  # WHY THE WEAK TIER IS BOUND AND THE STRONG ONE IS NOT. Symptom phrasing was
  # added because `production is down` and `why is the checkout page broken`
  # reached this gate and were dropped, while `fix …` sailed through — an incident
  # is reported by its effect, not by a verb, so the one moment where tool choice
  # matters most was the moment the catalog never reached. But bare `down` also
  # matches `scroll down and tell me what you see`, and bare `slow` matches `the
  # meeting ran slow today`. Each false positive injects the ~2.6k-token catalog
  # into a session that would otherwise pay nothing, and no gate can see it:
  # context-budget.sh measures one fixed making-verb prompt in an empty sandbox,
  # so this cost is real and structurally unmeasurable. The state verb is what
  # separates a system in a bad state from an ordinary sentence. Bound pattern:
  # taskmaster/hooks/preview-guard.sh, whose weak .html tier is bounded for the
  # same reason — a weak signal that never clears is noise wearing a gate's name.
  #
  # HONEST LIMITATION. The bound is grammatical, not semantic. A symptom phrased
  # without a state verb — `payment failures spiking`, `memory leak in the worker`
  # — is missed, and a chat sentence that happens to carry one (`the build is slow
  # to watch`) still fires. It trades recall on the weak tier for the silence of
  # the plain-prompt path, which §1 calls the overwhelming case; the STRONG tier
  # is what carries recall, and it is unbounded. A miss here costs a check, never
  # a wrong route.
  printf '%s' "$head" | grep -qiE '\b(build|create|make|add|implement|develop|write|rewrite|refactor|migrate|port|fix|debug|review|audit|design|redesign|restyle|theme|style|test|deploy|ship|optimi[sz]e|speed up|scaffold|set ?up|plan|spec|integrate|automate|error|errors|crash|crashing|500s?|regress(ed|ion)?|not working|why is|investigate)\b|\b(is|are|was|were|been|went|going|get(s|ting)?|got|keeps?|kept|still|now|seems?|looks?|am)\b[[:space:]]+([a-z]+[[:space:]]+)?\b(down|slow(er)?|broken|failing|fails|leak(s|ing)?|stuck)\b' || exit 0

  # ONCE PER SESSION. The catalog stays in context after the first injection, so a
  # second copy buys nothing and costs the same tokens again.
  sid=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-route-catalog-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  mkdir "$seen" 2>/dev/null || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-route-catalog-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  # ---- catalog: every installed plugin's commands, one line each ---------------
  # Only the sibling plugins directory is read, so an uninstalled plugin cannot
  # appear. The description is the command's own frontmatter, already length-linted
  # by scripts/validate.sh; the first clause is the part that says what it is FOR.
  #
  # `pr_plugin_roots` yields one content root per plugin under either layout — see
  # hooks/plugins-dir.sh. The previous `"$plugins_dir"/*/commands/*.md` glob was
  # one level short on a versioned cache and matched nothing, so this hook printed
  # no catalog at all on a real install.
  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 || exit 0
  pr_resolve_plugins_dir
  [ -n "$PLUGINS_DIR" ] || exit 0

  # ---- stack relevance (spec 4.6) ---------------------------------------------
  # The catalog used to list every installed plugin's commands, filtered only by
  # installed-ness, so a Laravel repo was offered /nextjs:review. A command whose
  # stack is demonstrably absent is noise at the exact surface where the model
  # picks a tool, and it is the largest line item in this hook's output.
  #
  # PREDICATE: drop a plugin's commands only when it OWNS rules.tsv rows AND none
  # of them can match anything in this repo. Two corrections the design needed:
  #   * NOT the stack_marker column. It is populated on 15 of 67 data rows and is
  #     absent on exactly nextjs, nuxt, vite and threejs — the plugins the filter
  #     is FOR. A stack_marker predicate would silently do nothing for them.
  #   * NOT glob rows alone. Seven plugins ship ONLY content rows (llm-app,
  #     node-backend, observability, payments, resilience, security, threejs), so a
  #     glob-only predicate matches nothing for them in ANY repo and would delete
  #     /security:review from every repository on earth. A plugin with no rows, or
  #     with no glob rows, is stack-NEUTRAL and always kept.
  #
  # Cost: bounded by the once-per-session marker claimed above — this walk runs at
  # most once per session, never per prompt. Fail open: any error keeps the row.
  RULES="$(dirname "$0")/../rules.tsv"
  # SCOPE. This filter may drop a stack review command and nothing else. rules.tsv globs
  # were authored to route a SKILL to files that already exist, so reusing them as a
  # relevance test for EVERY command was a category error: it hid the commands whose whole
  # job is to create the thing the glob looks for. Measured on a Laravel repo, the earlier
  # form hid dev-env init from any repo without a Dockerfile, craft-layer craft from every
  # greenfield repo, and the a11y audit from anything without a .tsx at depth four, since
  # a11y ships one glob row and it is .tsx alone. The original motivation was narrow: a
  # Laravel repo should not be offered the nextjs review, so the filter is narrow now.
  #
  # PRUNED AND MEMOISED. Unpruned walks measured 2.86s at 4515 entries and 20.26s at 35014,
  # linear, and a real node_modules is often past 100k. That is dead air on the first
  # work-shaped prompt of a session. Worse, the once-per-session marker is claimed about 65
  # lines above this point, so a hook killed on timeout leaves the marker behind and the
  # catalog never prints again for that session. Pruning the vendor trees bounds the walk
  # and the per-plugin memo stops the same answer being recomputed for every row.
  SR_SEEN=""
  sr_find() {
    find "$cwd_f" \( -name node_modules -o -name vendor -o -name .git -o -name dist \) -prune \
      -o -maxdepth 4 "$@" -print -quit 2>/dev/null
  }
  sr_repo_has() {
    [ -r "$RULES" ] || return 0
    [ -n "$cwd_f" ] || return 0
    case " $SR_SEEN " in *" keep:$1 "*) return 0 ;; *" drop:$1 "*) return 1 ;; esac
    local pat kind owner hit=1 globs=0 mid
    while IFS=$'\t' read -r kind pat _skill owner _conf _mark; do
      case "$kind" in '#'*|'') continue ;; esac
      [ "$owner" = "$1" ] || continue
      case "$kind" in
          # Only a FILE-shaped glob can justify HIDING a review; a directory-shaped one cannot.
          # A directory row marks something the repo has already ADOPTED. i18n ships only
          # lang and locales rows, testing only tests, database only migrations, so treating a
          # miss there as absence-of-stack hid the review from exactly the repo that needed it:
          # the i18n review finds hardcoded strings, and a repo with no lang directory is the
          # one that has the most of them. A file row such as a blade template or a next config
          # marks the stack's own sources, which is the question this filter actually asks. A
          # directory row still counts as a HIT when it matches, since that is evidence the
          # stack is present; it simply never votes for absence.
        glob)
          case "$pat" in
            '**/'*'/**')
              mid=${pat#**/}; mid=${mid%/**}
              [ -n "$(sr_find -type d -name "$mid")" ] && hit=0
              ;;
            *)
              globs=1
              [ -n "$(sr_find -name "$pat")" ] && hit=0
              ;;
          esac
          ;;
      esac
      [ "$hit" = 0 ] && break
    done < "$RULES"
    [ "$globs" = 0 ] && hit=0
    if [ "$hit" = 0 ]; then SR_SEEN="$SR_SEEN keep:$1"; else SR_SEEN="$SR_SEEN drop:$1"; fi
    return $hit
  }

  catalog=$(
    pr_plugin_roots | while IFS=$'\t' read -r plug proot; do
      for cmd in "$proot"/commands/*.md; do
        [ -f "$cmd" ] || continue
        name=$(basename "$cmd" .md)
        # A command that creates or audits is most needed where its artifact does not
        # exist yet, so only a stack review is ever filtered on repo evidence.
        [ "$name" = review ] && ! sr_repo_has "$plug" && continue
        desc=$(awk '
        /^---[[:space:]]*$/ { f++; next }
        f==1 && /^description:/ {
          sub(/^description:[[:space:]]*/, "")
          gsub(/^["'"'"']|["'"'"']$/, "")
          split($0, a, / — |\. |: /)
          d = a[1]
          # Trim to a word boundary: a description cut mid-word reads as corruption
          # and costs the same tokens as one that stops cleanly.
          if (length(d) > 85) { d = substr(d, 1, 85); sub(/[[:space:]][^[:space:]]*$/, "", d); d = d "…" }
          print d
          exit
        }
        f>=2 { exit }' "$cmd" 2>/dev/null)
        [ -n "$desc" ] || continue
        printf -- '- /%s:%s — %s\n' "$plug" "$name" "$desc"
      done
    done
  )
  [ -n "$catalog" ] || exit 0

  cat <<CATALOG
[skill-router] Tool-fit check (once this session). Commands installed here, and what each is for:

$catalog

Apply this to work requests for the rest of the session:

1. Judge which listed command best fits the ASK — its substance, not its wording. Most
   requests fit none of them. Silence is the default and the common case.
2. If the user NAMED a tool (a command, a plugin, a pipeline) and a listed command
   clearly fits the ask better, do NOT silently switch and do NOT silently comply.
   Ask via AskUserQuestion, exactly two options:
     "Proceed with <better-command> (Recommended)" / "Proceed with <what-they-named> as asked"
   Give one line of why the other fits — the deliverable's shape, not a preference.
3. If no tool was named and one clearly fits, name it in one line and carry on. No picker.
   Exception: when a scope-first reminder fired on the same prompt, satisfy it before
   carrying on — scoping the work outranks tool-fit. Which reminder that is varies by
   phase and rank, not by plugin: it may be the clarifying-round directive, a
   build-vs-buy check, a docs check, or a stuck-loop nudge. Obey whichever one spoke.
4. Close call, or the named tool IS the best fit: say nothing at all. A tool being
   listed is not a reason to route to it; over-suggesting is the failure mode here.
5. At most one picker per named tool per session. Declining is durable — a user who
   kept their choice is not asked about that tool again.
6. Under a hands-off boost (an ultra-goal run, or a Goal: marker in the card index),
   auto-take the Recommended route instead of asking, and record it in the goal ledger
   with the rationale and both options, per the taskmaster ultra skill's Goal rules.
CATALOG
} 2>/dev/null
exit 0
