#!/bin/bash
# Absolute-path shebang, same reasoning as secret-scanning's guard: the fail-open
# guarantee must hold even under a stripped PATH.
#
# PostToolUse WARN (never deny) on the mechanically detectable subset of the
# security-review skill — the Laravel/Vite shapes that used to be review-time only,
# plus the stack-agnostic sinks (eval, shell-string exec, unsafe deserialization,
# XXE, TLS-off, ECB, script-without-SRI) ported from Anthropic's security-guidance
# pattern set, each gated to the file extensions where the token IS the sink. Warn, not deny, on purpose: each has a legitimate
# form (a fixture, an admin-only Blade page, an already-sanitized sink), and a
# deny that fires on ambiguous cases is a deny that gets turned off.
#
# One warning per (session, file, finding) — repeat edits stay quiet. Fail-open:
# any error, or missing jq, exits 0 silently. CC_SECURITY_SCAN=off disables.
#
# Residual (stated, per the has-teeth convention): shape-only matching on the
# text being written, single-line — a multi-line yaml.load(...) call with SafeLoader
# on the next line still warns, and a sink reached through an alias never does.
# Cross-file flows, authz logic, injection via query builders other than whereRaw —
# still review-time judgment (/security:review). GitHub Actions expression injection
# is deliberately NOT here: devops/hooks/workflow-guard.sh denies it pre-write.
# Three LLM sinks (prompt-interpolation, llm-output-exec, tool-result-unfenced) are
# ported from llm-app's prompt-injection prose rule and carry the same single-line
# residual: a system prompt assembled across lines, or a completion executed two
# statements later, never fires — and no regex detects injection IN the data.
{
  [ "${CC_SECURITY_SCAN:-on}" = "off" ] && exit 0
  # Also honour the marketplace-wide advisory switch other plugins' READMEs advertise.
  # This hook is warn-only, so there is no deny lane to protect from it.
  [ "${CC_REMIND:-on}" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Pattern and rationale: code-review/hooks/conventions.sh (context-key one-shot).
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  # The context value is usually an ABSOLUTE transcript path. Used raw as a directory
  # component it mirrored the whole path under $TMPDIR — seven nested dirs per session —
  # and nothing ever removed them. Hash it, the way every sibling one-shot does
  # (ask-ledger/hooks/ledger.sh:53), so the marker tree is one flat dir per context, and
  # sweep keys older than a day. Does NOT catch: a machine where this hook never fires
  # again keeps its last day of markers — the sweep only runs when the hook runs.
  skey=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$skey" ] || skey=nosession
  lockroot="${TMPDIR:-/tmp}/cc-security-scan"
  find "$lockroot" -mindepth 1 -maxdepth 1 -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null

  hits=""
  # Extension gate: a pattern that only means something in one language (eval in a
  # README, innerHTML in a Python docstring) is a warning that gets turned off.
  # Groups are ERE alternations over the lowercased basename's suffix.
  JS='js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte'
  PY='py|pyi|ipynb'
  PHP='php'
  MARKUP='html|htm|php|vue|jsx|tsx|twig|erb|ejs|hbs'
  CODE='[a-z0-9]+'   # any extension; the doc exclusion below still applies
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
  # Every bundler that exposes env to the client does it by PREFIX, and each picked its
  # own: Vite `VITE_`, Next `NEXT_PUBLIC_`, Nuxt `NUXT_PUBLIC_`, Expo `EXPO_PUBLIC_`,
  # SvelteKit/Astro `PUBLIC_`, CRA `REACT_APP_`, Gatsby `GATSBY_`, Vue CLI `VUE_APP_`.
  # The slug is prefix-neutral for the same reason. Does NOT catch: a secret exposed
  # without a prefix (an explicit `define:`/`envPrefix` override), or a name whose
  # secret-ness is not in the identifier (`NEXT_PUBLIC_FOO`).
  detect "client-bundle-secret" \
    '(^|[^A-Z0-9_])(VITE|NEXT_PUBLIC|NUXT_PUBLIC|EXPO_PUBLIC|PUBLIC|REACT_APP|GATSBY|VUE_APP)_[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|API_?KEY)' \
    "a public-bundle env prefix (VITE_, NEXT_PUBLIC_, NUXT_PUBLIC_, EXPO_PUBLIC_, PUBLIC_, REACT_APP_, GATSBY_, VUE_APP_) compiles the value into the client bundle — server secrets must not carry one"
  detect "raw-sql-interpolation" \
    'whereRaw\((["'"'"'][^"'"'"')]*\{\$|[^,)]*\.[[:space:]]*\$)' \
    "variable inside whereRaw SQL — use ? placeholders with the bindings array"
  detect "raw-html-sink" \
    'dangerouslySetInnerHTML|v-html[[:space:]]*=|\{@html[[:space:]]|set:html[[:space:]]*=|\.(innerHTML|outerHTML)[[:space:]]*=|\.insertAdjacentHTML[[:space:]]*\(|document\.write(ln)?[[:space:]]*\(' \
    "raw HTML sink — sanitize upstream or render as text; XSS if any user data reaches it"

  # ---- stack-agnostic sinks, ported from Anthropic's security-guidance pattern set ----
  # (claude-plugins-official, 2026-09-03). Same warn tier, same one-per-finding dedup.
  # Each is gated to the language where the token IS the sink, so a README that
  # mentions eval() stays quiet.
  detect "code-eval" \
    '(^|[^[:alnum:]_.$>])eval[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\(' \
    "eval()/new Function() executes a string as code — parse data with JSON/literal parsers; if input is truly static, say so in a comment" \
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

  # ---- LLM sinks, ported from llm-app's prompt-injection rule (2026-09-10) ----------
  # Each ERE is composed from named pieces so the shape stays readable; every piece is
  # still one line and the match is still one line. A `system`/`role: "system"` key
  # whose value is built by interpolation or concatenation; a completion/message value
  # on the same line as an exec sink; a tool-result/retrieved-chunk name interpolated
  # into a prompt/messages string with no delimiter token on that line.
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

  [ -n "$hits" ] || exit 0
  ctx="${hits}[security] warn-tier only (file: ${file}) — judgment cases stay with /security:review; CC_SECURITY_SCAN=off disables."
  jq -cn --arg c "$ctx" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
