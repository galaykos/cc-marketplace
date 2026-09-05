#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop hook — completion-gate enforcement for a task-runner run.
#
# WHAT IT DOES: on every Stop, if a run has REGISTERED itself (the run wrote
# $cwd/.claude/task-runner/active-run.json at start), this checks whether the
# behavioral-gate recorded a PASS for the current HEAD in gate-pass.json. If not, it
# exits 2 to BLOCK the stop and feed the reason back to the model — the produced code
# was never run through the gate, and a green repo suite alone is NOT the gate.
#
# WHY BLOCK IS THE DEFAULT: a Stop hook reaches the model ONLY through exit 2. Exit 0
# prints to a turn that has already ended, so warn mode cannot prevent the failure it
# describes — a run that narrates its next step ("starting card 01 now") and yields in
# plain text stalls, with no card started and the user waiting on a dead turn. Blocking
# is bounded to ONE BLOCK PER COMMIT (the nudge marker below), on the run's own branch
# only, so a genuine stop costs at most one extra turn and an abandoned run cannot become
# a repo-wide trap. Opt out with TASK_RUNNER_STOP_GATE=warn (print only, never block).
#
# WHY A RECORDS CHECK, NOT A TEST RUN: this hook fires on EVERY yield, so it must be
# cheap and never mutate the tree. It never executes the produced tests — the
# completion protocol runs behavioral-gate.sh in the proper isolated way and records
# the pass here. This hook only verifies that record exists for the final commit.
#
# HONEST LIMIT (documented, not hidden): enforcement is keyed off the run REGISTERING
# itself. A run that never writes active-run.json is not enforced (fail-open) — the
# same residual the behavioral-gate skill names. What this closes is the honest-but-
# forgetful path: a registered run cannot stop "done" without a recorded gate pass.
#
# Default is BLOCK (one-shot, only inside a registered run). Downgrade to print-only
# with TASK_RUNNER_STOP_GATE=warn. Fail-open on missing jq/git or a malformed sentinel. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)

input=$(cat)

command -v jq >/dev/null 2>&1 || { echo "[task-runner] completion-gate: jq not found — gate not enforced" >&2; exit 0; }

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || exit 0

# Never re-trigger from our own continuation.
# stop_hook_active is READ here and honoured only inside gate_exit's fallback — it is
# NOT an early exit any more. The flag is SHARED across every Stop hook: Claude Code
# sets it on the continuation following ANY blocking one, so code-architecture's
# evidence-gate blocking first used to spend this gate's enforcement, and a registered
# run could end clean with cards unexecuted — the exact outcome this hook exists to
# prevent. The per-HEAD nudge below is this gate's own bound and sat unreachable
# beneath that exit.
sha_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)

sentinel="$cwd/.claude/task-runner/active-run.json"
[ -r "$sentinel" ] || exit 0                     # no registered run → nothing to enforce
jq empty "$sentinel" 2>/dev/null || { echo "[task-runner] completion-gate: active-run.json malformed — not enforced" >&2; exit 0; }

command -v git >/dev/null 2>&1 || { echo "[task-runner] completion-gate: git not found — not enforced" >&2; exit 0; }
head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || { echo "[task-runner] completion-gate: not a git repo — not enforced" >&2; exit 0; }

# BRANCH GUARD: a sentinel is cleared only on clean completion, so an abandoned run leaves
# one behind indefinitely. Enforcing it from a different branch would turn a dead run into
# a repo-wide trap on unrelated work, with no way out but deleting a file the user does not
# know exists. A run registered with a "branch" is enforced only on that branch; a sentinel
# without one (pre-0.17 registration) keeps the old unconditional behavior.
run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
cur_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
  printf '[task-runner] completion-gate: run registered on branch %s, now on %s — not enforced here.\n' "$run_branch" "$cur_branch" >&2
  printf '  If that run is finished or abandoned, delete .claude/task-runner/active-run.json.\n' >&2
  exit 0
fi

