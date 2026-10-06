#!/usr/bin/env bash
# pattern-parity.test.sh — one fixture set through hooks/scan.sh (a PreToolUse Write) and hooks/redact-core.ts (redact, under node):
#   scan.sh denies exactly when the core reports a label and names the core's first label, scan.sh passes the core's redacted
#   text, a fixture's exact redacted text holds, both reject a malformed patterns.tsv at the same line, and redact stays under
#   a time bound on an adversarial line. A documented grep/JavaScript difference is a divergence fixture naming the side that
#   flags and its label. Every failure counts in the parity line. Secret shapes are assembled at runtime: the guard would deny
#   a write of this file.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/scan.sh"; CORE="$ROOT/hooks/redact-core.ts"; PAT="$ROOT/hooks/patterns.tsv"
# A hook inherits the host's locale, usually UTF-8, which is where grep -i folds U+017F and U+0131 into s and i.
export LC_ALL=C.UTF-8
unset CC_SECRET_SCAN CLAUDE_PLUGIN_OPTION_CC_SECRET_SCAN
command -v node >/dev/null && command -v jq >/dev/null || { echo "FAIL: node and jq are required"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mismatch=0; offcase=0; slow=0; diverged=0
BOUND_MS=500

AWS="AKIA""ABCDEFGHIJKLMNOP"
AWS2="AKIA""QRSTUVWXYZ234567"
AWS_DOC="AKIA""IOSFODNN7EXAMPLE"
PKEY="-----BEGIN RSA PRIVATE ""KEY-----"
PKEY8="-----BEGIN PRIVATE ""KEY-----"
KEY_BODY='MIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu'
GH="ghp""_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
SLACK="xoxb""-1234567890-abcdef"
GOOG="AIza""SyA1234567890abcdefghijklmnopqrstuv"
STRIPE="sk_live""_abcdefghijklmnopqrstuvwx"
LONGVAL='aVeryLongSecretValue1234567890abcd'
WEBHOOK="https://hooks.slack"".com/services/T01ABCD2EF/B09XYZ12345/"
LONG_S=$(printf '\xc5\xbf'); DOTLESS_I=$(printf '\xc4\xb1'); KELVIN=$(printf '\xe2\x84\xaa'); EMOJI=$(printf '\xf0\x9f\x98\x80')
CR=$'\r'
ASSIGNED='[REDACTED:an assigned secret literal]'

names=(); wants=(); texts=(); extras=()
# fx deny|allow|diverge <name> <text> [<extra>] — deny: the exact redacted text; diverge: scan:<label> or core:<label>, the
#   one side that flags. <NUL> in a text becomes U+0000 in the payload.
fx() { wants+=("$1"); names+=("$2"); texts+=("$3"); extras+=("${4-}"); }

fx deny    "AWS access key ID"                    "aws_ref = \"$AWS\""
fx deny    "private key block"                    "$PKEY"
fx deny    "GitHub token"                         "gh auth: $GH"
fx deny    "Slack token"                          "SLACK=$SLACK"
fx deny    "Google API key"                       "g=$GOOG"
fx deny    "Stripe live secret key"               "$STRIPE"
fx deny    "credential in a postgres URL"         "$(printf 'DATABASE_URL=postgres://admin:%s@db.internal:5432/app' 'Sup3rS3cretVal')"
fx deny    "Slack webhook URL"                    "SLACK=${WEBHOOK}abcdefghijklmnopqrstuvwx"
fx deny    "assigned literal"                     "$(printf 'api_%s = "%s"' 'key' "$LONGVAL")" \
           "api_key = \"$ASSIGNED\""
fx deny    "assigned literal, mixed case (flag i)" "$(printf 'Api_%s: %s' 'Key' "$LONGVAL")"
fx deny    "assigned literal, placeholder word in the name only" "$(printf 'SECRET_DUMMY_%s=%s' 'KEY' "$LONGVAL")"
fx deny    "assigned literal with base64 padding" "$(printf 'PASSWORD=%s==' "$LONGVAL")"
fx deny    "assigned value masked through its !tail, name kept" "$(printf 'DB_PASS%s=%s!tail rest' 'WORD' "$LONGVAL")" \
           "DB_PASSWORD=$ASSIGNED rest"
fx deny    "quoted assigned value masked through its closing quote" "$(printf 'PASS%s="%s more words" rest' 'WORD' "$LONGVAL")" \
           "PASSWORD=\"$ASSIGNED\" rest"
fx deny    "quoted assigned value with no closing quote masked to the line end" "$(printf 'PASS%s="%s more words\nnext' 'WORD' "$LONGVAL")" \
           "PASSWORD=\"$ASSIGNED
next"
fx deny    "AWS key inside an assigned value (overlapping matches merge)" "password=${AWS}1234567890xyz" \
           "password=[REDACTED:an AWS access key ID, an assigned secret literal]"
fx deny    "two real keys on one line"            "a = \"$AWS\"; b = \"$AWS2\""
fx deny    "placeholder key, then a real one"     "a = \"$AWS_DOC\"; b = \"$AWS\""
fx deny    "multi-line text, key on line three"   "$(printf 'line one\nline two\nkey = %s\nline four' "$AWS")"
fx deny    "two kinds, the later row first in the text" "$(printf 'gh auth: %s\nkey = %s' "$GH" "$AWS")"
fx deny    "CRLF lines, assigned literal on the second" "line one${CR}
API_KEY=$LONGVAL${CR}
line three" "line one${CR}
API_KEY=$ASSIGNED${CR}
line three"
fx deny    "private key with its body, masked through END" "$PKEY
$KEY_BODY
-----END RSA PRIVATE KEY-----
after" "[REDACTED:a private key block]
after"
fx deny    "private key with no END, masked to the end of the text" "before
$PKEY
$KEY_BODY
$KEY_BODY" "before
[REDACTED:a private key block]"
fx deny    "space-flattened key on one line, masked through its END" "KEY=$PKEY $KEY_BODY $KEY_BODY -----END RSA PRIVATE KEY----- # prod" \
           "KEY=[REDACTED:a private key block] # prod"
fx deny    "private key body, then prose: the block closes at the prose" "$PKEY
$KEY_BODY
$KEY_BODY

This key is for staging only." "[REDACTED:a private key block]

This key is for staging only."
fx deny    "encrypted key headers and body with no END, then prose" "$PKEY
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,0A1B2C3D4E5F60718293A4B5C6D7E8F9

$KEY_BODY
rotate it tomorrow" "[REDACTED:a private key block]
rotate it tomorrow"
fx deny    "CRLF key body with no END, then prose" "$PKEY${CR}
$KEY_BODY${CR}
see the runbook${CR}
" "[REDACTED:a private key block]${CR}
see the runbook${CR}
"
fx deny    "BEGIN literal in a code line, then code: only the marker masked" "if (pem.startsWith('$PKEY')) {
  return parse(pem)
}" "if (pem.startsWith('[REDACTED:a private key block]')) {
  return parse(pem)
}"
fx deny    "one-line JSON private_key with no END: the closing quote ends the block" \
           "{\"private_key\": \"$PKEY8\\n$KEY_BODY\\n$KEY_BODY\", \"client_email\": \"svc@x.iam\"}" \
           "{\"private_key\": \"[REDACTED:a private key block]\", \"client_email\": \"svc@x.iam\"}"
