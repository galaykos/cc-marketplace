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
  printf '%s' "$head" | grep -qiE '\b(build|create|make|add|implement|develop|write|rewrite|refactor|migrate|port|fix|debug|review|audit|design|redesign|restyle|theme|style|test|deploy|ship|optimi[sz]e|speed up|scaffold|set ?up|plan|spec|integrate|automate)\b' || exit 0

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

  catalog=$(
    pr_plugin_roots | while IFS=$'\t' read -r plug proot; do
      for cmd in "$proot"/commands/*.md; do
        [ -f "$cmd" ] || continue
        name=$(basename "$cmd" .md)
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
   Exception: when a scope-first reminder (e.g. taskmaster's clarifying-round directive)
   fired on the same prompt, satisfy it before carrying on — clarification outranks tool-fit.
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
