#!/usr/bin/env bash
# generated from templates/boost-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Inject the boost directive when the prompt asks.
# One hook, two tokens: ultra-task (boost) / ultra-goal (boost + hands-off).
# No suffix grammar — bare tokens only, fixed tier model=auto effort=xhigh
# (auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable).
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  # OFF SWITCH. CC_BOOST=off disables every boost hook in the marketplace;
  # TASKMASTER_BOOST=off disables this one. Environment is the only state three
  # independently-installed plugins genuinely share, so this works cross-plugin
  # even though a co-activation GUARD does not (see the skill's residual note).
  plugin_switch=TASKMASTER_BOOST
  case "${CC_BOOST:-on}${!plugin_switch:-on}" in *off*) exit 0 ;; esac

  # TRIGGER NARROWING. The token used to be grepped from the WHOLE prompt, so a
  # pasted log, a quoted transcript, or the sentence "don't use <token> here"
  # injected the directive — before the model could read the skill's claim that
  # such a mention is inert. Three narrowings, in order:
  #   1. drop fenced code blocks and inline backticked spans (quoted text)
  #   2. only look at the first 200 characters — a real invocation is typed at
  #      the top of the prompt; a pasted log buries the token deep
  #   3. do not fire when the token is negated
  # LIMITATION (honest scope): heuristic, not parsing. It converts "any mention
  # anywhere fires the boost" into "a mention that reads like an invocation
  # fires it". A quotation in the first 200 chars with no negation still fires,
  # and an invocation past 200 chars no longer does — the off switch above is
  # the reliable control, this is the cheap one.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-200)
  printf '%s' "$head" | grep -qiE "(do not|don't|never|without|avoid|not) +[a-z ]{0,12}ultra" && exit 0
  #   4. do not fire on this hook's OWN output echoed back. The injected directive
  #      opens "ULTRA-<X> ACTIVE"; a prompt quoting that is a transcript paste, not
  #      an invocation. Catching the self-echo is worth a line because the commonest
  #      way a boost banner reaches a prompt is a previous run's output.
  #      The boost tokens are ENUMERATED here, not `ultra-?[a-z]+`: the loose form
  #      also matched Claude Code's own vocabulary, so "ultracode active — now
  #      <token> X" (and "ultrathink active, …") silently suppressed the boost the
  #      user had just typed. Regression cases: scripts/smoke/hook-guard-tests.sh.
  #      This list is shared by every boost hook the chassis renders — a new boost
  #      token is added HERE, in the template, or the sibling hooks will not
  #      recognise its banner and will fire on a pasted one.
  printf '%s' "$head" | grep -qiE "ultra-?(task|goal|assess(ment)?|craft) +active" && exit 0
  # The directive is emitted through a quoted heredoc: no expansion, so the
  # manifest text is the wire text — backticks, quotes and $ are all literal.
  if printf '%s' "$head" | grep -qiE '\bultra-?goal\b([^-]|$)'; then
    cat <<'CC_BOOST_DIRECTIVE'
ULTRA-GOAL ACTIVE (model=auto, effort=xhigh) — hands-off Extreme Boost for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md) in Goal mode: full boost contract (reasoning subagents model:auto — session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only; scouts and opinion-lens stay NATIVE), mandatory red-team + coverage, auto-take every recommendation per the skill's Goal rules with every auto-take audited to the goal ledger, stamp 'Goal: true (model=auto, effort=xhigh)' into 00-INDEX.md, never suppress safety halts, print the ⚡ banner first. Fan-out only when the Workflow tool is present; else inline fallback labeled 'inline heuristic pass — single model, uncorroborated'.
CC_BOOST_DIRECTIVE
  elif printf '%s' "$head" | grep -qiE '\bultra-?task\b'; then
    cat <<'CC_BOOST_DIRECTIVE'
ULTRA-TASK ACTIVE (model=auto, effort=xhigh) — Extreme Boost for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md): reasoning subagents (red-team, coverage, card-verify, synthesis) model:auto (session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only), scouts and opinion-lens stay NATIVE, mandatory red-team + coverage, bounded fan-outs whose counts are CEILINGS sized to blast radius (references/dispatch-tiers.md), print the ⚡ banner first, write 'Ultra: true (model=auto, effort=xhigh)' verbatim into the card index. Fan-out only when the Workflow tool is present; else inline fallback labeled 'inline heuristic pass — single model, uncorroborated'.
CC_BOOST_DIRECTIVE
  fi
} 2>/dev/null
exit 0
