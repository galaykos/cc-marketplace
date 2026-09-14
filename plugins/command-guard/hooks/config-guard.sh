#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PreToolUse guard on the agent's OWN guardrails. Returns `ask` — never a bare deny —
# on a write that would weaken the configuration deciding what the agent may do:
#
#   settings           .claude/settings.json, settings.local.json, ~/.claude/settings.json
#   hooks              any hooks.json, any plugins/*/hooks/*.sh
#   plugin manifests   .claude-plugin/plugin.json, marketplace.json
#   lint/test config   .eslintrc*, eslint.config.*, .rubocop.yml, ruff.toml, phpstan.neon,
#                      psalm.xml, .php-cs-fixer*, tsconfig.json, .golangci.yml, pytest.ini,
#                      setup.cfg, .flake8, biome.json, clippy.toml
#
# WHY. Given a gate it cannot satisfy, the cheapest path out is to edit the gate — turn
# off the rule, lower `strict`, add the file to an ignore list, delete the hook. It is
# not malice, it is gradient descent, and it is invisible in a diff summary that reads
# "updated config". Prose cannot reach it: the model is not violating an instruction it
# remembers, it is solving the problem in front of it. A guard that fires at the moment
# of the write is the only thing that turns the move into a decision the user makes.
# (`karanb192/claude-code-hooks`'s `config-guard` is prior art and cites CVE-2026-25725;
# this one is narrower — ask, not deny — because a legitimate config edit is common.)
#
# WHY `ask` AND NOT `deny`. Editing these files is often exactly the task ("add a
# permission", "wire a hook", "bump the plugin version"). A deny would be wrong most of
# the time it fired. An ask costs one keystroke on a legitimate edit and is the whole
# mechanism on an illegitimate one, because the illegitimate case is precisely the one
# the user would not have approved had they been asked.
#
# WHAT IT DOES NOT CATCH, stated because the README tiers this:
#   - A weakening applied through Bash (`sed -i` on .eslintrc, `rm` of a hook). That is
#     destructive-guard.sh's matcher, and it classifies commands, not their effect on
#     config semantics.
#   - A weakening in a file this list does not name. The list is literal, not clever.
#   - Any judgment about WHETHER the edit weakens anything: it does not parse the file,
#     it asks about the path. Adding a rule and deleting one look identical here.
#     That half is agent-graded and the ask text says so.
#   - The first write that CREATES one of these files (there is nothing to weaken yet),
#     which is why a missing target is allowed through.
#
# Off with CC_CONFIG_GUARD=off. Fail-open on every error path.
{
  [ "${CC_CONFIG_GUARD:-on}" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *apply_patch|*create_new_file) ;;
    *) exit 0 ;;
  esac

  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
  [ -n "$file" ] || exit 0
  base=$(basename "$file")

  kind=""
  case "/$file" in
    */.claude/settings.json|*/.claude/settings.local.json|*/.claude/settings.*.json) kind="the settings file that decides which tools and permissions this session has" ;;
    */.claude/hooks/*|*/hooks/hooks.json)                                            kind="a hooks configuration — the file that decides which guards run at all" ;;
  esac
  [ -z "$kind" ] && case "$base" in
    hooks.json)            kind="a hooks configuration — the file that decides which guards run at all" ;;
    plugin.json|marketplace.json)
                           kind="a plugin manifest — it declares the hooks, matchers and dependencies an install gets" ;;
    .eslintrc|.eslintrc.*|eslint.config.*|biome.json|.rubocop.yml|ruff.toml|.flake8|setup.cfg|pytest.ini|pyproject.toml|phpstan.neon|phpstan.neon.dist|psalm.xml|psalm.xml.dist|.php-cs-fixer.php|.php-cs-fixer.dist.php|.golangci.yml|.golangci.yaml|clippy.toml|tsconfig.json)
                           kind="a lint, type-check or test configuration — the rules a build fails on" ;;
  esac
  # A hook SCRIPT, not just its manifest.
  [ -z "$kind" ] && case "/$file" in
    */hooks/*.sh|*/hooks/*.py|*/hooks/*.mjs|*/hooks/*.js) kind="a hook script — the code a guard runs" ;;
  esac
  [ -n "$kind" ] || exit 0

  # Nothing to weaken if it does not exist yet: creating a config is not relaxing one.
  # (A brand-new hooks.json is how a guard gets INSTALLED.)
  [ -f "$file" ] || exit 0

  # Self-exemption: this marketplace's own repository edits these files as its product.
  # Keyed on the marketplace manifest at the repo root, not on a plugin name, so a
  # consumer repo that happens to vendor a plugin is still guarded.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -n "$cwd" ]; then
    root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
    [ -f "$root/.claude-plugin/marketplace.json" ] && exit 0
  fi

  reason="command-guard: this writes to $kind (\`$base\`). Editing it is often the task — and it is also the cheapest way past a gate that just refused something, which is why you are being asked rather than told. Confirm you intend a configuration change here, not a way around a check. If a rule is wrong, say so in the change; if a check is in the way, the check is the thing to argue with. This guard reads the PATH, not the diff: it cannot tell adding a rule from deleting one. CC_CONFIG_GUARD=off disables it for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
