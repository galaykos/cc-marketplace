#!/usr/bin/env bash
# PreToolUse guard on the Artifact tool.
#
# The failure this exists for: a visual decision gets published as a remote
# artifact instead of served from the local preview server. The skills that
# route to that server (visual-decisions, ui-ux:theme) load by JUDGMENT, so a
# run where they never load never sees their rule — that is exactly how it goes
# wrong. This fires on the tool call instead.
#
# TIERED, because the strong signal is absent in precisely the population that
# needs guarding. An earlier version keyed solely on taskmaster-docs/mockups/
# existing; that directory is only ever created by the flows whose non-loading
# IS the root cause, so the guard was silent exactly when it mattered and noisy
# afterwards (one server start arms it for the life of the checkout).
#
#   STRONG — a per-purpose preview basename, or a path under a mockups docroot,
#            or a mockups docroot present in this project: ask for confirmation.
#   WEAK   — any other .html artifact: emit context, do NOT interrupt.
#   NONE   — not .html (a markdown report is not a mockup): silent.
#
# Fails open on any error: a broken guard degrades to a no-op, never to a
# blocked tool call.
#
# TWIN: plugins/taskmaster/hooks/preview-guard.sh is a byte-identical copy. ui-ux
# ships the theme flow but declares no taskmaster dependency, and bundles like
# frontend-suite install it alone — without its own copy that path would have
# no mechanical guard at all. ${CLAUDE_PLUGIN_ROOT} is per-plugin so the file
# cannot be shared; change one, change both. With BOTH plugins installed the
# guard fires twice on the same call — an extra line in one prompt, which is
# the cheap side of the trade against leaving ui-ux unguarded.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)

  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$path" in
    *.html | *.htm | *.HTML | *.HTM) ;;
    *) exit 0 ;;
  esac

  # .cwd is the session root; $PWD is only this script's cwd, so prefer it.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || cwd="$PWD"

  # Walk UP looking for the docroot. A git worktree or a session started in a
  # subdirectory would otherwise miss it — taskmaster-docs is gitignored, so a
  # worktree never carries one even while the shared server is live.
  docroot=""
  d="$cwd"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/taskmaster-docs/mockups" ]; then docroot="$d/taskmaster-docs/mockups"; break; fi
    d=$(dirname "$d")
  done

  # The artifact itself is the more reliable signal than project state.
  base=${path##*/}
  strong=""
  case "$base" in
    current.html | theme.html | walkthrough.html | diagram.html | api.html) strong=basename ;;
  esac
  case "$path" in
    */taskmaster-docs/mockups/*) strong=path ;;
  esac
  [ -n "$strong" ] || { [ -n "$docroot" ] && strong=docroot; }

  # Never interpolate an unvalidated env value into text shown at a permission
  # decision: jq keeps the JSON well-formed, but a crafted PREVIEW_PORT would
  # still read as prose in the guard's own authoritative voice.
  port="${PREVIEW_PORT:-8123}"
  case "$port" in '' | *[!0-9]*) port=8123 ;; esac

  if [ -n "$strong" ]; then
    jq -cn --arg p "$port" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason:
          ("This looks like a mockup or theme preview. Those belong on the local "
           + "preview server at http://localhost:" + $p + "/ — it carries the viewport "
           + "presets, the version picker, and push-reload that a published page does "
           + "not, and it keeps unreleased design work off a remote host. Publish only "
           + "if the point is sharing with someone who cannot reach this machine.")
      }
    }'
  else
    jq -cn --arg p "$port" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext:
          ("Note: if this HTML is a visual decision (mockup, theme, palette, flow), "
           + "serve it from the local preview server at http://localhost:" + $p + "/ "
           + "instead — see the visual-decisions or ui-ux:theme skill. Publishing is "
           + "for pages someone else has to open.")
      }
    }'
  fi
} 2>/dev/null
exit 0