fx deny    "one-line JSON private_key with escaped newlines" \
           "{\"private_key\": \"$PKEY8\\n$KEY_BODY\\n-----END PRIVATE KEY-----\\n\", \"client_email\": \"svc@x.iam\"}" \
           "{\"private_key\": \"[REDACTED:a private key block]\\n\", \"client_email\": \"svc@x.iam\"}"
fx deny    "CR inside a Slack webhook tail"       "${WEBHOOK}abcdefgh${CR}ijklmnopqrstuvwx"
fx deny    "U+017F in an assigned name (grep -i folds it into s)" "${LONG_S}ecret=$LONGVAL" "${LONG_S}ecret=$ASSIGNED"
fx deny    "U+0131 in an assigned name (grep -i folds it into i)" "ap${DOTLESS_I}_key=$LONGVAL"
fx deny    "placeholder word spelled with U+017F (the placeholder grep runs under LC_ALL=C)" \
           "$(printf 'postgres://u:%s@db/app' "${LONG_S}ample123456")"
fx allow   "U+212A in an assigned name (grep -i does not fold it into k)" "to${KELVIN}en=$LONGVAL"
fx allow   "AWS doc key (EXAMPLE suffix)"         "aws_ref = \"$AWS_DOC\""
fx allow   "changeme value (word list)"           "$(printf 'API_%s=changeme_changeme_changeme_now' 'KEY')"
fx allow   "your- value"                          "$(printf 'API_%s=your-api-key-goes-here-1234567890' 'KEY')"
fx allow   "single distinct character value"      "$(printf 'PASSWORD = "%s"' '00000000000000000000000000000000')"
fx allow   "ghp_ of x's"                          "$(printf 'gh%s_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' 'p')"
fx allow   "changeme password in a URL"           'DATABASE_URL=postgres://user:changeme@localhost/db'
fx allow   "lowercased AKIA (case-sensitive row)" "$(printf 'x = "akia%s"' 'abcdefghijklmnop')"
fx allow   "GitHub token one character short"     "$(printf 'gh%s_%s' 'p' 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')"
fx allow   "camelCase name holding a keyword"     'tokenizerConfig = "aVeryLongConfigValue1234567890"'
fx allow   "short assigned value"                 'pw = "hunter2"'
fx allow   "URL with a space in the password"     "$(printf 'postgres://admin:%s@db/app' 'Sup3r S3cretVal')"
fx allow   "URL with a \${VAR} password"          'DATABASE_URL=postgres://admin:${DB_PASS}@db/app'
fx allow   "URL credential split across lines"    "$(printf 'https://svc\nfoo:%s@api.example.com' 'Gk39dkLwq2x')"
fx allow   "empty text"                           ''
fx diverge "astral characters in a Slack webhook tail (UTF-8 grep counts code points, JavaScript UTF-16 units)" \
           "${WEBHOOK}$EMOJI$EMOJI$EMOJI$EMOJI$EMOJI$EMOJI$EMOJI$EMOJI" "core:a Slack webhook URL"
