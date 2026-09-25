#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SubagentStart: hand a plugin subagent the Read paths of the skills its own frontmatter
# declares in `bestpractices-skill:`, kept to the ones THIS project's stack uses. One
# `hookSpecificOutput.additionalContext`, a few hundred characters: an instruction line and
# one absolute SKILL.md path per kept skill. The body is NOT injected — the agent Reads it.
#
# WHY. `bestpractices-skill:` is this marketplace's own frontmatter key; Claude Code does
# nothing with it. Only task-runner's dispatcher turns it into Read paths, so an agent
# spawned any other way starts with no rubric. Measured 2026-09-25
# (rationale/2026-09-25-session-plugin-usage-review.md, finding 6): three ad-hoc
# `ui-ux:ui-ux-reviewer` spawns made 95-101 Read/Grep/Glob calls each and read ZERO
# SKILL.md files, while task-runner-dispatched workers in another session read them 156+
# times. The host's `skills:` preload was the other fix and was rejected for these lists:
# it is stack-blind, so frontend-reviewer in a Laravel/Inertia repo would carry the React
# Native and Next.js bodies (~4.4k tokens) on every spawn. Only the stack-independent
# `ui-ux:a11y-audit` is preloaded that way.
#
# THE FILTER is prime.sh's own evidence table (`sr_repo_skills`, sourced from that file so
# the SessionStart index and this hook cannot disagree about what the stack is), read at
# the project root through `cc_state_root` — which prime.sh defines — so a spawn from a
# model `cd`-ed into a subdirectory sees the same stack. A declared skill is kept only when
# a row there finds its evidence AND its owning plugin is installed AND its SKILL.md exists.
# Declared order is kept. A skill the agent already preloads through the host's `skills:`
# key is dropped — its body is in context before this line arrives.
#
# OFF SWITCHES: CC_SUBAGENT_SKILLS=off silences this hook alone; CC_REMIND=off does too.
# SILENT also when: the agent type is not plugin-scoped (`Explore`, `general-purpose`, a
# project agent), its plugin is not in this marketplace's install root or is disabled, the
# definition has no `bestpractices-skill:`, nothing declared matches the stack, or jq is
# missing. No marker file: the host itself re-injects a SubagentStart context only when
# the subagent's context no longer holds the earlier copy (docs, hooks § SubagentStart,
# read 2026-09-25), so a resumed agent does not pay twice.
#
# COST. Every plugin-scoped spawn (the hooks.json matcher keeps built-in agents out) runs
# one jq read, one awk over the agent file and, when a list exists, prime.sh's evidence
# rows: manifest greps plus up to ten `find -maxdepth 3 -print -quit` calls — measured
# 200-265 ms per spawn on two real Laravel/Inertia repos with 282 MB and 422 MB of
# node_modules (2026-09-25). The output is capped at CAP characters, about 600 in practice;
# a path past the cap is dropped whole, never cut mid-path.
# `scripts/context-budget.sh` executes SessionStart, UserPromptSubmit and Pre/PostToolUse
# hooks only, so this channel is NOT metered there.
#
# LIMITATIONS, stated rather than implied:
#   - A declared skill prime.sh has NO evidence row for (motion-best-practices,
#     security-review, performance-tuning, observability-design) is never injected: no
#     manifest can say it applies, and an unconditional Read is the stack-blind cost this
#     hook exists to avoid. Those agents get what their own body text tells them, as before.
#   - The filter inherits prime.sh's misses: a11y-audit is evidenced by a .tsx/.jsx file
#     within three levels of the root, so a11y-engineer in a Vue- or Blade-only repo is
#     told nothing; devops-practices needs `.github/workflows/`; a monorepo whose manifests
#     sit in a workspace below the root reads as having none.
#   - Advisory: additionalContext cannot make the agent Read. Probed ONCE live (CLI
#     2.1.282, haiku, --plugin-dir, a Laravel/Inertia repo): web-dev:frontend-reviewer
#     received exactly the inertia and vite paths, as "SubagentStart hook additional
#     context" in its own transcript, and quoted them back. Whether an agent then READS
#     them on a real task is unmeasured.
#   - "This marketplace" means the plugins root resolved from this hook's own
#     CLAUDE_PLUGIN_ROOT (hooks/plugins-dir.sh). Another marketplace's plugin with the
#     same name as one here is resolved against this one's definition.
{
  CAP=700
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_SUBAGENT_SKILLS:-on}" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  agent=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  case "$agent" in *:*) ;; *) exit 0 ;; esac
  plugin="${agent%%:*}"; name="${agent#*:}"
  # Both halves become path segments below; anything but a plain name is not ours.
  case "$plugin" in ''|*[!a-z0-9._-]*|.*) exit 0 ;; esac
  case "$name" in ''|*[!a-zA-Z0-9._-]*|.*) exit 0 ;; esac
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

  here=$(dirname "$0")
  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$here/plugins-dir.sh" 2>/dev/null || exit 0
  pr_resolve_plugins_dir
  # No root, no path to name: unlike route.sh's fire-if-uncertain, silence is the only
  # honest output here.
  [ -n "$PLUGINS_DIR" ] || exit 0
  pr_plugin_installed "$plugin" || exit 0
  proot=$(pr_plugin_root "$plugin")
  [ -n "$proot" ] || exit 0

  # The host reports the frontmatter `name`, not the filename; they agree across this
  # marketplace today, and the scan covers the day one does not.
  def="$proot/agents/$name.md"
  if [ ! -f "$def" ]; then
    def=""
    for f in "$proot"/agents/*.md; do
      [ -f "$f" ] || continue
      awk -v n="$name" '/^---[[:space:]]*$/{c++; if (c == 2) exit 1; next}
        c == 1 && /^name:/ {v = $0; sub(/^name:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); exit (v == n ? 0 : 1)}
        END {exit 1}' "$f" && { def="$f"; break; }
    done
    [ -n "$def" ] || exit 0
  fi

  # Frontmatter only — the same read validate.sh's stack-authoring guard uses. `skills:`
  # is read inline (`[a, b]` or `a, b`) and as a block list; a plugin prefix is dropped.
  declared=$(awk '/^---[[:space:]]*$/{c++; if (c == 2) exit; next}
    c == 1 && /^bestpractices-skill:/ {sub(/^bestpractices-skill:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit}' "$def" \
    | tr ',' '\n' | grep -v '^$')
  [ -n "$declared" ] || exit 0
  preloaded=$(awk '/^---[[:space:]]*$/{c++; if (c == 2) exit; next}
    c != 1 {next}
    /^skills:/ {v = $0; sub(/^skills:[[:space:]]*/, "", v); gsub(/[][[:space:]"\047]/, "", v)
      if (v != "") {print v; blk = 0} else blk = 1; next}
    blk && /^[[:space:]]*-/ {v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); gsub(/[[:space:]"\047]/, "", v); print v; next}
    {blk = 0}' "$def" | tr ',' '\n' | sed 's/.*://' | grep -v '^$')

  . "$here/prime.sh" 2>/dev/null || exit 0
  command -v sr_repo_skills >/dev/null 2>&1 && command -v cc_state_root >/dev/null 2>&1 || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  evidence=""
  add() { evidence="${evidence}$1"$'\t'"$2"$'\n'; } # $1 skill, $2 owning_plugin
  sr_repo_skills "$root"
  [ -n "$evidence" ] || exit 0

  msg="[skill-router] Stack skills for this repo from your bestpractices-skill list. Read these before working; a path the dispatcher already gave you needs no second Read:"
  kept=0
  while IFS= read -r sk; do
    printf '%s\n' "$preloaded" | grep -qxF -- "$sk" && continue
    owner=$(printf '%s' "$evidence" | awk -F'\t' -v s="$sk" '$1 == s {print $2; exit}')
    [ -n "$owner" ] || continue
    pr_plugin_installed "$owner" || continue
    oroot=$(pr_plugin_root "$owner")
    [ -n "$oroot" ] && [ -f "$oroot/skills/$sk/SKILL.md" ] || continue
    line=$'\n'"$oroot/skills/$sk/SKILL.md"
    case "$msg" in *"$line"*) continue ;; esac
    [ $(( ${#msg} + ${#line} )) -le "$CAP" ] || break
    msg="$msg$line"; kept=$((kept + 1))
  done <<EOF
$declared
EOF
  [ "$kept" -gt 0 ] || exit 0
  jq -cn --arg m "$msg" '{hookSpecificOutput:{hookEventName:"SubagentStart",additionalContext:$m}}'
} 2>/dev/null
exit 0
