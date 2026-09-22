#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
#
# UserPromptSubmit tool-fit check. This hook does NOT decide which command fits —
# it hands the model the rules for judging and points at the command list the HOST
# already put in this session. A previous version matched prompt patterns to
# commands in a table; a table only ever routes the phrasings its author thought
# of, and every new plugin needed a new row. The judgment belongs to the model,
# which reads meaning; the hook's job is the discipline around that judgment.
#
# It used to rebuild the list too — one truncated frontmatter line per installed
# command — which cost ~5.2 kB per session to restate what the model could already
# read, and grew with every plugin. See the block above the heredoc for what that
# removal gave up (the repo-evidence filter went with it).
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
  # CONTEXT KEY — must match route.sh:28-55 exactly, field order included: read
  # `.transcript_path // .session_id`, then hash. Reading the raw `.session_id` here
  # named a file route.sh never writes, so this flush found nothing on every prompt
  # and the whole low-confidence channel was dead. The cksum applies to the fallback
  # branch too, so no payload shape makes the two spellings coincide.
  sid_f=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  cwd_f=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  ctx_f=$(printf '%s' "$sid_f" | cksum 2>/dev/null | cut -d' ' -f1)
  if [ -n "$sid_f" ] && [ -n "$cwd_f" ] && [ -n "$ctx_f" ] && [ -r "$cwd_f/.claude/skill-router/fired-$ctx_f.json" ]; then
    state_f="$cwd_f/.claude/skill-router/fired-$ctx_f.json"
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
  #
  # `.session_id` RAW is correct here and is NOT the pc_context_key defect. That gate
  # exists because a subagent shares its parent's session_id, so a one-shot keyed on it
  # dedups the worker against a nudge only the parent saw — but UserPromptSubmit never
  # fires in a subagent at all (route.sh:23 and testing/hooks/test-shape.sh:90
  # both state PostToolUse is the only channel that reaches one). There is no second context to starve. The flush block at :46 keys on
  # `.transcript_path // .session_id` for a different reason: it READS the state file
  # route.sh writes, so it must spell the key exactly as route.sh does.
  sid=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-route-catalog-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  # FAIL OPEN on an unwritable TMPDIR. `mkdir || exit 0` conflated two causes with
  # opposite correct responses: the marker already exists (fired this session —
  # suppress, the whole point), or TMPDIR is not writable so the marker can never
  # exist (suppressing costs the catalog on EVERY prompt of EVERY session, silently).
  # route.sh:156 states this plugin's doctrine for exactly this case — "an unwritable
  # state dir cannot swallow a nudge the model should have seen" — and delivers before
  # persisting. This is the same rule on the bigger payload. mkdir stays the atomic
  # first attempt; the existence test only runs once it has already failed.
  #
  # `-e`, not `-d`: the first version of this fix tested for a DIRECTORY, so a plain
  # FILE squatting the marker path fell through both branches and the ~9 KB catalog
  # injected on every prompt of the session — a worse failure than the one being
  # fixed. Anything at the path means the marker state is either "fired" or unusable;
  # suppressing is right in both (one lost catalog beats 9 KB per prompt), and the
  # fail-open branch stays reachable only when the path is genuinely vacant, i.e. the
  # parent is unwritable.
  if ! mkdir "$seen" 2>/dev/null; then
    [ -e "$seen" ] && exit 0
  fi
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-route-catalog-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  # ---- the protocol, not a catalog --------------------------------------------
  # This hook used to rebuild every installed plugin's commands as one truncated line
  # each: 61 rows, 5,179 of the 6,892 chars it emitted, a second copy of a listing the
  # host had already sent this session and one row longer per command installed. What
  # the model does NOT have from that listing is the discipline below, which is the
  # whole reason this hook exists; the rows were the part it could already read.
  #
  # LIMITATION (honest scope), and it is a real trade. The host listing is not filtered
  # by repo evidence, so a Laravel repo now sees the Next.js review in it where the
  # built catalog hid that row — the stack-relevance walk went with the rows it filtered.
  # Step 1 below ("most requests fit none of them") is the only thing left holding that
  # down, and it is the model's judgment, not a gate. Nothing here can verify the host
  # actually sent a listing either; if a session has none, step 1 reads as vacuous and
  # the hook is silent rather than wrong.
  cat <<CATALOG
[skill-router] Tool-fit check (once this session). Judge against the slash commands already listed in this session — do not rebuild or ask for that list.

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