# ONE BLOCK PER HEAD. The stop_hook_active check above assumes Claude Code sets that flag
# on the continuation it triggers; this guard does not assume it. The last HEAD blocked on
# is recorded, and a second stop at the SAME commit prints without blocking. Enforcement
# therefore rides on progress — every commit re-arms the gate, so a real run is held to
# every card — while a stale sentinel costs at most one extra turn per commit, not one per
# stop. The marker lives beside the sentinel in .claude/task-runner/ (the run's own state
# dir); it is the only thing this hook ever writes, and never touches the working tree.
#
# The marker is honored only while it is NEWER than the sentinel it was written under.
# Nothing clears it (the run clears active-run.json, not this), so without that test a
# marker left by run A would eat run B's first block whenever no commit landed between
# them — the same HEAD, a different run, and the protection silently gone on the turn it
# matters most. Comparing mtimes makes a new registration re-arm the gate by itself; if
# the two land in the same clock tick the comparison fails toward blocking, never toward
# silence.
nudge="$cwd/.claude/task-runner/gate-nudge"
gate_exit() {
  [ "${TASK_RUNNER_STOP_GATE:-block}" = "block" ] || exit 0
  if [ -r "$nudge" ] && [ "$nudge" -nt "$sentinel" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$head" ]; then
    exit 0
  fi
  if ! printf '%s' "$head" > "$nudge" 2>/dev/null; then
    # The nudge could not be written, so the per-HEAD bound does not exist this turn.
    # THIS is the only place the shared flag is still needed: without a marker and
    # without it, an unwritable state dir would block the same stop forever. Cost is
    # one unenforced stop on an already-degraded setup, rather than surrendering every
    # stop that follows a sibling gate's block.
    [ "$sha_active" = "true" ] && exit 0
  fi
  exit 2
}

gatepass="$cwd/.claude/task-runner/gate-pass.json"
if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
  # Gate pass recorded for THIS commit. For an index run, run.md also records card
  # counts in gate-pass.json; when those numeric fields are present, refuse a clean
  # stop while any card is neither done nor parked (cards_done + cards_parked <
  # cards_total). ALL fields absent → legacy behavior (allow). Partially present,
  # non-numeric, or inconsistent (done+parked > total) counts are MALFORMED — warned,
  # never silently allowed, so a bookkeeping slip cannot disarm the gate. Same
  # block-by-default semantics (via gate_exit) as the no-pass path below.
  verdict=$(jq -r '
    if ((.cards_total|type)=="number" and (.cards_done|type)=="number" and (.cards_parked|type)=="number")
    then (if (.cards_done + .cards_parked) < .cards_total then "incomplete"
          elif (.cards_done + .cards_parked) > .cards_total then "malformed"
          else "complete" end)
    elif ((has("cards_total") or has("cards_done") or has("cards_parked")) | not) then "absent"
    else "malformed" end' "$gatepass" 2>/dev/null)
  # A run REGISTERED as an index run (active-run.json carries index_path) must record
  # counts: counts-absent for it is a bookkeeping failure, not legacy — warn, never a
  # silent allow (an unregistered/plain run keeps the legacy absent→allow behavior).
  if [ "$verdict" = "absent" ] && [ "$(jq -r 'has("index_path")' "$sentinel" 2>/dev/null)" = "true" ]; then
    verdict="malformed"
  fi
  if [ "$verdict" = "incomplete" ] || [ "$verdict" = "malformed" ]; then
    slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
    ct=$(jq -r '.cards_total' "$gatepass" 2>/dev/null)
    cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
    cpark=$(jq -r '.cards_parked' "$gatepass" 2>/dev/null)
    printf '[task-runner] completion-gate: %s recorded a gate pass but its card counts are %s: done=%s parked=%s total=%s.\n' "$slug" "$verdict" "$cdone" "$cpark" "$ct" >&2
    printf '  A run may not report complete while any card is neither done nor parked.\n' >&2
    gate_exit
  fi
  # PER-CARD NEGATIVE-CONTROL COVERAGE (opt-in by presence): when the run recorded
  # per-card NC results in .claude/task-runner/nc/ (negative-control.sh --record-dir
  # writes nc-pass-* mechanically on a discriminating control; documented skips are
  # nc-skip-*), a "complete" run must have one record per DONE card. Fewer records
  # than cards_done → some card was flipped done with no control and no documented
  # skip → refuse the clean stop. No nc/ dir at all → the run predates or did not
  # opt into the convention; legacy allow (same incremental posture as the branch
  # guard). This shrinks the named "per-card control unenforced" residual: forgetting
  # the control now blocks; only a hand-forged record defeats it.
  ncdir="$cwd/.claude/task-runner/nc"
  if [ "$verdict" = "complete" ] && [ -d "$ncdir" ]; then
    cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
    nc_count=$(find "$ncdir" -maxdepth 1 \( -name 'nc-pass-*.json' -o -name 'nc-skip-*.json' \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "$nc_count" -lt "$cdone" ] 2>/dev/null; then
      slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
      printf '[task-runner] completion-gate: %s reports %s done cards but only %s per-card negative-control records in .claude/task-runner/nc/.\n' "$slug" "$cdone" "$nc_count" >&2
      printf '  Every done card needs an nc-pass record (negative-control.sh --record-dir --card) or a documented nc-skip. Run the missing controls, then stop.\n' >&2
      gate_exit
    fi
  fi
  # PER-CARD REVIEWER COVERAGE. Same arithmetic as the nc block, different evidence:
  # rv-seen-* records are written by hooks/rv-observe.sh when it OBSERVES a reviewer
  # dispatch carrying the card's RV-CARD marker, so the count is not model-authored.
  # rv-skip-* is a discretionary skip (consent-gated, disclosed); rv-exempt-* is a
  # design carve-out (leaf card, reviewer plugin absent).
  #
  # This closes the gap a real run fell through: reviewers ran on card 01, were
  # dropped on 02-08 under context pressure, and nothing noticed — every other gate
  # was green and the report said "all 8 done, none parked". The rv/ dir is created
  # at run registration (commands/run.md step 1), NOT on first use: opt-in-by-presence
  # would be defeated by the same pressure that causes the skip.
  rvdir="$cwd/.claude/task-runner/rv"
  if [ "$verdict" = "complete" ] && [ -d "$rvdir" ]; then
    cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
    # TWO CORRECTIONS over a raw file count, both found by adversarial review:
    #
    # -newer "$sentinel": card ids repeat across runs (taskmaster emits 01..NN every
    # time), so run B's coverage was satisfied by run A's leftover records — the gate
    # was fully defeated from the second run in a repo onward. Only records written
    # since THIS run registered count.
    #
    # distinct ids: rv-seen-01 plus rv-skip-01 is two files and one card. Counting
    # files let a two-card run pass with card 02 never reviewed, skipped, or exempted.
    rv_count=$(find "$rvdir" -maxdepth 1 \( -name 'rv-seen-*.json' -o -name 'rv-skip-*.json' -o -name 'rv-exempt-*.json' \) -newer "$sentinel" 2>/dev/null |
      sed -E 's#.*/rv-(seen|skip|exempt)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
    if [ "$rv_count" -lt "$cdone" ] 2>/dev/null; then
      slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
      printf '[task-runner] completion-gate: %s reports %s done cards but only %s per-card reviewer records in .claude/task-runner/rv/.\n' "$slug" "$cdone" "$rv_count" >&2
      printf '  Every done card needs an observed reviewer dispatch (the RV-CARD marker in the prompt), a recorded skip (scripts/review-skip.sh --card --reason) or an exemption (--exempt). Run the missing reviews, then stop.\n' >&2
      gate_exit
    fi
  fi
  # BEHAVIORAL-GATE EVIDENCE. gate-pass.json is written by the MODEL — on its own it
  # proves a claim was typed, not that the gate ran. behavioral-gate.sh now writes
  # bg-<head>.json with the verdict it actually reached. When that directory exists
  # (created at run registration) a complete verdict must be backed by a matching
  # record for the same HEAD. Absent bg/ → legacy allow, same posture as nc/ and rv/.
  bgdir="$cwd/.claude/task-runner/bg"
  if [ "$verdict" = "complete" ] && [ -d "$bgdir" ]; then
    if [ ! -r "$bgdir/bg-$head.json" ]; then
      slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
      printf '[task-runner] completion-gate: %s recorded a gate pass for HEAD %s, but behavioral-gate.sh left no verdict record for it.\n' "$slug" "${head:0:12}" >&2
      printf '  gate-pass.json is written by hand; bg/bg-<head>.json is written by the gate itself. Run scripts/behavioral-gate.sh against this HEAD, then stop.\n' >&2
      gate_exit
    fi
    # PASSING VERDICTS ARE TWO, not one: behavioral-gate.sh exits 0 for `covered` AND
    # for `no-executable-surface` (its own contract — an honest doc/lint-only change has
    # nothing runnable to prove). Treating the second as red blocked every docs run at
    # completion with no way forward, which is a worse failure than the silence this
    # whole mechanism replaced.
    bgv=$(jq -r '.verdict // empty' "$bgdir/bg-$head.json" 2>/dev/null)
    case "$bgv" in covered | no-executable-surface | '') bgv="" ;; esac
    if [ -n "$bgv" ]; then
      printf '[task-runner] completion-gate: behavioral-gate.sh reached "%s" for HEAD %s, and the run is reporting complete.\n' "$bgv" "${head:0:12}" >&2
      printf '  A run may not close over a red or unverifiable behavioral gate. Fix the coverage, re-run the gate, then stop.\n' >&2
      gate_exit
    fi
  fi
  # RED-TEAM PANEL WIDTH (boosted runs only). code-redteam mandates exactly three blind
  # refuters plus a completeness critic over the SHIPPED diff, and its own text says a
  # skipped red-team is "a silent regression, never an option" — which nothing observed.
  # Refuter dispatches carry RT-LENS markers, the critic RT-CRITIC; rv-observe.sh records
  # them. The degraded inline fallback is legitimate but must be RECORDED (reduction-
  # record.sh --kind redteam) and, like every reduction, disclosed in the report.
  #
  # Scoped to boosted runs because that is when the pass fires: the index carries an
  # Ultra:/Goal: marker and active-run.json names the index.
  rtdir="$cwd/.claude/task-runner/rt"
  if [ "$verdict" = "complete" ] && [ -d "$rtdir" ]; then
    idx=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null)
    boosted=0
    case "$idx" in /*) idxp="$idx" ;; *) idxp="$cwd/$idx" ;; esac   # absolute or relative
    if [ -n "$idx" ] && [ -r "$idxp" ]; then
      grep -qiE '^[[:space:]]*(Ultra|Goal):[[:space:]]*true' "$idxp" 2>/dev/null && boosted=1
    fi
    # A boosted run that shipped no code has nothing for a code red-team to refute —
    # code-redteam fires "when a boosted run produced code". Arming rt/ at registration
    # is unconditional, so without this a legitimate docs-only ultra run blocked at
    # completion and the only escape was recording a semantically false degradation.
    # Unknown diff (no base recorded, or git cannot resolve it) → do not enforce: a
    # missed check costs a check, a false block costs the run.
    if [ "$boosted" = 1 ]; then
      run_base=$(jq -r '.base // empty' "$sentinel" 2>/dev/null)
      code_touched=unknown
      if [ -n "$run_base" ] && git -C "$cwd" rev-parse --verify "$run_base" >/dev/null 2>&1; then
        if git -C "$cwd" diff --name-only "$run_base..HEAD" 2>/dev/null |
             grep -qvE '\.(md|txt|json|ya?ml|lock|csv|svg|png|jpe?g|gif)$|^$'; then
          code_touched=yes
        else
          code_touched=no
        fi
      fi
      [ "$code_touched" = "no" ] && boosted=0
    fi
    if [ "$boosted" = 1 ]; then
      lenses=$(find "$rtdir" -maxdepth 1 -name 'rt-lens-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
      critic=$(find "$rtdir" -maxdepth 1 -name 'rt-critic-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
      degraded=$(find "$cwd/.claude/task-runner/reductions" -maxdepth 1 -name 'redteam-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$degraded" -eq 0 ] 2>/dev/null && { [ "$lenses" -lt 3 ] || [ "$critic" -lt 1 ]; } 2>/dev/null; then
        printf '[task-runner] completion-gate: this is a boosted run, and the code red-team panel is short: %s of 3 refuter lenses, %s of 1 completeness critic.\n' "$lenses" "$critic" >&2
        printf '  Dispatch the missing refuters (each prompt carries RT-LENS: <lens>, the critic RT-CRITIC: <id>), or record the degraded inline pass with scripts/reduction-record.sh --kind redteam --id <ref> --reason "...". Then stop.\n' >&2
        gate_exit
      fi
    fi
  fi
  # DISCLOSURE, for every recorded reduction — a skipped reviewer pass, a degraded
  # red-team, a narrowed fan-out, anything reduction-record.sh filed. Presence only:
  # this cannot judge whether the disclosure is honest, and does not pretend to. What
  # it removes is the case the incident was made of — a reduction that happened, was
  # recorded, and never reached the person reading the report.
  if [ "$verdict" = "complete" ]; then
    # WHAT MUST BE DISCLOSED: the ID of every reduction recorded during THIS run.
    # Grepping for the words skipped/reduced/degraded was wrong in both directions —
    # "Tests: 41 passed, 0 skipped" satisfied it while the real cut went unmentioned,
    # and an honest "the reviewer pass was omitted with your approval" was blocked.
    # An id is specific: naming card 07 is what disclosure means.
    ids=$(find "$rvdir" -maxdepth 1 -name 'rv-skip-*.json' -newer "$sentinel" 2>/dev/null |
            sed -E 's|.*/rv-skip-||; s|\.json$||'
          find "$cwd/.claude/task-runner/reductions" -maxdepth 1 -name '*.json' -newer "$sentinel" 2>/dev/null |
            sed -E 's|.*/[a-z]+-||; s|\.json$||')
    ids=$(printf '%s\n' "$ids" | sed '/^$/d' | sort -u)
    if [ -n "$ids" ]; then
      tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
      if [ -n "$tp" ] && [ -r "$tp" ]; then
        # The whole final report, not a fixed tail: a long report can carry its
        # disclosure well above the last 40 lines.
        said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$tp" 2>/dev/null | tail -200)
        missing=""
        for id in $ids; do
          printf '%s' "$said" | grep -qF "$id" || missing="$missing $id"
        done
        if [ -n "$said" ] && [ -n "$missing" ]; then
          printf '[task-runner] completion-gate: this run recorded reductions that the closing report never names:%s\n' "$missing" >&2
          printf '  Name each one and its reason (the records are in .claude/task-runner/rv/ and reductions/) before stopping — a cut the user has to ask about is the gap this gate exists to prevent.\n' >&2
          gate_exit
        fi
      fi
    fi
  fi
  exit 0                                          # gate pass for THIS commit (cards complete or legacy) → allow
fi

# No gate pass for HEAD → the run is not complete. Two very different moments land here:
# mid-run (cards still to execute) and end-of-run (all cards done, gate not yet run). The
# hook cannot tell them apart cheaply — index status formats vary and parsing them here
# would trade fail-open cheapness for guesswork — so it names BOTH branches and lets the
# model pick the one it is in. Naming only the completion branch is what made the earlier
# message useless mid-run: it answered a question the model was not yet asking.
slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
printf '[task-runner] completion-gate: %s is a registered run with no behavioral-gate pass for HEAD %s.\n' "$slug" "${head:0:12}" >&2
printf '  The run is not complete, so this turn must not end here.\n' >&2
printf '  Cards still to execute -> continue NOW with a tool call. Do not name the next card in prose\n' >&2
printf '    and yield: that binds nothing, and the user waits on a turn that already ended. Need a\n' >&2
printf '    decision -> ask it with AskUserQuestion (not a stop). Blocked -> park the card with a reason.\n' >&2
printf '  Every card done or parked -> run behavioral-gate.sh on the produced code (isolated), record\n' >&2
printf '    the pass to .claude/task-runner/gate-pass.json as {"head":"%s"} plus the card counts,\n' "$head" >&2
printf '    then clear active-run.json. A green repo suite alone is NOT this gate.\n' >&2
printf '  Not running this task list at all? The sentinel outlived its run — delete\n' >&2
printf '    .claude/task-runner/active-run.json.\n' >&2

gate_exit                                          # blocks (exit 2) or, when already
                                                   # nudged at this HEAD / under warn, exits 0
