#!/usr/bin/env bash
# Fail open: never block the prompt. Inject the craft boost directive when the prompt asks.
# One token: ultra-craft (also ultracraft). No suffix grammar — fixed tier
# model=auto effort=xhigh (auto = session model or opus, whichever is higher on
# haiku<sonnet<opus<fable). Slash prompts exit early: /craft-layer:craft parses the
# token out of its own args, so the hook would double-fire the directive.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  # OFF SWITCH. CC_BOOST=off disables every boost hook in the marketplace;
  # CRAFT_BOOST=off disables this one. Environment is the only state three
  # independently-installed plugins genuinely share, so this works cross-plugin
  # even though a co-activation GUARD does not (see the skill's residual note).
  case "${CC_BOOST:-on}${CRAFT_BOOST:-on}" in *off*) exit 0 ;; esac

  # TRIGGER NARROWING. The token used to be grepped from the WHOLE prompt, so a
  # pasted log, a quoted transcript, or the sentence "don't use ultra-goal here"
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
  printf '%s' "$head" | grep -qiE "ultra-?[a-z]+ +active" && exit 0
  if printf '%s' "$head" | grep -qiE '\bultra-?craft\b'; then
    echo "ULTRA-CRAFT ACTIVE (model=auto, effort=xhigh) — Extreme Boost for this craft run. Apply the craft-layer 'ultra-craft' skill (skills/ultra-craft/SKILL.md): pin the offer contract's Ambition row to \`maximal\` and its Mode row to \`guided\`, stamp \`Boost: ultra-craft\` into the persisted contract, and honor the six bindings. Research is LIVE — fetch every source, six minimum across three lanes, each with URL, fetch date and a why-line per skills/ultra-craft/references/research-mandate.md; recall is a lead labeled unverified, never a backing. Search all three NAMED galleries with a category-scoped query and record each query: land-book.com (shipped page structure), awwwards.com (reach and signature candidates), dribbble.com (visual direction ONLY — a shot is a concept, never evidence a pattern ships). The search floor and the source floor are separate counts; a blocked fetch is recorded as searched-and-blocked, never covered with recall. Persist and ECHO craft/reference-board.md before any token is generated, and let the user confirm or redirect there. Reasoning subagents (creative-director, craft-reviewer) dispatch model:auto — session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only; builders and token generation stay NATIVE. After the audit, red-team the shipped tree against the contract and divergence record, N=3 as a ceiling sized to blast radius; no Workflow tool means ONE inline pass labeled 'inline heuristic pass — single model, uncorroborated'. The panel owes three rules from skills/ultra-craft/references/red-team-contract.md: SWEEP an interactive signature's reachable state space rather than reasoning about representative values and report states-swept/states-violating with a reproducing input; attack the post-audit FIX LIST as its own claim set, because a fix report is a confident self-assessment by the author of the defects; and RENDER the surface and open the image before calling it verified, retrying with an absolute path in an allowed root before concluding capture is unavailable. Every ceiling holds unchanged — reduced-motion, per-tier and cumulative motion budgets, accent contrast, licence and provenance, accessibility. Print the ⚡ banner first with the cost line; where the brief also asks for fast or cheap, ASK which order wins."
  fi
} 2>/dev/null
exit 0
