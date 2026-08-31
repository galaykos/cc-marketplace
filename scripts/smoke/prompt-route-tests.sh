#!/usr/bin/env bash
# scripts/smoke/prompt-route-tests.sh
#
# The skill-router's tool-fit check (hooks/route-prompt.sh).
#
# SCOPE, stated up front so nobody reads this harness as more than it is: the hook
# does not choose a command. It builds the catalog of installed commands and injects
# the rules for judging; the routing verdict is the MODEL's, and a judgment cannot be
# asserted by a shell test. What is gated here is the mechanism around the judgment —
# that the catalog is built, correct, and installed-scoped; that the directive carries
# the discipline that keeps it from nagging; that every guard silences the hook; that
# it costs its tokens once per session. Which command the model then picks is
# agent-graded, per CLAUDE.md's has-teeth convention. Do not add a test here that
# claims otherwise.
#
# Half B covers the two validate.sh gates that keep the mechanism honest: no literal
# command token in the hook, and no second routing pattern growing back in shell.
#
# Half C is the reminder hooks, not this one, and is here because it is the other
# half of a single change: the work-shaped gate was widened to let symptom phrasing
# through, and a moment nothing owns is not worth reaching.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$ROOT" || exit 2
BASH_BIN="$(command -v bash)"

SR="plugins/skill-router"
HOOK="$ROOT/$SR/hooks/route-prompt.sh"
[ -f "$HOOK" ] || { printf 'prompt-route-tests: no %s\n' "$HOOK" >&2; exit 2; }

