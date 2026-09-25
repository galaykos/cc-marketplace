#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
# PreToolUse secret guard. DENIES a Write/Edit/MultiEdit/NotebookEdit, an MCP file
# write, or (0.9.0) a Bash command whose heredoc or echo/printf lands text in a file,
# when that text introduces a high-confidence secret, before it reaches disk.
# Fail-open: any error, or a missing jq, exits 0 (allow) and never blocks legitimate
# work. Only high-confidence provider patterns deny — matching is shape-only: a fixture
# that still matches a pattern's shape (an AKIA-shaped fake) is denied; non-matching
# shapes (sk_live_placeholder, short values) pass.
#
# PLACEHOLDER EXEMPTION (0.5.0), the one departure from shape-only. The deny has no
# bound and no allow-file, so a write it refuses is refused on every retry, and the
# reason text's own advice — "use an obviously-fake value" — was unfollowable for
# the two shapes that came up: AWS's documented example key `AKIAIOSFODNN7EXAMPLE`
# matches the AKIA shape by construction (every AWS doc key ends in EXAMPLE), and
# an `.env.example` line `STRIPE_SECRET=<test-key prefix + a run of x's>` matches
# the assigned-literal shape (the literal is not spelled out here: GitHub's own push
# protection flags the x-run form as a Stripe test key, which is the point). The only
# exits were a Bash heredoc around the guard (a route 0.9.0 closed, below) or
# uninstalling it. So a matched VALUE is released when it is a placeholder by
# its own text: it ends in EXAMPLE (the AWS convention), it is one character
# repeated (xxxx…, 0000…), or it carries a placeholder word (example, placeholder,
# changeme, your-/your_, dummy, redacted, sample, fake, todo). A real secret that
# happens to contain one of those words passes — that residual is stated, small,
# and smaller than a deny that cannot be satisfied. The check is applied to the
# VALUE only, never to the variable name, so `EXAMPLE_TOKEN=<real>` still denies.
#
# BASH WRITES (0.9.0). Until 0.9.0 this guard matched the host write tools only, and the
# header above named the heredoc as the way around it. Measured 2026-09-25
# (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): the host steers file
# writes through Bash (auto mode `bashFirst`), one session's main thread wrote 233 files
# through Bash against 5 through Edit/Write, and in that session the one deny guard on
# the default write path never ran. On `Bash`, when cc_bash_write_targets (shared block
# below) finds at least one write target, the guard scans the text that will land in a
# file — heredoc bodies and echo/printf arguments whose pipeline writes a file, read by
# cc_secret_bash_chunks below — with the SAME patterns and placeholder exemption as the
# Write path, through one scanner (scan_for_secret). The deny names the file the
# offending chunk writes. Every target counts, inside the project or not: the Write
# path never filtered by location, and a key in /tmp/deploy.env is a key on disk. No
# per-call cap either — the scan reads command text, never a file, and a cap would let
# the ninth heredoc through; a pathological command can still outrun the timeout, which
# fails open, like every other error here.
# NOT caught on Bash, stated: a command with no write target (a live key in a
# `curl -H` header is a different problem — it leaves the machine, not lands on disk);
# interpreter writes (python open(), php file_put_contents); `cp`/`mv` of a file that
# already holds a secret; sed/perl -i replacement text; and the gaps
# cc_secret_bash_chunks lists. command-guard owns DESTROYING a live `.env` (truncation,
# overwrite); this guard owns a secret ENTERING any file, `.env.example` included, and
# never asks whether the target exists.