fx diverge "NUL inside an AWS key (bash drops NUL before grep reads the text)" "k = AKIA<NUL>ABCDEFGHIJKLMNOP" \
           "scan:an AWS access key ID"

payload() { jq -cn --arg c "$1" '{tool_name:"Write", tool_input:{file_path:"/tmp/parity.txt", content:($c | gsub("<NUL>"; "\u0000"))}}'; }
scan() { # scan <payload> [hook] -> allow, or deny TAB the label the deny names (or why the pattern file is unusable)
  local out r
  out=$(printf '%s' "$1" | bash "${2:-$HOOK}")
  [ -n "$out" ] || { printf 'allow'; return; }
  r=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out")
  case $r in
    *"is unusable ("*) r=${r#*is unusable (}; r=${r%%), so this write*} ;;
    *) r=${r#*this write appears to contain }; r=${r%%. Blocked before it reaches disk.*} ;;
  esac
  printf 'deny\t%s' "$r"
}

CORE_REDACT='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parsePatterns, redact } = await import(pathToFileURL(process.argv[1]).href)
const pats = parsePatterns(readFileSync(process.argv[2], "utf8"))
for (const line of readFileSync(0, "utf8").split("\n").filter(Boolean)) {
  const { value, labels } = redact(JSON.parse(line).tool_input.content, pats)
  console.log(JSON.stringify({ labels, value }))
}'
payloads=()
for t in "${texts[@]}"; do payloads+=("$(payload "$t")"); done
if ! core_out=$(printf '%s\n' "${payloads[@]}" | node --input-type=module -e "$CORE_REDACT" "$CORE" "$PAT" 2>"$TMP/err"); then
  echo "FAIL: node could not run redact-core.ts: $(cat "$TMP/err")"; exit 1
fi
mapfile -t core <<<"$core_out"
[ "${#core[@]}" -eq "${#texts[@]}" ] || { echo "FAIL: redact-core answered ${#core[@]} of ${#texts[@]} fixtures"; exit 1; }

