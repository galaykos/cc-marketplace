#!/usr/bin/env bash
# Fixture tests for hooks/write-scan.sh — each warn pattern proven to warn once,
# dedup proven, clean/off/malformed inputs proven silent.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/write-scan.sh"
export TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
pass=0; fail=0
n=0

run() { # run <session> <tool> <content>
  jq -cn --arg s "$1" --arg t "$2" --arg c "$3" \
    '{tool_name:$t, session_id:$s, tool_input:{file_path:"/tmp/f.php", content:$c}}' | bash "$HOOK"
}

warns() { # warns <name> <content> <expect-slug>
  n=$((n+1)); out=$(run "s$n" Write "$2")
  if grep -q "$3" <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: expected [$3], got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
silent() { # silent <name> <session> <tool> <content>
  out=$(run "$2" "$3" "$4")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $1: expected silence, got: $out"; fail=$((fail+1)); fi
}

warns "empty guarded"      'protected $guarded = [];'                        "mass-assignment-open"
warns "blade unescaped"    '<div>{!! $user->bio !!}</div>'                   "blade-unescaped"
warns "vite secret"        'VITE_STRIPE_SECRET=sk_test_x'                    "vite-client-secret"
warns "whereRaw interp"    '->whereRaw("id = {$id}")'                        "raw-sql-interpolation"
warns "whereRaw concat"    "->whereRaw('id = ' . \$id)"                      "raw-sql-interpolation"
warns "raw html sink"      '<div dangerouslySetInnerHTML={{__html: bio}} />' "raw-html-sink"

# ---- ported stack-agnostic sinks, each gated to its language --------------------------
runf() { # runf <session> <file_path> <content>
  jq -cn --arg s "$1" --arg f "$2" --arg c "$3" \
    '{tool_name:"Write", session_id:$s, tool_input:{file_path:$f, content:$c}}' | bash "$HOOK"
}
warnsf() { # warnsf <name> <file_path> <content> <expect-slug>
  n=$((n+1)); out=$(runf "f$n" "$2" "$3")
  if grep -q "$4" <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: expected [$4], got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
silentf() { # silentf <name> <file_path> <content>
  n=$((n+1)); out=$(runf "q$n" "$2" "$3")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $1: expected silence, got: $out"; fail=$((fail+1)); fi
}
warnsf "innerHTML"          /tmp/a.js  'el.innerHTML = user.bio'                          "raw-html-sink"
warnsf "insertAdjacentHTML" /tmp/a.ts  'el.insertAdjacentHTML("beforeend", html)'         "raw-html-sink"
warnsf "js eval"            /tmp/a.js  'const v = eval(input)'                            "code-eval"
warnsf "php eval"           /tmp/a.php 'eval($code);'                                     "code-eval"
warnsf "new Function"       /tmp/a.ts  'const fn = new Function("a", body)'               "code-eval"
silentf "eval in README"    /tmp/R.md  'never call eval(input) on user data'
silentf "model.eval()"      /tmp/t.py  'model.eval()'
warnsf "child_process"      /tmp/a.js  'child_process.exec(`ls ${dir}`)'                  "shell-string-exec"
warnsf "execSync"           /tmp/a.mjs 'execSync("git " + args)'                          "shell-string-exec"
warnsf "php shell_exec"     /tmp/a.php 'shell_exec("ls " . $dir);'                        "shell-string-exec"
warnsf "php exec var"       /tmp/a.php 'exec($cmd, $out);'                                "shell-string-exec"
warnsf "os.system"          /tmp/a.py  'os.system("rm " + path)'                          "shell-string-exec"
warnsf "subprocess shell"   /tmp/a.py  'subprocess.run(cmd, shell=True)'                  "shell-string-exec"
silentf "execFile array"    /tmp/a.js  'execFile("git", ["status"])'
silentf "subprocess list"   /tmp/a.py  'subprocess.run(["ls", path])'
warnsf "pickle.load"        /tmp/a.py  'data = pickle.load(f)'                            "unsafe-deserialization"
warnsf "pandas read_pickle" /tmp/a.py  'df = pd.read_pickle(path)'                        "unsafe-deserialization"
warnsf "php unserialize"    /tmp/a.php '$o = unserialize($_COOKIE["u"]);'                 "unsafe-deserialization"
warnsf "yaml.load bare"     /tmp/a.py  'cfg = yaml.load(f)'                               "unsafe-yaml-load"
silentf "yaml.load Safe"    /tmp/a.py  'cfg = yaml.load(f, Loader=yaml.SafeLoader)'
silentf "yaml.safe_load"    /tmp/a.py  'cfg = yaml.safe_load(f)'
warnsf "torch.load"         /tmp/a.py  'm = torch.load(p)'                                "torch-unsafe-load"
silentf "torch weights"     /tmp/a.py  'm = torch.load(p, weights_only=True)'
warnsf "ElementTree"        /tmp/a.py  'root = ET.fromstring(body)'                       "xml-external-entities"
warnsf "php LIBXML_NOENT"   /tmp/a.php '$d->loadXML($x, LIBXML_NOENT);'                   "xml-external-entities"
warnsf "requests verify"    /tmp/a.py  'requests.get(url, verify=False)'                  "tls-verify-off"
warnsf "node reject"        /tmp/a.js  'https.request({rejectUnauthorized: false})'       "tls-verify-off"
warnsf "guzzle verify"      /tmp/a.php '$c->get($u, ["verify" => false]);'                "tls-verify-off"
warnsf "curl verifypeer"    /tmp/a.php 'curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);' "tls-verify-off"
warnsf "aes ecb"            /tmp/a.py  'AES.new(k, AES.MODE_ECB)'                         "weak-cipher-mode"
warnsf "createCipher"       /tmp/a.js  'crypto.createCipher("aes256", key)'               "weak-cipher-mode"
silentf "createCipheriv"    /tmp/a.js  'crypto.createCipheriv("aes-256-gcm", key, iv)'
warnsf "script no sri"      /tmp/a.html '<script src="https://cdn.x/lib.js"></script>'    "script-without-sri"
silentf "script with sri"   /tmp/a.html '<script src="https://cdn.x/lib.js" integrity="sha384-abc" crossorigin="anonymous"></script>'
silentf "script in .md"     /tmp/a.md   '<script src="https://cdn.x/lib.js"></script>'

# ---- LLM sinks, ported from llm-app's prompt-injection rule; JS/TS/PY/PHP gated ------
warnsf "sys interp ts"      /tmp/a.ts  '{ role: "system", content: `You are a helper for ${user.name}` }' "prompt-interpolation"
warnsf "sys key ts"         /tmp/a.ts  'system: `You are ${persona}. Answer briefly.`,'            "prompt-interpolation"
warnsf "sys fstring py"     /tmp/a.py  'system=f"You are {persona}. Answer briefly."'              "prompt-interpolation"
warnsf "sys concat py"      /tmp/a.py  '{"role": "system", "content": "You are " + persona}'      "prompt-interpolation"
warnsf "sys format py"      /tmp/a.py  '{"role": "system", "content": "You are {}".format(who)}'  "prompt-interpolation"
warnsf "sys concat php"     /tmp/a.php "['role' => 'system', 'content' => \"You are \" . \$who]," "prompt-interpolation"
silentf "sys in .md"        /tmp/a.md  'system: `You are ${persona}`'
silentf "sys constant ts"   /tmp/a.ts  '{ role: "system", content: SYSTEM_PROMPT }'
silentf "sys literal py"    /tmp/a.py  '{"role": "system", "content": "You are a helpful assistant."}'
silentf "user turn interp"  /tmp/a.ts  '{ role: "user", content: `Question: ${q}` }'
silentf "sys type only"     /tmp/a.ts  'system: string;'
silentf "sys equality"      /tmp/a.py  'if system == "linux" + suffix:'
warnsf "eval completion ts" /tmp/a.ts  'eval(completion.choices[0].message.content)'               "llm-output-exec"
warnsf "new Function msg"   /tmp/a.ts  'const fn = new Function(msg.content)'                      "llm-output-exec"
warnsf "exec choices py"    /tmp/a.py  'exec(response.choices[0].message.content)'                 "llm-output-exec"
warnsf "subprocess text py" /tmp/a.py  'subprocess.run(reply.text, shell=True)'                    "llm-output-exec"
warnsf "os.system message"  /tmp/a.py  'os.system(message)'                                        "llm-output-exec"
warnsf "shell_exec php"     /tmp/a.php 'shell_exec($response->content);'                           "llm-output-exec"
silentf "exec in .md"       /tmp/a.md  'never eval(completion.choices[0].message.content)'
silentf "log completion"    /tmp/a.ts  'console.log(completion.choices[0].message.content)'
silentf "parse content py"  /tmp/a.py  'data = json.loads(response.choices[0].message.content)'
silentf "regex exec ts"     /tmp/a.ts  'const m = pattern.exec(message.content)'
notslug() { # notslug <name> <file_path> <content> <slug-that-must-NOT-fire> — a sibling may
  n=$((n+1)); out=$(runf "z$n" "$2" "$3")
  if ! grep -q "$4" <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: [$4] must not fire, got: $out"; fail=$((fail+1)); fi
}
notslug "php mail message"  /tmp/a.php 'exec("mail " . $message);'                                 "llm-output-exec"
warnsf "chunks template ts" /tmp/a.ts  'const prompt = `Answer using: ${chunks}\nQ: ${q}`'         "tool-result-unfenced"
warnsf "docs concat ts"     /tmp/a.ts  'messages.push({ role: "user", content: "Docs: " + documents })' "tool-result-unfenced"
warnsf "retrieved fstr py"  /tmp/a.py  'prompt = f"Context: {retrieved_text}\nQuestion: {q}"'      "tool-result-unfenced"
warnsf "chunks join py"     /tmp/a.py  'prompt = "Context:\n" + "\n".join(chunks) + "\nQ: " + q'  "tool-result-unfenced"
warnsf "tool_result pct py" /tmp/a.py  '{"role": "user", "content": "Result: %s" % tool_result}'  "tool-result-unfenced"
warnsf "toolResult php"     /tmp/a.php "\$prompt = \"Context: \" . \$toolResult . \"\\nQ: \" . \$q;" "tool-result-unfenced"
silentf "chunks in .md"     /tmp/a.md  'const prompt = `Answer using: ${chunks}`'
silentf "fenced document"   /tmp/a.ts  'const prompt = `Answer using:\n<document>${chunks}</document>\nQ: ${q}`'
silentf "fenced hr"         /tmp/a.ts  'const prompt = `---\n${chunks}\n---\nQ: ${q}`'
silentf "fenced <<<"        /tmp/a.py  'prompt = "Context:\n<<<\n" + "\n".join(chunks) + "\n>>>\nQ: " + q'
silentf "fenced BEGIN"      /tmp/a.py  'prompt = f"[BEGIN DATA]{tool_result}[END DATA]"'
silentf "fenced triple"     /tmp/a.py  'prompt = f"""Context:\n{retrieved_text}\n"""'
silentf "chunks no prompt"  /tmp/a.ts  'const context = chunks.map(c => c.text).join("\n")'
silentf "chunks as arg"     /tmp/a.py  'prompt = build_prompt(chunks, question)'
silentf "content is var"    /tmp/a.ts  'messages.push({ role: "user", content: chunks })'

# Dedup: same session + file + finding warns once.
out1=$(run dedup Write 'protected $guarded = [];')
out2=$(run dedup Write 'protected $guarded = [];')
if [[ -n "$out1" && -z "$out2" ]]; then pass=$((pass+1));
else echo "FAIL dedup: first='${out1:0:40}' second='${out2:0:40}'"; fail=$((fail+1)); fi

silent "clean file"      sc Write 'const a = 1;'
out=$(jq -cn --arg c 'protected $guarded = [];' \
  '{tool_name:"Write", session_id:"soff", tool_input:{file_path:"/tmp/f.php", content:$c}}' \
  | CC_SECURITY_SCAN=off bash "$HOOK")
if [[ -z "$out" ]]; then pass=$((pass+1)); else echo "FAIL off-switch: $out"; fail=$((fail+1)); fi
# Same payload with the switch ON must warn — proves the off test tested the switch.
out=$(jq -cn --arg c 'protected $guarded = [];' \
  '{tool_name:"Write", session_id:"son", tool_input:{file_path:"/tmp/f.php", content:$c}}' | bash "$HOOK")
if grep -q "mass-assignment-open" <<<"$out"; then pass=$((pass+1));
else echo "FAIL on-control: ${out:-<empty>}"; fail=$((fail+1)); fi
silent "non-write tool"  sn Bash  'protected $guarded = [];'
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL fail-open: rc=$rc out=$out"; fail=$((fail+1)); fi

# ---- the payload the host actually sends ---------------------------------------------
# Every case above sends session_id only, so they graded the FALLBACK branch of
# `.transcript_path // .session_id`. This hook puts that value in the lock path as a
# DIRECTORY component, and an absolute transcript path is only survivable there because
# of the `mkdir -p "$(dirname "$lock")"` on the next line. That one line is the whole
# safety margin and nothing exercised it. Three sibling hooks that lacked the equivalent
# shipped broken behind a green suite. Gated by pc_harness_payload.
TP='/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl'
tprun() { # tprun <content>
  jq -cn --arg c "$1" --arg t "$TP" \
    '{tool_name:"Write", session_id:"11111111-2222-3333-4444-555555555555", transcript_path:$t,
      tool_input:{file_path:"/tmp/tp.php", content:$c}}' | bash "$HOOK"
}
DIRTY='<?php class M extends Model { protected $guarded = []; }'
out=$(tprun "$DIRTY")
if grep -q 'mass-assignment-open' <<<"$out"; then pass=$((pass+1)); echo "PASS transcript_path: the hook still warns"
else echo "FAIL transcript_path: went silent — the lock path swallowed the key. got: ${out:-<empty>}"; fail=$((fail+1)); fi

out2=$(tprun "$DIRTY")
if [ -z "$out2" ]; then pass=$((pass+1)); echo "PASS transcript_path: dedup still holds on the second write"
else echo "FAIL transcript_path: warned twice, dedup dead: $out2"; fail=$((fail+1)); fi

# Scoped to THIS run's key, not any lock dir: the transcript path is absolute, so if the
# mkdir -p rescue works the path's own leading segments appear under cc-security-scan.
# A bare `find -name '*_*'` would have passed on locks left by the session_id cases above,
# which is a green assertion that proves nothing.
if [ -d "$TMPDIR/cc-security-scan/Users/x/.claude/projects" ]; then
  pass=$((pass+1)); echo "PASS transcript_path: mkdir -p \$(dirname) rescued the nested path"
else echo "FAIL transcript_path: nested lock path never created"; fail=$((fail+1)); fi

echo "write-scan tests: $pass passed, $fail failed"
exit $((fail > 0))