WORK="$(mktemp -d)" || exit 2
HB="$WORK/route-prompt.sh.bak"
cp "$HOOK" "$HB" || exit 2
cleanup() {
  [ -f "$HB" ] && cp "$HB" "$HOOK"
  if [ -f "$HB" ] && ! cmp -s "$HB" "$HOOK"; then
    printf 'FAIL  %s not restored\n' "$HOOK"; rm -rf "$WORK"; exit 1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM HUP

rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf mkdir find cksum; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'prompt-route-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

# Every call needs its OWN session id and TMPDIR: the hook injects once per session,
# so a shared session would silence every case after the first. The counter lives in a
# FILE, not a variable — run_hook is called inside $( ), and a variable incremented in a
# subshell never reaches the parent (which is exactly how the first draft of this
# harness reported three false silences).
COUNTER="$WORK/n"; printf '0' > "$COUNTER"
run_hook() { # run_hook <prompt> <root> [env...] -> hook stdout
  local prompt="$1" root="$2"; shift 2
  local n; n=$(( $(cat "$COUNTER") + 1 )); printf '%s' "$n" > "$COUNTER"
  local box="$WORK/box-$n"; mkdir -p "$box"
  # HOST-SHAPED PAYLOAD: transcript_path is sent, and it is load-bearing.
  # route-prompt.sh keys its pending-signal flush on `.transcript_path //
  # .session_id` — the same key route.sh writes — so a payload carrying only
  # session_id grades the FALLBACK branch and this harness would report green on
  # a hook that never finds its state file. That is exactly how the writer/reader
  # key mismatch shipped: every assertion here passed while the flush was dead.
  # `pc_harness_payload` fails this file if the field goes away again.
  local tp="$box/transcript-sess-$n.jsonl"; : > "$tp"
  printf '%s' "$prompt" | jq -Rs --arg s "sess-$n" --arg tp "$tp" \
      '{prompt:., session_id:$s, transcript_path:$tp}' \
    | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$root" "$@" "$BASH_BIN" "$HOOK" 2>/dev/null
}

want_fires() { # desc  prompt
  local out; out="$(run_hook "$2" "$ROOT/$SR")"
  [ -n "$out" ] && pass "$1" || fail "$1" "wanted the catalog, hook stayed silent"
}
want_silent() { # desc  prompt  [env...]
  local desc="$1" prompt="$2"; shift 2
  local out; out="$(run_hook "$prompt" "$ROOT/$SR" "$@")"
  [ -z "$out" ] && pass "$desc" || fail "$desc" "wanted silence, spoke ${#out} bytes"
}

printf '== half A: when it fires ==\n'
want_fires "work-shaped: build"    "build a landing page for a B2B marketing agency"
want_fires "work-shaped: fix"      "fix the crash on checkout submit"
want_fires "work-shaped: review"   "review my diff before I push"
want_fires "names a tool"          "run taskmaster: create a marketing landing page"

# SYMPTOM PHRASING. Nine realistic incident prompts were run against the gate as it
# stood; these seven were dropped and only `fix …` / `debug …` got through. Asserted
# one by one, not as a batch: a batch that goes red names none of the phrasings that
# regressed, and each of these is a different shape (question, state, status code,
# comparative, past tense, imperative, adverb-tailed).
want_fires "symptom: why is … broken" "why is the checkout page broken"
want_fires "symptom: is down"         "production is down"
want_fires "symptom: 500s"            "users are seeing 500s on login"
want_fires "symptom: got slow"        "this query got really slow after the last release"
want_fires "symptom: regressed"       "something regressed in the cart total"
want_fires "symptom: investigate"     "investigate the memory leak"
want_fires "symptom: keeps failing"   "the payment webhook keeps failing intermittently"
# The weak tier must still reach real symptoms after the state-verb bound below.
want_fires "weak tier: are failing"   "the tests are failing on CI"
want_fires "weak tier: went down"     "the site went down after the deploy"
want_fires "weak tier: am stuck"      "i am stuck on this migration"

printf '== half A: guards ==\n'
want_silent "not work-shaped"     "what time does the standup start"
# THE OTHER DIRECTION, and the reason it exists: the symptom tier above was first
# written with `down`, `slow`, `broken`, `leak` and `stuck` matching bare, which
# made `scroll down and tell me what you see` and `the meeting ran slow today`
# work-shaped. A regex matching everything passes every want_fires above, so a
# gate asserted in one direction only is half-asserted. These pin the state-verb
# bound: each carries a weak token with NO state verb in front of it.
want_silent "weak tier: scroll down"  "scroll down and tell me what you see"
want_silent "weak tier: ran slow"     "the meeting ran slow today"
want_silent "weak tier: slow down"    "lets slow down and talk about scope first"
want_silent "chat: acknowledgement"   "thanks, that looks good"
want_silent "chat: question about code" "what does this function do"
want_silent "chat: question about history" "who wrote this file"
want_silent "slash prompt"        "/taskmaster:task build a landing page"
want_silent "meta: about the hook" "disable the router hook that injects the catalog"
want_silent "own output echoed"   "[skill-router] Tool-fit check (once this session)."
want_silent "CC_ROUTE=off"        "build a landing page" CC_ROUTE=off
want_silent "CC_REMIND=off"       "build a landing page" CC_REMIND=off

box="$WORK/nojq-box"; mkdir -p "$box"
out=$(printf '{"prompt":"build a landing page","session_id":"nojq"}' \
  | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null); jrc=$?
if [ "$jrc" -eq 0 ] && [ -z "$out" ]; then pass "no-jq fail-open"; else fail "no-jq fail-open" "exit $jrc, out: ${out:0:60}"; fi

# once per session: same session id, same TMPDIR — the catalog is context-resident
# after the first injection, so a second copy is pure waste.
box="$WORK/once"; mkdir -p "$box"
J='{"prompt":"build a landing page","session_id":"once"}'
o1=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
o2=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$o1" ] && pass "first prompt injects" || fail "first prompt injects" "silent"
[ -z "$o2" ] && pass "second prompt yields" || fail "second prompt yields" "injected twice"

# UNWRITABLE TMPDIR MUST STILL INJECT. The dedup above and this case are the two
# outcomes of one failed `mkdir`, and the hook used to answer both with `exit 0`:
# marker exists (suppress, correct) and marker CANNOT exist (suppress, wrong — the
# catalog is then lost on every prompt of every session, silently). Only the pair
# pins the behaviour; asserting the dedup alone passes on the broken version, which
# is why it is asserted here and not left to the case above. route.sh:156 is the
# doctrine being enforced: an unwritable state dir must not swallow the payload.
ro="$WORK/ro"; mkdir -p "$ro"; chmod 500 "$ro" 2>/dev/null
if mkdir "$ro/probe" 2>/dev/null; then
  rmdir "$ro/probe" 2>/dev/null
  printf 'SKIP: TMPDIR still writable after chmod 500 (running as root?) — fail-open case not graded\n'
else
  oro=$(printf '{"prompt":"build a landing page","session_id":"ro"}' \
    | env TMPDIR="$ro" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
  [ -n "$oro" ] && pass "unwritable TMPDIR still injects (fail open)" \
    || fail "unwritable TMPDIR still injects (fail open)" "marker write failed and the catalog went with it"
fi
chmod 700 "$ro" 2>/dev/null

printf '== half A: catalog content ==\n'
cat_out="$(run_hook "build a landing page for a B2B marketing agency" "$ROOT/$SR")"
lines=$(printf '%s' "$cat_out" | grep -c '^- /' || true)
[ "$lines" -ge 20 ] && pass "catalog has $lines command lines" \
  || fail "catalog line count" "only $lines lines — expected the installed commands"

# every catalog line must name a command that actually exists on disk
bad=""
while IFS= read -r line; do
  tok=${line#- }; tok=${tok%% *}
  p=${tok#/}; p=${p%%:*}; c=${tok##*:}
  [ -f "plugins/$p/commands/$c.md" ] || bad="$bad $tok"
done <<EOF_LINES
$(printf '%s' "$cat_out" | grep '^- /')
EOF_LINES
[ -z "$bad" ] && pass "every catalog entry resolves to a command file" \
  || fail "catalog entries resolve" "no such command:$bad"

# the directive must carry the anti-nag discipline — these are the rules that stop a
# catalog from turning every prompt into a suggestion
for phrase in "Silence is the default" "AskUserQuestion" "(Recommended)" "as asked" \
              "one picker per named tool per session" "goal ledger"; do
  printf '%s' "$cat_out" | grep -qF "$phrase" \
    && pass "directive carries: $phrase" || fail "directive carries: $phrase" "missing"
done

# installed-scoping: a tree holding two plugins must yield a catalog of only those
SOLO="$WORK/solo/plugins"; mkdir -p "$SOLO/skill-router/hooks"
cp -R plugins/a11y "$SOLO/a11y"
cp "$HOOK" "$SOLO/skill-router/hooks/route-prompt.sh"
solo_out="$(run_hook "audit this for accessibility problems and fix them" "$SOLO/skill-router")"
solo_lines=$(printf '%s' "$solo_out" | grep -c '^- /' || true)
foreign=$(printf '%s' "$solo_out" | grep '^- /' | grep -vc '^- /a11y:' || true)
if [ "$solo_lines" -ge 1 ] && [ "$foreign" -eq 0 ]; then
  pass "catalog is installed-scoped ($solo_lines entries, all a11y)"
else
  fail "catalog is installed-scoped" "$solo_lines entries, $foreign from uninstalled plugins"
fi

printf '== half C: the incident moment has an owner ==\n'
# These four cases exercise plugins/*/hooks/remind.sh, not the hook this file is
# named for. Each hook gets its OWN TMPDIR: reminder hooks share one per-prompt
# mkdir marker, so a shared sandbox would measure scheduling order instead of the
# trigger, which is the exact confusion this split was made to remove.
DBG="$ROOT/plugins/debugging/hooks/remind.sh"
FT="$ROOT/plugins/fresh-take/hooks/remind.sh"

run_remind() { # run_remind <hook> <prompt> -> hook stdout
  local hook="$1" prompt="$2"
  local n; n=$(( $(cat "$COUNTER") + 1 )); printf '%s' "$n" > "$COUNTER"
  local box="$WORK/rbox-$n"; mkdir -p "$box"
  local tp="$box/transcript-rsess-$n.jsonl"; : > "$tp"
  printf '%s' "$prompt" | jq -Rs --arg s "rsess-$n" --arg tp "$tp" \
      '{prompt:., session_id:$s, transcript_path:$tp}' \
    | env TMPDIR="$box" "$BASH_BIN" "$hook" 2>/dev/null
}

if [ -f "$DBG" ] && [ -f "$FT" ]; then
  STUCK="the login test is still failing"
  out="$(run_remind "$DBG" "$STUCK")"
  printf '%s' "$out" | grep -qF '/debugging:debug' \
    && pass "debugging fires on the stuck moment and names its command" \
    || fail "debugging fires on the stuck moment" "wanted /debugging:debug, got: ${out:-<silence>}"
  out="$(run_remind "$FT" "$STUCK")"
  [ -z "$out" ] && pass "fresh-take yields the stuck moment to debugging" \
    || fail "fresh-take yields the stuck moment" "both plugins still claim it: $out"

  # The destructive branch is KEPT, deliberately. command-guard is PreToolUse and so
  # fires only once the model has already composed the call; this is the only signal
  # that reaches the user before the proposal exists. Its MESSAGE moved, not its
  # trigger — deleting the branch would have been the cheaper edit and the wrong one.
  out="$(run_remind "$FT" "rm -rf node_modules")"
  if [ -n "$out" ]; then
    pass "fresh-take still fires on a destructive token"
    printf '%s' "$out" | grep -qF 'stronger-model' \
      && fail "destructive line is re-pointed" "still sells a stronger-model take: $out" \
      || pass "destructive line no longer sells a stronger-model take"
  else
    fail "fresh-take still fires on a destructive token" "the sole pre-proposal signal is gone"
  fi
else
  fail "incident-moment hooks present" "missing $DBG or $FT"
fi

printf '== half B: validate.sh gates ==\n'
want_err() { printf '%s\n' "$vout" | grep -qF "$2" && pass "$1" || fail "$1 did not fire" "wanted: $2"; }

# PLANT INTO A COPY, NEVER THE LIVE TREE.
# These cases need validate.sh to SEE a broken hook, and the previous version appended to
# the real plugins/skill-router/hooks/route-prompt.sh and restored it with cp. That
# works exactly as long as nothing interrupts: a killed run, a timeout, or two runs
# overlapping leaves the plant on disk, and the next gate then fails on a file nobody
# edited. It also silently reverted a completed feature once, because the restore
# copied a backup taken before that feature landed. validate.sh cds to its own repo
# root (validate.sh:4), so running the COPY's validate.sh scopes everything to the
# copy — the live tree is never written to at all.
MIRROR="$WORK/mirror"
mkdir -p "$MIRROR"
# .claude-plugin is not optional: validate.sh exits early with
# "marketplace.json missing" without it, so the mirror would report a DIFFERENT
# failure and every want_err below would silently never fire.
for d in plugins scripts templates .claude-plugin; do cp -R "$ROOT/$d" "$MIRROR/" 2>/dev/null; done
for f in CLAUDE.md README.md skills-lock.json; do [ -f "$ROOT/$f" ] && cp "$ROOT/$f" "$MIRROR/" 2>/dev/null; done
MHOOK="$MIRROR/$SR/hooks/route-prompt.sh"
mvalidate() { ( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ); }

if [ -f "$MHOOK" ]; then
  MHB="$WORK/mirror-route-prompt.bak"; cp "$MHOOK" "$MHB"

  printf 'echo /taskmaster:task\n' >> "$MHOOK"
  vout=$(mvalidate)
  cp "$MHB" "$MHOOK"
  want_err "literal command token" "carries literal command token(s)"

  # a fifth prompt-matching grep = a routing table regrowing in shell
  printf '%s\n' 'printf '"'"'%s'"'"' "$head" | grep -qiE "landing page" && exit 0' >> "$MHOOK"
  vout=$(mvalidate)
  cp "$MHB" "$MHOOK"
  want_err "extra prompt pattern" "a fifth is a routing table regrowing in shell"

  vout=$(mvalidate)
  printf '%s\n' "$vout" | grep -qF 'route-prompt.sh' \
    && fail "clean tree is clean" "validate still reports route-prompt problems after restore" \
    || pass "clean tree is clean"

  # The live tree must be untouched by any of the above.
  if cmp -s "$HOOK" "$HB"; then
    pass "live route-prompt.sh was never written to"
  else
    fail "live route-prompt.sh was never written to" "the harness mutated the real tree"
  fi
else
  fail "mirror tree built" "missing $MHOOK"
fi

# ---- STACK RELEVANCE of the catalog (spec 4.6, card C6) ----------------------
# The catalog is filtered by repo evidence, not just installed-ness: a Laravel repo
# should not be offered /nextjs:review. Asserted in BOTH directions plus the trap
# that a glob-only predicate would fall into.
#
# THE TRAP: seven plugins own ONLY content rows in rules.tsv (llm-app,
# node-backend, observability, payments, resilience, security, threejs). A
# predicate that asked "does any GLOB row match" would find nothing for them in
# any repository, and would therefore delete /security:review from every repo on
# earth. The empty-repo case below is what catches that, and it is the reason a
# plugin with no rows — or no glob rows — is defined as stack-neutral and kept.
CAT_HOOK="$ROOT/plugins/skill-router/hooks/route-prompt.sh"
if [ -f "$CAT_HOOK" ]; then
  cat_for() { # $1 project dir, $2 session tag
    printf '{"prompt":"refactor the checkout module","session_id":"cat-%s","cwd":"%s"}' "$2" "$1" \
      | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/skill-router" \
        TMPDIR="$(mktemp -d "$WORK/cat.XXXXXX")" "$BASH_BIN" "$CAT_HOOK" 2>/dev/null
  }
  cat_expect() { # $1 desc, $2 output, $3 needle, $4 present|absent
    local got=absent
    case "$2" in *"$3"*) got=present ;; esac
    [ "$got" = "$4" ] && pass "catalog: $1" || fail "catalog: $1" "$3 is $got, wanted $4"
  }

  CL="$WORK/cat-laravel"; mkdir -p "$CL"
  printf '{"require":{"laravel/framework":"^11"}}' > "$CL/composer.json"; : > "$CL/app.php"
  OL=$(cat_for "$CL" laravel)
  cat_expect "a Laravel repo is not offered /nextjs:review" "$OL" "/nextjs:review" absent
  cat_expect "a Laravel repo keeps /laravel:review"         "$OL" "/laravel:review" present
  cat_expect "stack-neutral /code-review:review always kept" "$OL" "/code-review:review" present

  CN="$WORK/cat-next"; mkdir -p "$CN"
  printf '{"dependencies":{"next":"^14"}}' > "$CN/package.json"; : > "$CN/next.config.js"
  ON=$(cat_for "$CN" next)
  cat_expect "a Next.js repo keeps /nextjs:review"      "$ON" "/nextjs:review" present
  cat_expect "a Next.js repo is not offered /laravel:review" "$ON" "/laravel:review" absent

  CE="$WORK/cat-empty"; mkdir -p "$CE"
  OE=$(cat_for "$CE" empty)
  cat_expect "content-only /security:review survives an empty repo"     "$OE" "/security:review" present
  cat_expect "content-only /resilience:review survives an empty repo"   "$OE" "/resilience:review" present
  cat_expect "content-only /observability:review survives an empty repo" "$OE" "/observability:review" present

  # A filter that dropped everything would pass every "absent" assertion above.
  ln_l=$(printf '%s' "$OL" | grep -c '^- /')
  [ "$ln_l" -gt 30 ] && pass "catalog: the filter narrows without emptying ($ln_l rows on Laravel)" \
    || fail "catalog: the filter narrows without emptying" "only $ln_l rows survived — over-filtering"
fi

if [ "$rc" -eq 0 ]; then
  printf '\nAll tool-fit check cases passed (mechanism only — the routing verdict is agent-graded).\n'
else
  printf '\nSome tool-fit check cases FAILED.\n'
fi
exit $rc
