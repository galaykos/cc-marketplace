#!/bin/bash
# Absolute-path shebang, not `/usr/bin/env bash`: the fail-open guarantee must
# hold under a stripped PATH where `env bash` exits 127.
#
# candor-gate — a Stop hook with TWO clauses, both falsifiable on disk or in the
# transcript. Neither is a tone judgement; tone is measured by /candor:check and
# blocked by nothing.
#
#   CLAUSE 1 — FABRICATED CITATION. The final assistant message contains a
#   `path/to/file.ext:NNN` reference that does not resolve: no such file under
#   cwd, or the file has fewer lines than the number cited. A file:line citation
#   asserts "I read this"; when it resolves to nothing, that assertion is false
#   and a script can prove it. This is the one hallucination shape in coding work
#   that is mechanically decidable, which is why it is the one this gate takes.
#
#   CLAUSE 2 — UNEVIDENCED REVERSAL. The last user message is BARE pushback —
#   challenge-shaped ("are you sure?", "that's wrong", "nope"), carrying no
#   correction of its own — and the final assistant message retracts ("you're
#   right", "my mistake", "I stand corrected") while NO tool ran after that
#   pushback and the message states no basis for the change. That is sycophancy
#   with the evidence step skipped, and unlike "was the model too agreeable" it
#   is decidable: either something was re-checked between the challenge and the
#   retraction, or nothing was.
#
# WHAT THIS CARRIES THAT NO SIBLING GATE DOES (Admission law — see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - code-architecture/hooks/evidence-gate.sh judges a COMPLETION CLAIM against
#     post-edit execution. It never reads what the message cites, and it never
#     looks at the user's turn at all. A turn that edits nothing, claims nothing,
#     and simply invents `src/auth/session.ts:212` passes it clean.
#   - task-runner/hooks/completion-gate.sh enforces a REGISTERED run's recorded
#     behavioural-gate pass. Outside a registered run it does nothing.
#   - This repo's scripts/done-gate.sh is marketplace-specific and gate-status
#     based. This hook ships with the plugin and works in any project, git or not.
#
# LIMITATION (honest scope — the four laws, "Honest limitation"):
#   - CLAUSE 1 checks `file:line` ONLY, never a bare path. A bare path is
#     routinely a file the turn PROPOSES to create, and blocking those would
#     make the gate a nuisance on ordinary work — the false-positive class that
#     gets a gate switched off. So a confidently invented API name, package,
#     flag or function is NOT caught here; only an invented location is.
#   - CLAUSE 1 fires on an invented FILENAME, not a wrong directory. See the
#     ladder in resolve() for the measurement that forced that scope: a real
#     filename cited under an abbreviated or wrong path now passes silently.
#   - CLAUSE 1 cannot see intent. A citation into a file the turn itself just
#     shortened, DELETED or renamed, or into a sibling worktree or container
#     path, blocks though the model did read it. The escape is to re-cite or
#     drop the number, which is the right move in all of those cases.
#   - A path written with an elision (`plugins/x/.../SKILL.md:74`) is skipped,
#     not resolved — it is prose shorthand and never a claim about a real path.
#   - CLAUSE 2's pushback test is a regex over one message, not comprehension.
#     Pushback phrased in a way this list does not carry is invisible, and a
#     user message that includes its OWN correction (a path, a quoted snippet, a
#     long explanation) deliberately disarms the clause — agreeing with a
#     correction that arrived WITH evidence is not sycophancy, it is reading.
#   - CLAUSE 2 accepts ANY tool call after the pushback as evidence. A `git
#     status` satisfies it. It proves something was re-checked, not that the
#     right thing was.
#   - Both clauses judge the FINAL assistant message only, deliberately: the
#     sibling evidence-gate documents a measured window-bleed defect from
#     matching claim and escape over a 30-line rolling window in BOTH
#     directions. A single-message window cannot bleed. The cost is that a
#     retraction split across two messages escapes clause 2.
#   - Tone — flattery, defensiveness, combativeness, apology spirals — is NOT
#     gated. No regex separates "you're right" said because it is true from the
#     same words said to please, once the evidence question is already answered.
#     /candor:check measures it after the fact; the skill is where the rule
#     lives. Calling that enforcement would be the tier over-claim this
#     marketplace's own conventions forbid.
#   - Transcript tail only (last 4000 entries).
#   - One block per distinct final text (state marker), so a disagreement cannot
#     loop forever.
#
# FAIL-OPEN on missing jq, an unreadable transcript, or empty text.
#
# A Stop hook reaches the model only via exit 2 with the reason on stderr (or
# block-JSON on stdout); this uses exit 2. Exit 0 prints into a turn that has
# already ended and can prevent nothing.
#
# MODES: CC_CANDOR_GATE=block (default) | warn (print, never block) | off

