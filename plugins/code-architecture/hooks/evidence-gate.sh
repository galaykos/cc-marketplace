#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop hook — evidence-at-claim gate. The mechanical teeth of this plugin's
# work-verification skill ("never assert without output").
#
# WHAT IT CATCHES: the zero-effort completion claim. A turn ends with prose
# claiming the work is done/fixed/implemented, files were edited this session,
# and NOTHING was executed after the last edit — no test, no build, no lint,
# not even running the code. That is the exact shape of the later apology
# "you're right, I didn't actually do it", and it is the one case neither
# sibling Stop gate covers: the marketplace repo's done-gate is repo-specific,
# and task-runner's completion-gate enforces only runs that registered
# themselves. This hook is portable — it ships with the plugin and works in
# any project, git or not.
#
# TRIGGER — all THREE must hold, read from the session transcript:
#   1. the session's assistant tail claims completion (done, fixed,
#      implemented, verified, passes, should work, ...), and
#   2. the session mutated files (Edit/Write/MultiEdit/NotebookEdit), and
#   3. no execution tool (Bash/Agent/Task) ran AFTER the last mutation.
#
# The ESCAPE is honesty, not silence-about-failure phrasing games: prose that
# says what is unverified ("not tested", "did not run", "still failing",
# "blocked", ...) passes. An honest status report always carries it. The escape
# vocabulary is deliberately phrase-scoped, not word-scoped — see the ACK note
# below for the hole that a bare `failing` opened.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - Saying nothing evades it. A turn that ends without a completion claim is
#     not judged — acceptable: the lie this gate exists to stop was never told.
#   - ANY post-edit execution counts as evidence — a `git status` satisfies
#     clause 3. The gate proves "something ran after the last edit", not "the
#     right verification ran"; relevance stays with the reviewer.
#   - An Agent/Task tool call counts as execution — a subagent may have
#     verified, and this hook cannot see inside its report cheaply.
#   - Transcript tail only (last 4000 entries); a session longer than that is
#     judged on its tail.
#   - CLAIM and ACK are matched over the SAME window (the last 30 lines of
#     assistant text), so an honest acknowledgement several messages back still
#     licenses a naked claim now. Narrowing ACK to the final message alone was
#     considered and rejected: it would block honest reports that state the
#     caveat before the summary, and it fixes no observed case — every measured
#     escape was same-sentence, which the phrase-scoping above closes.
#   - One block per distinct claim (state marker) — a re-stop on the same
#     final text passes, so an unfixable disagreement cannot loop forever.
#
# FAIL-OPEN on missing jq, missing/unreadable transcript, or empty text —
# matching the sibling hooks. A Stop hook reaches the model only via exit 2
# with the reason on stderr (or block-JSON on stdout); this uses exit 2.
#
# MODES: CC_EVIDENCE_GATE=block (default) | warn (print, never block) | off

input=$(cat)

case "${CC_EVIDENCE_GATE:-block}" in off) exit 0 ;; esac

command -v jq >/dev/null 2>&1 || { echo "[code-architecture] evidence-gate: jq not found — gate not enforced" >&2; exit 0; }

# Never re-trigger from our own continuation.
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$tp" ] && [ -r "$tp" ] || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd="."

tail_jsonl=$(tail -n 4000 "$tp" 2>/dev/null)
[ -n "$tail_jsonl" ] || exit 0

# 1. CLAIM (cheap): does the assistant tail claim completion? Whole-word via
# grep -w (BSD grep has no \b; unanchored 'done' would match 'abandoned').
said=$(printf '%s' "$tail_jsonl" \
  | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
  | tail -30)
[ -n "$said" ] || exit 0

CLAIM='done|complete|completed|finished|implemented|fixed|resolved|verified|passes|passing|works now|working now|should work|all set|good to go'
printf '%s' "$said" | grep -qiwE "$CLAIM" || exit 0

# HONESTY ESCAPE: a turn that names what is unverified or failing is a status
# report, not a false claim. Evaluated before the tool scan so honest turns
# stay cheap.
#
# The escape must assert something about THIS turn's verification state. Bare
# failure nouns (fail/fails/failing/failed/failure) used to be listed, and they
# disarmed the gate on the single most common shape of a real bug-fix turn:
# "Fixed the failing test — should work now" matched `failing`, exited 0, and
# never reached the evidence scan. A failure named as the thing that was FIXED
# is part of the claim, not an acknowledgement of it. So the failure vocabulary
# is now phrase-scoped — the subject must be the check ("tests still fail",
# "the build failed") or the failure must carry its cause ("fails with ENOENT").
ACK='not tested|untested|unverified|not verified|did not run|didn.t run|have not run|haven.t run|not run yet|cannot verify|could not verify|not green|still fail(ing|s)?|currently fail(ing|s)?|(tests?|suite|build|lint|checks?|it) (still |currently )?fail(ing|ed|s)?|fail(ing|ed|s)? (with|on|because|due)|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|please verify|verify manually|left to do|remains to'
printf '%s' "$said" | grep -qiwE "$ACK" && exit 0

# 2+3. MUTATION AND EVIDENCE ORDER: one row of tool names per assistant entry
# (blank when none) preserves order without line numbers; awk finds whether an
# execution tool ran after the LAST file mutation.
verdict=$(printf '%s' "$tail_jsonl" \
  | jq -r 'select(.type=="assistant") | [.message.content[]? | select(.type=="tool_use") | .name] | join(" ")' 2>/dev/null \
  | awk '
      { for (i = 1; i <= NF; i++) { n++
          if ($i ~ /^(Edit|Write|MultiEdit|NotebookEdit)$/) last_edit = n
          if ($i ~ /^(Bash|Agent|Task)$/)                   last_exec = n } }
      END {
        if (!last_edit)               print "no-edits"
        else if (last_exec > last_edit) print "evidence"
        else                          print "naked-claim" }')
[ "$verdict" = "naked-claim" ] || exit 0

# LOOP GUARD: block once per distinct final text. stop_hook_active is not
# trusted alone (neither sibling trusts it); the marker is state a mid-work
# turn cannot fake — a genuinely new turn produces new text or new tool rows.
marker="$cwd/.claude/evidence-gate-last"
state=$(printf '%s' "$said" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
mkdir -p "$cwd/.claude" 2>/dev/null && printf '%s' "$state" > "$marker" 2>/dev/null

printf '[code-architecture] evidence-gate: this turn claims completion, files were edited, and no command ran after the last edit — nothing verified the change.\n' >&2
printf '  Either run the check that would FAIL if the change were broken (test, build, lint, or execute\n' >&2
printf '  the changed code) and show its output — or restate honestly: what changed, what was NOT\n' >&2
printf '  verified, and the exact command the user can run to verify it.\n' >&2
printf '  A claim with no execution behind it is the failure this gate exists to stop.\n' >&2

case "${CC_EVIDENCE_GATE:-block}" in warn) exit 0 ;; esac
exit 2
