#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
# PreToolUse secret guard. DENIES a Write/Edit/MultiEdit that introduces a
# high-confidence secret, before it reaches disk. Fail-open: any error, or a missing
# jq, exits 0 (allow) and never blocks legitimate work. Only high-confidence provider
# patterns deny — matching is shape-only: a fixture that still matches a pattern's
# shape (an AKIA-shaped fake) is denied; non-matching shapes (sk_live_placeholder,
# short values) pass.
#
# PLACEHOLDER EXEMPTION (0.5.0), the one departure from shape-only. The deny has no
# bound and no allow-file, so a write it refuses is refused on every retry, and the
# reason text's own advice — "use an obviously-fake value" — was unfollowable for
# the two shapes that came up: AWS's documented example key `AKIAIOSFODNN7EXAMPLE`
# matches the AKIA shape by construction (every AWS doc key ends in EXAMPLE), and
# an `.env.example` line `STRIPE_SECRET=<test-key prefix + a run of x's>` matches
# the assigned-literal shape (the literal is not spelled out here: GitHub's own push
# protection flags the x-run form as a Stripe test key, which is the point). The only exits were a Bash heredoc around the guard
# or uninstalling it. So a matched VALUE is released when it is a placeholder by
# its own text: it ends in EXAMPLE (the AWS convention), it is one character
# repeated (xxxx…, 0000…), or it carries a placeholder word (example, placeholder,
# changeme, your-/your_, dummy, redacted, sample, fake, todo). A real secret that
# happens to contain one of those words passes — that residual is stated, small,
# and smaller than a deny that cannot be satisfied. The check is applied to the
# VALUE only, never to the variable name, so `EXAMPLE_TOKEN=<real>` still denies.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  # Collect the text being written across the three tool shapes.
  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

  hit=""
  # `--` is load-bearing: the private-key pattern starts with dashes, and without
  # it grep parses the pattern as options and the pattern never matches.
  # placeholder <matched-value> — 0 when the value announces itself as fake.
  placeholder() {
    local v="$1" lc
    lc=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    case "$lc" in *example) return 0 ;; esac
    printf '%s' "$lc" | grep -qE 'example|placeholder|changeme|change-me|your[_-]|dummy|redacted|sample|fake|todo|xxxx' && return 0
    # one character repeated for the whole value
    [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l | tr -d ' ')" -le 1 ] && return 0
    return 1
  }
  # detect <label> <ERE>: the first pattern whose match survives the placeholder
  # test sets the hit. Every match of a pattern is checked, not just the first — a
  # file can carry a placeholder AND a real value.
  detect() {
    local m
    [ -z "$hit" ] || return 0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      placeholder "$m" || { hit="$1"; return 0; }
    done <<EOF_M
$(printf '%s' "$text" | grep -oE -- "$2" 2>/dev/null)
EOF_M
  }
  # Case-INSENSITIVE twin, for the generic assigned-literal rule only. The provider
  # patterns below must stay case-sensitive: `AKIA`, `AIza`, `sk_live_` and the PEM
  # header are literal provider prefixes, and -i would loosen them toward noise
  # (`aiza`+35 chars matches far more prose than the real key shape does).
  detect_i() {
    local m v
    [ -z "$hit" ] || return 0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      # the VALUE is the run of value characters at the end of the match; the
      # placeholder test must not see the variable name
      v=$(printf '%s' "$m" | sed -E 's/^[^:=]*[:=]["'"'"' ]*//')
      placeholder "${v:-$m}" || { hit="$1"; return 0; }
    done <<EOF_M
$(printf '%s' "$text" | grep -oiE -- "$2" 2>/dev/null)
EOF_M
  }
  detect "an AWS access key ID"      'AKIA[0-9A-Z]{16}'
  detect "a private key block"       '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
  detect "a GitHub token"            'gh[pousr]_[A-Za-z0-9]{36,}'
  detect "a Slack token"             'xox[baprs]-[A-Za-z0-9-]{10,}'
  detect "a Google API key"          'AIza[0-9A-Za-z_-]{35}'
  detect "a Stripe live secret key"  'sk_live_[0-9a-zA-Z]{24,}'
  # Two widenings, both forced by where assigned literals actually live: .env,
  # compose `environment:`, Actions `env:`, k8s manifests, Dockerfile ENV.
  #
  # 1. CASE-INSENSITIVE (detect_i). Those surfaces name variables in UPPERCASE by
  #    convention. Matched case-sensitively, this catch-all tier — the one that
  #    exists precisely to cover what the provider patterns miss — let `SECRET=`,
  #    `API_KEY=`, `TOKEN=` and `PASSWORD=` through while denying their lowercase
  #    twins on identical values.
  # 2. SEPARATOR TAIL `([_-][A-Za-z0-9]+)*`. The trigger word used to have to sit
  #    immediately before the operator, so the canonical `AWS_SECRET_ACCESS_KEY=`
  #    missed: after `SECRET` comes `_ACCESS_KEY`, not `=`. The tail is restricted
  #    to `_`/`-` separated segments on purpose — that is the env-var naming shape.
  #    It deliberately does NOT match camelCase, so `tokenizerConfig = "<long>"`
  #    stays clean while `AWS_SECRET_ACCESS_KEY=<long>` denies.
  #
  # The old harness only exercised `api_key = "..."` — lowercase, no tail — so a
  # green run never showed either hole.
  detect_i "an assigned secret literal" '(api[_-]?key|secret|token|passwd|password)([_-][A-Za-z0-9]+)*["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+=_-]{24,}'
  [ -n "$hit" ] || exit 0

  reason="secret-scanning: this write appears to contain ${hit}. Blocked before it reaches disk. Move the value to an environment variable or a secret store and reference it by name; if this is a deliberate fixture, make the value announce itself — end it in EXAMPLE, or use a placeholder word (example, placeholder, changeme, dummy, xxxx) — and the guard lets it through."
  [ -n "$file" ] && reason="$reason (file: $file)"

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
