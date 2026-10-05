#!/bin/bash
# write-scan.sh (PostToolUse on Write, Edit, MultiEdit and Bash; payload on stdin) — warns, never denies, once per context, file and finding,
#   on a security sink one written line or Bash-written file shows; the ported and LLM sinks only in their own file types, the Laravel/Vite/raw-HTML ones in any file.
# Off: CC_SECURITY_SCAN=off or CC_REMIND=off. Fails open on any error, a missing jq included.
# CC_SECURITY_SCAN / CC_REMIND unset: the /config options cc_security_scan / cc_remind decide.
# Misses: a sink split across lines or reached through an alias, and injection inside the data; cross-file flows, authz, raw SQL outside whereRaw;
#   a client secret with no public-bundle prefix or with no secret word in its name (NEXT_PUBLIC_FOO); on Bash, targets past the eighth, bytes past
#   256 KiB, writes cc_bash_write_targets misses, a relative target in a command holding a cd/pushd. Warns anyway: a guard on the next line (SafeLoader, weights_only).
# Why, limits, history: rationale/derivations/plugin-security.md § plugins/security/hooks/write-scan.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

# Shared block templates/blocks/bash-write-targets.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-targets.md
# cc_bash_write_targets <command> prints each path the command writes through `>`/`>>`, `[sudo] tee` or `sed -i`/`perl -i`,
# one per line as spelled; heredoc bodies and quoted text never match. A path guard keeps existing files under its root.
# BSD sed's -I always takes the next word as its backup suffix, so that word is never a target; after a bare sed -i,
# a `''` or `.`-led word is read as one too, unless it would be the only file.
# Misses: interpreter writes, cp/mv/install, a path in a variable, a glob, a `\` line continuation, a digit- or &-led
# redirect and `>&`, sed/perl/tee behind another command word (gsed, /usr/bin/sed, env, xargs, sudo -u), a `-`-led
# operand with no `/` or `.`, operands cut short by a `&` inside `$(( ))`/`${ }`, every line after a `<<\EOF` opener.
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
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, x, c, a, inp, scr, eo, sfx, nf, f) {
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
      } else if (word == "sed" || word == "perl") {
        inp = 0; scr = 0; eo = 0; sfx = ""; nf = 0
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1); x = substr(ms, ws[k], we[k] - ws[k] + 1)
          if (x ~ /[<>]/) {
            a = substr(w, 1, match(x, /[<>]/) - 1)
            if (a !~ /^[0-9&]*$/) f[++nf] = a
            if (x ~ /[<>][&|]?$/) k++
            continue
          }
          if (eo || x !~ /^-./) { f[++nf] = w; if (word == "perl") eo = 1; continue }
          if (x == "--") { eo = 1; continue }
          if (x ~ /^--/) {
            if (word == "sed" && x ~ /^--in-place(=|$)/) inp = 1
            if (word == "sed" && x ~ /^--(expression|file)(=|$)/) { scr = 1; if (x !~ /=/) k++ }
            continue
          }
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (c == "i" || word == "sed" && c == "I") {
              inp = 1
              if (word == "sed" && j == length(x) && k < n) {
                a = substr(os, ws[k + 1], we[k + 1] - ws[k + 1] + 1); gsub(/^["\047]|["\047]$/, "", a)
                if (c == "I") k++
                else if (a == "" || a ~ /^\.[^\/<>]*$/) { k++; sfx = a }
              }
              break
            }
            if (c == "e" || c == (word == "sed" ? "f" : "E")) { scr = 1; if (j == length(x)) k++; break }
            if (c == (word == "sed" ? "l" : "I")) { if (j == length(x)) k++; break }
            if (word == "perl" && c ~ /[MmFxdDVC]/) break
            if (word == "perl" && c ~ /[l0]/) while (substr(x, j + 1, 1) ~ /[0-7]/) j++
          }
        }
        if (!inp) return
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/ || eo) { emit(f[j]); sfx = "" }
        if (sfx != "") emit(sfx)
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
        if (i > length(m) || c == ";" || c == "|" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||" || c2 == "|&") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

MARKER_TTL_MIN=1440
MAX_BASH_TARGETS=8
{
  [ "$(cc_option CC_SECURITY_SCAN on)" = "off" ] && exit 0
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    targets=$(cc_bash_write_targets "$cmd" | head -n "$MAX_BASH_TARGETS")
    [ -n "$targets" ] || exit 0
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
    # A cd inside a heredoc body moves nothing, so bodies are dropped before the cd test.
    hascd=0
    printf '%s\n' "$cmd" | awk '
      inh { if ($0 ~ ("^[\t]*" term "[ \t]*$")) inh = 0; next }
      { print; l = $0; gsub(/<<</, "", l); o = "<<-?[ \t]*[\"\047\\\\]?"
        if (match(l, o "[A-Za-z_][A-Za-z0-9_]*")) { term = substr(l, RSTART, RLENGTH); sub(o, "", term); inh = 1 } }' \
      | grep -qE '(^|[;&|(])[[:space:]]*(cd|pushd)[[:space:]]' && hascd=1
  else
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    [ -n "$text" ] || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
  fi
  # Context key, not session: a subagent shares its parent's session_id but has its own transcript.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  skey=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$skey" ] || skey=nosession
  lockroot="${TMPDIR:-/tmp}/cc-security-scan"
  find "$lockroot" -mindepth 1 -maxdepth 1 -type d -mmin +"$MARKER_TTL_MIN" -exec rm -rf {} + 2>/dev/null

  hits=""
  JS='js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte'
  PY='py|pyi|ipynb'
  PHP='php'
  MARKUP='html|htm|php|vue|jsx|tsx|twig|erb|ejs|hbs'
  CODE='[a-z0-9]+'
  scan_text() {
    lfile=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    case "$lfile" in *.md|*.mdx|*.txt|*.rst|*.json|*.yaml|*.yml|*.lock) isdoc=1 ;; *) isdoc=0 ;; esac
    detect() { # detect <slug> <ERE> <one-line advice> [ext-alternation] [exclude-ERE]
      if [ -n "${4:-}" ]; then
        printf '%s' "$lfile" | grep -qE "\.(${4})$" || return 0
        [ "$isdoc" = 1 ] && return 0
      fi
      if [ -n "${5:-}" ]; then
        printf '%s' "$text" | grep -E "$2" | grep -vE "$5" | grep -q . || return 0
      else
        printf '%s' "$text" | grep -qE "$2" || return 0
      fi
      lock="${lockroot}/${skey}/$(printf '%s%s' "$file" "$1" | cksum | tr ' ' '_')"
      mkdir -p "${lockroot}/${skey}" 2>/dev/null || return 0
      mkdir "$lock" 2>/dev/null || return 0   # already warned for this file+finding
      hits="${hits}[security] ${1}: ${3}
"
    }

    detect "mass-assignment-open" \
      '\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' \
      "empty \$guarded disables mass-assignment protection — list guarded fields or use \$fillable"
    detect "blade-unescaped" \
      '\{!![[:space:]]*\$' \
      "{!! \$var !!} skips Blade escaping — use {{ }} unless this exact value is sanitized HTML"
    detect "client-bundle-secret" \
      '(^|[^A-Z0-9_])(VITE|NEXT_PUBLIC|NUXT_PUBLIC|EXPO_PUBLIC|PUBLIC|REACT_APP|GATSBY|VUE_APP)_[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|API_?KEY)' \
      "a public-bundle env prefix (VITE_, NEXT_PUBLIC_, NUXT_PUBLIC_, EXPO_PUBLIC_, PUBLIC_, REACT_APP_, GATSBY_, VUE_APP_) compiles the value into the client bundle — server secrets must not carry one"
    detect "raw-sql-interpolation" \
      'whereRaw\((["'"'"'][^"'"'"')]*\{\$|[^,)]*\.[[:space:]]*\$)' \
      "variable inside whereRaw SQL — use ? placeholders with the bindings array"
    detect "raw-html-sink" \
      'dangerouslySetInnerHTML|v-html[[:space:]]*=|\{@html[[:space:]]|set:html[[:space:]]*=|\.(innerHTML|outerHTML)[[:space:]]*=|\.insertAdjacentHTML[[:space:]]*\(|document\.write(ln)?[[:space:]]*\(' \
      "raw HTML sink — sanitize upstream or render as text; XSS if any user data reaches it"

    detect "code-eval" \
      '(^|[^[:alnum:]_.$>])eval[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\(' \
      "eval()/new Function() executes a string as code — parse data with JSON/literal parsers; a static string wants the literal, not eval. When eval is genuinely required, a one-line comment at the call saying why" \
      "$CODE"
    detect "shell-string-exec" \
      'child_process\.exec(Sync)?[[:space:]]*\(|(^|[^[:alnum:]_.])execSync[[:space:]]*\(|(^|[^[:alnum:]_.$>])(shell_exec|passthru|popen|proc_open)[[:space:]]*\(|(^|[^[:alnum:]_.$>])(exec|system)[[:space:]]*\([[:space:]]*["'"'"'$]|os\.system[[:space:]]*\(|subprocess\.[A-Za-z_]+\(.*shell[[:space:]]*=[[:space:]]*True' \
      "shell-string execution — pass an argument array (execFile/spawn, subprocess.run([...]), escapeshellarg) so metacharacters in input are data, not commands" \
      "$JS|$PY|$PHP"
    detect "unsafe-deserialization" \
      '(^|[^[:alnum:]_])(pickle|cPickle|cloudpickle|dill|marshal)\.(load|loads|Unpickler)[[:space:]]*\(|joblib\.load[[:space:]]*\(|read_pickle[[:space:]]*\(|shelve\.open[[:space:]]*\(|allow_pickle[[:space:]]*=[[:space:]]*True|(^|[^[:alnum:]_>$])unserialize[[:space:]]*\([[:space:]]*\$' \
      "deserializing untrusted bytes constructs arbitrary objects — use JSON or a schema-validated decoder; PHP unserialize() takes allowed_classes" \
      "$PY|$PHP"
    detect "unsafe-yaml-load" \
      'yaml\.(load|unsafe_load)[[:space:]]*\(' \
      "yaml.load() without SafeLoader executes !!python/object tags — use yaml.safe_load()" \
      "$PY" 'SafeLoader|safe_load'
    detect "torch-unsafe-load" \
      'torch\.load[[:space:]]*\(' \
      "torch.load() unpickles arbitrary objects unless weights_only=True" \
      "$PY" 'weights_only[[:space:]]*=[[:space:]]*True'
    detect "xml-external-entities" \
      '(ElementTree|[^[:alnum:]_]ET|minidom|xml\.sax)\.(parse|fromstring|parseString|XML|make_parser)[[:space:]]*\(|libxml_disable_entity_loader[[:space:]]*\([[:space:]]*false|LIBXML_NOENT' \
      "XML parsed with entities enabled — XXE and billion-laughs; use defusedxml (Python) or keep entity loading off (PHP)" \
      "$PY|$PHP"
    detect "tls-verify-off" \
      'verify[[:space:]]*=[[:space:]]*False|rejectUnauthorized[[:space:]]*:[[:space:]]*false|InsecureSkipVerify[[:space:]]*:[[:space:]]*true|NODE_TLS_REJECT_UNAUTHORIZED[[:space:]]*=[[:space:]]*["'"'"']?0|CURLOPT_SSL_VERIFYPEER[[:space:]]*(=>|,)[[:space:]]*(false|0)[^.0-9]|["'"'"']verify["'"'"'][[:space:]]*=>[[:space:]]*false' \
      "TLS verification disabled — MITM-able; trust the dev CA instead of turning verification off" \
      "$CODE"
    detect "weak-cipher-mode" \
      'AES\.MODE_ECB|["'"'"']aes-[0-9]+-ecb["'"'"']|crypto\.(createCipher|createDecipher)[[:space:]]*\(' \
      "ECB mode leaks plaintext structure and createCipher derives keys without an IV — use AES-GCM via createCipheriv / modes.GCM" \
      "$CODE"
    detect "script-without-sri" \
      '<script[^>]*src[[:space:]]*=[[:space:]]*["'"'"'](https?:)?//' \
      "external <script> without integrity= — add an SRI hash and crossorigin, or self-host" \
      "$MARKUP" 'integrity[[:space:]]*='

    SYSKEY='role["'"'"']?[[:space:]]*(:|=>|=)[[:space:]]*["'"'"']system["'"'"']|(^|[^[:alnum:]_])["'"'"']?(system|system_?prompt|systemPrompt)["'"'"']?[[:space:]]*(:|=>|=)'
    INTERP='\$\{|\{\$|r?f["'"'"']{1,3}[^"'"'"']*\{|\.format[[:space:]]*\(|%s|["'"'"'`][[:space:]]*\+[[:space:]]*[A-Za-z_$]|[A-Za-z0-9_$][[:space:]]*\+[[:space:]]*["'"'"'`]|["'"'"'][[:space:]]*\.[[:space:]]*\$|\$[A-Za-z0-9_]+[[:space:]]*\.[[:space:]]*["'"'"']'
    detect "prompt-interpolation" \
      "(${SYSKEY}).*(${INTERP})" \
      "user input inside the system prompt — pass it as a user turn or a delimited data block, never into the instruction text" \
      "$JS|$PY|$PHP" '[=!]='
    LLMSRC='completion|choices\[0\]|(\.|->)(content|text)([^[:alnum:]_]|$)|(^|[^[:alnum:]_$])message([^[:alnum:]_]|$)'
    SINKCALL='(^|[^[:alnum:]_.$>])(eval|exec(Sync)?|system|shell_exec|passthru|proc_open|popen)[[:space:]]*|os\.system[[:space:]]*|new[[:space:]]+Function[[:space:]]*|child_process\.[A-Za-z]+[[:space:]]*|subprocess\.[A-Za-z_]+[[:space:]]*'
    detect "llm-output-exec" \
      "(${LLMSRC}).*(${SINKCALL})\(|(${SINKCALL})\((message([^[:alnum:]_]|$)|.*(${LLMSRC}))" \
      "model output executed as code — validate against a schema or allow-list first" \
      "$JS|$PY|$PHP"
    TRVAR='tool_?[Rr]esults?|retrieved[A-Za-z_]*|chunks|documents|context_docs'
    TRKEY='[Pp]rompt|messages|content["'"'"']?[[:space:]]*(:|=>)'
    TRINTERP='["'"'"'`][^"'"'"'`]*\$?\{([^}]*[^[:alnum:]_])?('"$TRVAR"')|\+[[:space:]]*\$?('"$TRVAR"')([^[:alnum:]_]|$)|(^|[^[:alnum:]_])\$?('"$TRVAR"')[[:space:]]*\+|\.[[:space:]]*\$('"$TRVAR"')([^[:alnum:]_]|$)|\$('"$TRVAR"')[[:space:]]*\.|%[[:space:]]*\(?('"$TRVAR"')([^[:alnum:]_]|$)|(format|join)\([[:space:]]*('"$TRVAR"')([^[:alnum:]_]|$)'
    detect "tool-result-unfenced" \
      "(${TRKEY}).*(${TRINTERP})|(${TRINTERP}).*(${TRKEY})" \
      "retrieved text is untrusted input — fence it with a delimiter and tell the model it is data" \
      "$JS|$PY|$PHP" '<<<|"""|'"'''"'|<[a-z_]+>|\[BEGIN|---|```'
  }

  if [ "$tool" = Bash ]; then
    hit_files=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        /*) ;;
        "~/"*) [ -n "${HOME:-}" ] || continue; p="$HOME/${p#??}" ;;
        *) [ "$hascd" = 0 ] || continue; p="$cwd/$p" ;;
      esac
      # One spelling per file, so `./app.js` and `app.js` share a dedup key.
      d=$(CDPATH= cd -- "$(dirname -- "$p")" 2>/dev/null && pwd) || continue
      p="$d/$(basename -- "$p")"
      [ -f "$p" ] || continue
      file=$p
      text=$(head -c 262144 "$p" 2>/dev/null)
      [ -n "$text" ] || continue
      before=$hits
      scan_text
      [ "$hits" = "$before" ] || hit_files="${hit_files:+$hit_files }$p"
    done <<EOF_T
$targets
EOF_T
  else
    scan_text
    hit_files=$file
  fi

  [ -n "$hits" ] || exit 0
  ctx="${hits}[security] warn-tier only (file: ${hit_files}) — judgment cases stay with /security:review; CC_SECURITY_SCAN=off disables."
  jq -cn --arg c "$ctx" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