for i in "${!texts[@]}"; do
  n=${names[$i]}; want=${wants[$i]}; extra=${extras[$i]}
  IFS=$'\t' read -r sv slabel <<<"$(scan "${payloads[$i]}")"
  clabel=$(jq -r '.labels[0] // empty' <<<"${core[$i]}")
  cv=allow; [ -n "$clabel" ] && cv=deny
  if [ "$want" = diverge ]; then
    side=${extra%%:*}; label=${extra#*:}
    if { [ "$side" = scan ] && [ "$sv/$slabel/$cv" = "deny/$label/allow" ]; } || { [ "$side" = core ] && [ "$cv/$clabel/$sv" = "deny/$label/allow" ]; }; then
      diverged=$((diverged + 1)); echo "divergence (documented): $n — only $side flags ($label)"
    elif [ "$sv" = "$cv" ]; then
      offcase=$((offcase + 1)); echo "FAIL $n: documented divergence did not reproduce, both sides $sv"
    else
      mismatch=$((mismatch + 1)); echo "FAIL $n: expected only $side to flag ($label), got scan.sh $sv${slabel:+ ($slabel)}, redact-core $cv${clabel:+ ($clabel)}"
    fi
    continue
  fi
  if [ "$sv" != "$cv" ]; then
    mismatch=$((mismatch + 1)); echo "FAIL $n: scan.sh $sv${slabel:+ ($slabel)}, redact-core $cv${clabel:+ ($clabel)}"
  elif [ "$sv" = deny ] && [ "$slabel" != "$clabel" ]; then
    mismatch=$((mismatch + 1)); echo "FAIL $n: scan.sh names $slabel, redact-core $clabel"
  elif [ "$sv" != "$want" ]; then
    offcase=$((offcase + 1)); echo "FAIL $n: both sides $sv, the fixture expects $want"
  fi
  if [ -n "$extra" ] && ! jq -e --arg want "$extra" '.value == $want' <<<"${core[$i]}" >/dev/null; then
    offcase=$((offcase + 1)); echo "FAIL $n: redacted text $(jq -c .value <<<"${core[$i]}"), expected $(jq -cn --arg w "$extra" '$w')"
  fi
  if [ "$cv" = deny ]; then
    IFS=$'\t' read -r rv rlabel <<<"$(scan "$(jq -c '{tool_name:"Write", tool_input:{file_path:"/tmp/parity.txt", content:.value}}' <<<"${core[$i]}")")"
    [ "$rv" = allow ] || { mismatch=$((mismatch + 1)); echo "FAIL $n: scan.sh denies redact-core's redacted text ($rlabel)"; }
  fi
done

CORE_WALK='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parsePatterns, redact } = await import(pathToFileURL(process.argv[1]).href)
const pats = parsePatterns(readFileSync(process.argv[2], "utf8"))
const key = process.argv[3]
const mask = "[REDACTED:an AWS access key ID]"
const error = new Error(`boom ${key}`, { cause: `cause ${key}` })
error.stderr = `stderr ${key}`
const map = new Map([["k", key]])
const bare = Object.assign(Object.create(null), { note: key })
const { value } = redact({ list: [key], error, map, bare, [key]: "kept" }, pats)
const pem = "-----BEGIN RSA PRIVATE " + "KEY-----"
const body = "MIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu"
const block = "[REDACTED:a private key block]"
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const blocks = texts => texts.map(text => ({ type: "text", text }))
const checks = {
  "array string masked": value.list[0] === mask,
  "Error copy keeps its prototype": value.error instanceof Error,
  "Error message masked": value.error.message === `boom ${mask}`,
  "Error stack carried and masked": value.error.stack === error.stack.replaceAll(key, mask),
  "Error cause masked": value.error.cause === `cause ${mask}`,
  "Error own enumerable property masked": value.error.stderr === `stderr ${mask}` && Object.keys(value.error).includes("stderr"),
  "input Error untouched": error.message === `boom ${key}`,
  "Map passes through as received": value.map === map && map.get("k") === key,
  "null-prototype object walked, prototype kept": Object.getPrototypeOf(value.bare) === null && value.bare.note === mask,
  "keys stay unredacted": value[key] === "kept",
  "key block split across array strings masked through its END":
    same(redact([pem, body, "-----END RSA PRIVATE KEY----- tail", "after"], pats).value, [block, block, `${block} tail`, "after"]),
  "an open block passes over a non-string element and closes at the first non-PEM string":
    same(redact(["before", pem, body, 7, body, "Done.", body], pats).value, ["before", block, block, 7, block, "Done.", body]),
  "MCP content blocks carry a key block through END at .text only":
    same(redact(blocks([pem, body, "-----END RSA PRIVATE KEY-----"]), pats).value, blocks([block, block, block])),
  "a carried block masks a space-flattened body through the END in the next element":
    same(redact(blocks([pem, `${body} ${body} -----END RSA PRIVATE KEY----- done`]), pats).value, blocks([block, `${block} done`])),
  "MCP content blocks with no END close at the first non-PEM text":
    same(redact({ content: blocks([pem, body, body, "Rotated on Monday."]) }, pats).value,
      { content: blocks([block, block, block, "Rotated on Monday."]) }),
  "nbformat source lines carry a key block until the code line":
    same(redact({ cell_type: "code", source: [`${pem}\n`, `${body}\n`, `${body}\n`, "print(1)\n"] }, pats).value,
      { cell_type: "code", source: [`${block}\n`, `${block}\n`, `${block}\n`, "print(1)\n"] }),
  "nested arrays carry a key block at the same [j] only":
    same(redact([["x = 1;", pem], ["y = 2;", body], ["z = 3;", "Done."]], pats).value,
      [["x = 1;", block], ["y = 2;", block], ["z = 3;", "Done."]]),
  "a moved lastIndex on an exported Pattern skips no match":
    (() => { pats.forEach(p => { p.re.lastIndex = 50 }); return redact(`${key} ${key}`, pats).value === `${mask} ${mask}` })(),
}
for (const [name, ok] of Object.entries(checks)) if (!ok) console.log(name)'
while IFS= read -r broken; do
  [ -n "$broken" ] && { offcase=$((offcase + 1)); echo "FAIL redact walk: $broken"; }
done < <(node --input-type=module -e "$CORE_WALK" "$CORE" "$PAT" "$AWS" 2>&1)

CORE_TIME='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parsePatterns, redact } = await import(pathToFileURL(process.argv[1]).href)
const pats = parsePatterns(readFileSync(process.argv[2], "utf8"))
const line = "token-".repeat(50000)
const start = performance.now()
redact(line, pats)
console.log(Math.round(performance.now() - start))'
ms=$(node --input-type=module -e "$CORE_TIME" "$CORE" "$PAT" 2>&1)
if [[ $ms =~ ^[0-9]+$ ]] && [ "$ms" -lt "$BOUND_MS" ]; then
  echo "timing: redact on a 300 kB token- line took $ms ms (bound $BOUND_MS ms)"
else
  slow=1; echo "FAIL timing: redact on a 300 kB token- line took ${ms} ms, bound $BOUND_MS ms"
fi

T=$'\t'; LAST="line $(( $(wc -l < "$PAT") + 1 ))"
bad=(); expect=()
for row in "secret${T}x${T}-" "secrets${T}x${T}-${T}abc" "secret${T}x${T}I${T}abc" "secret${T}x${T}-${T}" \
           "secret${T}x${T}-${T}abc " "secret${T}x${T}-${T}a[[:digit:]]b" "secret${T}x${T}-${T}[^@[:space:]]+" \
           "secret${T}x${T}-${T}(ab)\\1" "secret${T}x${T}-${T}ab(?=cd)" "secret${T}x${T}-${T}x\\d+" \
           "secret${T}x${T}-${T}sk_[0-9a-z{24,}" "secret${T}x${T}-${T}a*" "placeholder${T}x${T}i${T}example|..."; do
  { cat "$PAT"; printf '%s\n' "$row"; } > "$TMP/bad-${#bad[@]}.tsv"; bad+=("$TMP/bad-${#bad[@]}.tsv"); expect+=("$LAST")
done
sed 's/$/\r/' "$PAT" > "$TMP/bad-crlf.tsv"; bad+=("$TMP/bad-crlf.tsv"); expect+=("line 1")
grep -v "^secret$T" "$PAT" > "$TMP/bad-nosecret.tsv"; bad+=("$TMP/bad-nosecret.tsv"); expect+=("no secret row")

CORE_PARSE='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parsePatterns } = await import(pathToFileURL(process.argv[1]).href)
for (const path of process.argv.slice(2)) {
  try { parsePatterns(readFileSync(path, "utf8")); console.log("accepted") } catch (e) { console.log(e.message) }
}'
mapfile -t parsed < <(node --input-type=module -e "$CORE_PARSE" "$CORE" "${bad[@]}" 2>&1)
mkdir "$TMP/hook"; cp "$HOOK" "$TMP/hook/scan.sh"
CLEAN=$(payload 'const x = 1;')
where() { [[ $1 =~ ^(line\ [0-9]+) ]] && printf '%s' "${BASH_REMATCH[1]}" || printf '%s' "$1"; }
for i in "${!bad[@]}"; do
  cp "${bad[$i]}" "$TMP/hook/patterns.tsv"
  IFS=$'\t' read -r sv sreason <<<"$(scan "$CLEAN" "$TMP/hook/scan.sh")"
  skey=accepted; [ "$sv" = deny ] && skey=$(where "$sreason")
  ckey=$(where "${parsed[$i]:-}")
  if [ "$skey" != "$ckey" ]; then
    mismatch=$((mismatch + 1)); echo "FAIL malformed ${bad[$i]##*/}: scan.sh ${sreason:-accepts it}, parsePatterns ${parsed[$i]:-<no answer>}"
  elif [ "$skey" != "${expect[$i]}" ]; then
    offcase=$((offcase + 1)); echo "FAIL malformed ${bad[$i]##*/}: both sides reject at $skey, the fixture expects ${expect[$i]}"
  fi
done

echo "pattern parity: ${#texts[@]} fixtures, ${#bad[@]} malformed pattern files, $diverged documented divergences;" \
     "$mismatch disagreements, $offcase off expectation, $slow over the time bound"
echo "parity: $((mismatch + offcase + slow)) mismatches"
exit $(( mismatch + offcase + slow > 0 ))