# --- bash write targets --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
# cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
# The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
# 233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
# Write|Edit.
# Prints one target path per line, as spelled in the command (relative or absolute).
# Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
# HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
# (`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
# `[sudo] tee [-a] <paths>`, and the last operand of `sed -i` / `perl -i`. Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed).
# The caller filters to existing files under its root.
cc_bash_write_targets() {
  printf '%s\n' "$1" | awk '
    function emit(p) {
      gsub(/^["\047]|["\047]$/, "", p)
      if (p == "" || p ~ /^\/dev\// || p ~ /[$`*?]/ || p ~ /^[&0-9-]/ && p !~ /[\/.]/) return
      print p
    }
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, last) {
      rest = ms; off = 0
      while (match(rest, /(^|[^0-9&=<>-])>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t&|;<>()"\047]+)/)) {
        tok = substr(os, off + RSTART, RLENGTH)
        off += RSTART + RLENGTH - 1; rest = substr(ms, off + 1)
        sub(/^[^>]*>>?[ \t]*/, "", tok)
        emit(tok)
      }
      n = 0; j = 1
      while (j <= length(ms)) {
        while (j <= length(ms) && substr(ms, j, 1) ~ /[ \t]/) j++
        if (j > length(ms)) break
        st = j; while (j <= length(ms) && substr(ms, j, 1) !~ /[ \t]/) j++
        n++; ws[n] = st; we[n] = j - 1
      }
      if (n == 0) return
      k = 1; word = substr(os, ws[1], we[1] - ws[1] + 1)
      if (word == "sudo" && n > 1) { k = 2; word = substr(os, ws[2], we[2] - ws[2] + 1) }
      if (word == "tee") {
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1)
          if (w == "<" || w == "<<<") { k++; continue }
          if (w !~ /^-/ && w !~ /^[<>0-9]/) emit(w)
        }
      } else if ((word == "sed" || word == "perl") && ms ~ /[ \t]-[a-zA-Z0-9]*i/) {
        last = substr(os, ws[n], we[n] - ws[n] + 1)
        if (n > 2 && last !~ /^-/ && substr(ms, ws[n], 1) !~ /["\047]/) emit(last)
      }
    }
    skip { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) skip = 0; next }
    {
      line = $0; m = mask(line)
      if (match(m, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        if (substr(m, RSTART, 1) != "<") { RSTART++; RLENGTH-- }
        term = substr(line, RSTART, RLENGTH + 1)
        sub(/^<<-?[ \t]*["\047]?/, "", term); sub(/[^A-Za-z0-9_].*$/, "", term)
        skip = 1
      }
      st = 1
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c == "|" || c2 == "&&") {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

# --- bash written text (local to this hook; NOT a shared block) ------------------------
# cc_secret_bash_chunks <command> — what a Bash command puts INTO files, which is what the
# Bash path scans (the Write path scans tool_input.content). Prints chunks: a line that
# starts with \036 and carries the WRITER — the pipeline (split on ; && ||, never inside
# quotes) whose targets the caller resolves with cc_bash_write_targets — then the
# chunk's text lines. Two sources, and only two:
#   - a heredoc BODY: the lines between `<<TERM` (`<<-`, quoted or `\`-escaped TERM too)
#     and TERM; writer = the pipeline holding the `<<` (`cat > f <<EOF`,
#     `cat <<EOF | tee -a f`);
#   - the ARGUMENTS of an `echo`/`printf` segment; writer = its pipeline
#     (`echo "K=v" >> .env.example`, `printf '%s\n' v | tee f`).
# A chunk whose writer names no file is dropped by the caller, so `git commit -F - <<EOF`
# and `echo x | grep y` scan nothing. The body of ANY heredoc whose pipeline writes a file
# is scanned, whatever reads it — `python3 - <<PY > out.txt` included, where the script is
# not what lands in out.txt. Accepted: the literal sits in a file-writing command either
# way, and the placeholder escape still applies.
# NOT read, stated: a `{ echo …; } > f` group (the redirect sits on the closer, not on
# the echo's pipeline); a here-string `<<<`; printf's format substitution (`printf
# 'K=%s' v` is scanned as written, so the assigned-literal rule cannot pair the name with
# the value — a provider-shaped value still matches alone); a quoted string or a `\`
# continuation spanning lines; a second heredoc opened on one line.
# mask() copies the one inside cc_bash_write_targets: the block is byte-locked and its
# awk functions are not reachable from outside it.
cc_secret_bash_chunks() {
  printf '%s\n' "$1" | awk '
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function echo_args(p, mp,   i, st, seg, out) {
      out = ""; st = 1
      for (i = 1; i <= length(mp) + 1; i++) {
        if (i > length(mp) || substr(mp, i, 1) == "|") {
          seg = substr(mp, st, i - st)
          if (match(seg, /^[ \t]*(echo|printf)[ \t]/)) out = out substr(p, st + RLENGTH, i - st - RLENGTH) "\n"
          st = i + 1
        }
      }
      return out
    }
    inbody { if (trim($0) == term) inbody = 0; else print; next }
    {
      line = $0; m = mask(line); st = 1; opener = ""
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c2 == "&&" || c2 == "||") {
          if (i > st) {
            p = substr(line, st, i - st); mp = substr(m, st, i - st)
            a = echo_args(p, mp)
            if (a != "") printf "\036%s\n%s", p, a
            if (opener == "" && match(mp, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
              t = substr(p, RSTART, RLENGTH)
              sub(/^[^<]*<<-?[ \t]*["\047]?/, "", t); sub(/^\\/, "", t); sub(/[^A-Za-z0-9_].*$/, "", t)
              if (t != "") { opener = p; term = t }
            }
          }
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
      if (opener != "") { printf "\036%s\n", opener; inbody = 1 }
    }'
}
{
  input=$(cat)
  # OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
  # uninstalling the plugin. Every other guard in the marketplace ships one,
  # and a global install makes "turn it off here" a real need.
  [ "${CC_SECRET_SCAN:-on}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    # An MCP server that writes files bypasses the four host tool names entirely, and
    # a session driving the IDE writes every file through one. Keys verified against
    # the shipped tool schemas on 2026-09-14 (JetBrains MCP): create_new_file takes
    # `pathInProject` + `text`; apply_patch takes `input` (alias `patch`) carrying the
    # whole patch, whose added lines are what a secret would ride in on, and no single
    # path — hence the empty `file` below, which only affects the message, not the deny.
    # Residual, stated: this covers the servers whose key names are listed here. A
    # server using different keys writes past this guard, as every non-listed tool did
    # before. The matcher in hooks.json and this case must widen together.
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

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
  # scan_for_secret <text> — THE scanner, one for both paths: resets `hit`, then sets it
  # to the label of the first pattern whose match survives the placeholder test.
  scan_for_secret() {
    text=$1; hit=""
    [ -n "$text" ] || return 0
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
    # A credential that lives in a URL rather than in an assignment. `DATABASE_URL=
    # postgres://admin:<pw>@db/app` in a .env, a tfvars connection string, a compose
    # `POSTGRES_*` DSN, a Helm values DSN — none of them is a provider key and none of
    # them has 24 characters after a `secret=`-shaped operator, so the whole file passed.
    # The password run is bounded at 6+ so `redis://localhost:6379` (no password) and
    # `https://user:@host` do not match; it excludes `/?#` because RFC 3986 userinfo
    # cannot contain them, which is what keeps `https://host:8080/mail?to=a@b.com` out;
    # and it refuses a leading `$`/`{` so the CORRECT shape, `postgres://u:${DB_PASS}@db`,
    # is not denied on every retry (measured — the first draft denied it). NOT caught,
    # stated: a real password that itself begins with `$` or `{`, one under 6 characters,
    # and any credential in a URL whose scheme is not in the list.
    detect "a credential embedded in a URL" '(postgres|postgresql|mysql|mongodb(\+srv)?|redis|rediss|amqp|amqps|https?)://[^:/@[:space:]]+:[^@[:space:]/?#${][^@[:space:]/?#]{5,}@'
    # A Slack incoming-webhook URL is a bearer credential in URL clothing: anyone holding
    # it posts as the app, forever, and it matches no `secrets.`-shaped assignment. NOT
    # caught: any other vendor's webhook URL — each has its own shape and this is the one
    # that came up.
    detect "a Slack webhook URL" 'hooks\.slack\.com/services/T[^/]+/B[^/]+/.{16,}'
    detect_i "an assigned secret literal" '(api[_-]?key|secret|token|passwd|password)([_-][A-Za-z0-9]+)*["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+=_-]{24,}'
  }

  file=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    # Cheap exit for the common case — a Bash call that writes no file — before any
    # chunk is read.
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    # Keep the chunks whose writer names a file; remember that file for the message.
    n=0; keep=0; sep=$(printf '\036')
    while IFS= read -r l; do
      case "$l" in
        "$sep"*)
          tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
          if [ -n "$tgt" ]; then n=$((n + 1)); ctgt[$n]=$tgt; ctext[$n]=""; keep=1; else keep=0; fi ;;
        *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
      esac
    done <<EOF_C
$(cc_secret_bash_chunks "$cmd")
EOF_C
    i=1
    while [ "$i" -le "$n" ] && [ -z "$hit" ]; do
      scan_for_secret "${ctext[$i]}"; file=${ctgt[$i]}; i=$((i + 1))
    done
  else
    # Collect the text being written across the tool shapes.
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        .tool_input.text // empty,
        .tool_input.input // empty,
        .tool_input.patch // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
    scan_for_secret "$text"
  fi
  [ -n "$hit" ] || exit 0

  reason="secret-scanning: this write appears to contain ${hit}. Blocked before it reaches disk. Move the value to an environment variable or a secret store and reference it by name; if this is a deliberate fixture, make the value announce itself — end it in EXAMPLE, or use a placeholder word (example, placeholder, changeme, dummy, xxxx) — and the guard lets it through."
  [ -n "$file" ] && reason="$reason (file: $file)"
  # Name the escape in the message that blocks you: an off-switch documented only in a
  # CHANGELOG is not reachable by the person it exists for.
  reason="$reason CC_SECRET_SCAN=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