input=$(cat)

case "${CC_CANDOR_GATE:-block}" in off) exit 0 ;; esac

command -v jq >/dev/null 2>&1 || { echo "[candor] gate: jq not found — gate not enforced" >&2; exit 0; }

# NAMESPACED DISARM. stop_hook_active is SHARED across every Stop hook: Claude
# Code sets it on the continuation after ANY blocking one. A bare exit on it lets
# a sibling gate spend this gate's enforcement (task-runner's completion-gate
# header records that exact bug). Deleting the exit instead wedges the session,
# because this gate's own bound is a sha of the final message and a continuation
# is new prose by construction. So: record that THIS gate blocked, and honour the
# flag only when that record is present.
sha_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$tp" ] && [ -r "$tp" ] || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd="."

claimed="$cwd/.claude/candor-blocked"
if [ "$sha_active" = "true" ] && [ -f "$claimed" ]; then
  rm -f "$claimed" 2>/dev/null
  exit 0
fi

tail_jsonl=$(tail -n 4000 "$tp" 2>/dev/null)
[ -n "$tail_jsonl" ] || exit 0

# The FINAL assistant text message, whole and alone. `-s` slurps the JSONL into
# an array so "last" is expressible; a malformed line collapses the slurp, which
# is a fail-open path and is why the result is tested for emptiness below.
last_msg=$(printf '%s' "$tail_jsonl" | jq -rs '
  [ .[] | select(.type=="assistant")
        | ((.message.content // []) | map(select(.type=="text") | .text) | join("\n"))
        | select(length > 0) ] | last // empty' 2>/dev/null)
[ -n "$last_msg" ] || exit 0

verdict=""   # set by whichever clause fires first
detail=""

# ---------------------------------------------------------------------------
# CLAUSE 1 — citations that do not resolve
# ---------------------------------------------------------------------------
# URLs are stripped BEFORE extraction: `https://host/a.php:80` is a port, not a
# line. The extension must START with a letter, so `v1.2.3:4` and `10:30` never
# match, and a short deny-list drops bare host:port forms (`example.com:8080`).
cites=$(printf '%s' "$last_msg" \
  | sed -E 's#[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:])"]*##g' \
  | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' 2>/dev/null \
  | grep -vEi '\.(com|net|org|io|co|ai|app|gg|me):[0-9]+$' \
  | grep -vF '...' \
  | sort -u)

# _find <predicate…> — one pruned, depth-capped tree walk. Bounded so a Stop hook
# stays cheap on a large repo.
_find() { find "$cwd" -maxdepth 8 \
  \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv \) -prune \
  -o "$@" -type f -print 2>/dev/null; }

# resolve <relpath> — prints one of:
#   FILE <path>   the citation identifies exactly one file on disk
#   MISSING       no file anywhere in the tree carries that BASENAME
#   AMBIGUOUS     the path does not resolve, but the basename is not unique
#
# A FOUR-STEP LADDER, and the last two steps exist because of a measurement, not a
# theory. Run over 47 real session transcripts (~3.3k assistant messages), the
# earlier two-step version — cwd-relative, then a full-suffix match — reported 98
# unresolved citations, and the overwhelming majority were ABBREVIATED paths, not
# invented ones: `craft-layer/asset-sourcing/SKILL.md:10` for a file that really
# lives at `plugins/craft-layer/skills/asset-sourcing/SKILL.md`. Blocking those is
# the false-positive class that gets a gate switched off.
#
# So the ladder falls back to the basename, and only a basename that exists NOWHERE
# is treated as fabrication. That is the shape a script can be confident about: an
# invented FILENAME. A real filename under a wrong directory now passes silently,
# and that residual is deliberate — it is sloppiness, and it was indistinguishable
# from abbreviation on every real example measured.
resolve() {
  local p="$1" m b n
  case "$p" in
    /*) [ -f "$p" ] && { printf 'FILE %s' "$p"; return 0; } ;;
  esac
  [ -f "$cwd/$p" ] && { printf 'FILE %s' "$cwd/$p"; return 0; }
  m=$(_find -path "*/$p" | head -1)
  [ -n "$m" ] && { printf 'FILE %s' "$m"; return 0; }
  b=${p##*/}
  m=$(_find -name "$b" | head -2)
  n=$(printf '%s\n' "$m" | grep -c .)
  if [ "$n" -eq 0 ]; then printf 'MISSING'
  elif [ "$n" -eq 1 ]; then printf 'FILE %s' "$m"
  else printf 'AMBIGUOUS'
  fi
  return 0
}

misses=""
checked=0
for c in $cites; do
  [ "$checked" -ge 25 ] && break
  checked=$((checked + 1))
  path="${c%:*}"; line="${c##*:}"
  r=$(resolve "$path")
  case "$r" in
    MISSING)   misses="$misses
  - $c — no file named ${path##*/} exists anywhere under $cwd"; continue ;;
    AMBIGUOUS) continue ;;   # path unresolved but the name is real — not decidable
  esac
  file="${r#FILE }"
  lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
  case "$lines" in ''|*[!0-9]*) continue ;; esac
  # +1 tolerance: a final line with no trailing newline is not counted by wc -l.
  if [ "$line" -gt $((lines + 1)) ] 2>/dev/null; then
    misses="$misses
  - $c — $file has $lines lines"
  fi
done

if [ -n "$misses" ]; then
  verdict="citation"
  detail="$misses"
fi

# ---------------------------------------------------------------------------
# CLAUSE 2 — a position reversed after bare pushback, with nothing re-checked
# ---------------------------------------------------------------------------
if [ -z "$verdict" ]; then
  # Last real user message. Tool results also arrive as type "user"; they carry
  # tool_result blocks and no text blocks, so selecting text blocks excludes them.
  last_user=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="user")
          | (if (.message.content | type) == "string" then .message.content
             else ((.message.content // []) | map(select(.type=="text") | .text) | join("\n")) end)
          | select(length > 0) ] | last // empty' 2>/dev/null)

  PUSHBACK='are you sure|you sure|are you certain|is that (right|true|correct|actually)|that.?s (not right|wrong|incorrect|false|not true)|that is (not right|wrong|incorrect|false)|you.?re (wrong|mistaken)|you are (wrong|mistaken)|i don.?t think (so|that|it)|i disagree|doesn.?t (seem|sound|look) right|does not (seem|sound|look) right|check (it )?again|double.?check|really\?|no,? (it|that|this|they|you) |nope|prove it|where did you (get|see|find) that|you (made|just made) (that|it) up|hallucinat|that.?s not (how|what|where)'

  # A pushback that ARRIVES WITH ITS OWN EVIDENCE is not the sycophancy setup —
  # a user who quotes a path, pastes a snippet, or writes a paragraph of reasoning
  # has supplied the new information, and agreeing with it is reading, not
  # flattery. Disarm on any of: a backtick, a path-shaped token, a file:line, or
  # a message long enough to be an argument rather than a challenge.
  user_has_evidence=0
  if [ -n "$last_user" ]; then
    printf '%s' "$last_user" | grep -q '`' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' && user_has_evidence=1
    [ "$(printf '%s' "$last_user" | wc -c | tr -d ' ')" -gt 400 ] && user_has_evidence=1
  fi

  CAVE='you.?re (absolutely |completely |totally |quite |entirely )?right|you are (absolutely |completely |totally |quite |entirely )?right|you.?re correct|you are correct|my (mistake|apologies|bad|error)|i (was|am) wrong|i apologi[sz]e|apologies|good catch|i stand corrected|i (was|got) (confused|mistaken)|that was (wrong|my (mistake|error))|let me correct'

  # HOLD — the message did more than fold. Either it names what it re-checked, or
  # it keeps part of the position. Both are candour; neither is what this blocks.
  HOLD='i still (think|believe|maintain)|i do (think|believe)|i.?m not (changing|reversing)|re-?read|re-?ran|re-?checked|i (checked|verified|confirmed)|after (checking|re-?reading|running|re-?running)|the (file|output|test|error|transcript) (shows|says)|i disagree|on (that|this) (one|point) i|partly|only partly|to be clear, i'

  if [ -n "$last_user" ] && [ "$user_has_evidence" -eq 0 ] \
     && printf '%s' "$last_user" | grep -qiE "$PUSHBACK" \
     && printf '%s' "$last_msg" | grep -qiE "$CAVE" \
     && ! printf '%s' "$last_msg" | grep -qiE "$HOLD"; then
    # Did anything run AFTER that user message? One row per entry keeps order
    # without line numbers: "USER" for a real user turn, the tool names for an
    # assistant turn, empty otherwise.
    ran=$(printf '%s' "$tail_jsonl" | jq -r '
      if .type=="user" then
        (if ((.message.content | type) == "string")
            or (((.message.content // []) | map(select(.type=="text")) | length) > 0)
         then "USER" else "" end)
      elif .type=="assistant" then
        ([.message.content[]? | select(.type=="tool_use") | .name] | join(" "))
      else "" end' 2>/dev/null \
      | awk '{ if ($0 == "USER") { after = 0 } else if (NF > 0) { after = 1 } } END { print (after ? "yes" : "no") }')
    if [ "$ran" = "no" ]; then
      verdict="reversal"
      detail="$last_user"
    fi
  fi
fi

[ -n "$verdict" ] || exit 0

# LOOP GUARD: block once per distinct final text. stop_hook_active is not trusted
# alone (no sibling trusts it); the marker is state a mid-work turn cannot fake.
marker="$cwd/.claude/candor-last"
state=$(printf '%s|%s' "$verdict" "$last_msg" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
if ! { mkdir -p "$cwd/.claude" 2>/dev/null && printf '%s' "$state" > "$marker" 2>/dev/null; }; then
  # No marker means no per-text bound this turn. THIS is where the shared flag
  # earns its keep: without both, a gate that blocks on unwritable state blocks
  # the same turn forever. Honouring it only here costs at most one unenforced
  # stop on an already-degraded setup.
  [ "$sha_active" = "true" ] && exit 0
fi

mkdir -p "$cwd/.claude" 2>/dev/null && : > "$claimed" 2>/dev/null

if [ "$verdict" = "citation" ]; then
  printf '[candor] gate: this turn cites a location that does not exist.%s\n' "$detail" >&2
  printf '  A file:line citation asserts you read that line. Open the file, cite what is actually\n' >&2
  printf '  there, or drop the number and say plainly that you are inferring rather than quoting.\n' >&2
  printf '  Inventing a location is the failure this clause exists to stop.\n' >&2
else
  printf '[candor] gate: the user pushed back without giving you new information, and this turn\n' >&2
  printf '  retracts your position anyway — nothing was re-checked between the challenge and the\n' >&2
  printf '  retraction.\n' >&2
  printf '  Do one of two things. Re-check: run the command or read the file that would settle it,\n' >&2
  printf '  then report what it showed. Or hold: say you still believe what you said, and why.\n' >&2
  printf '  "You are right" is a finding. It needs the same evidence as any other finding.\n' >&2
fi

case "${CC_CANDOR_GATE:-block}" in warn) exit 0 ;; esac
exit 2
