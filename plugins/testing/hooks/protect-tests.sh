#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PreToolUse guard against FAKE GREEN: an edit that makes a test stop running rather
# than makes the code pass. DENIES two shapes in a test file, and only in a test file:
#
#   1. a skip/exclusive marker being ADDED (`.skip`, `.only`, `xit(`, `xdescribe(`,
#      `@pytest.mark.skip`, `markTestSkipped`, `$this->markTestIncomplete`, Go's
#      `t.Skip(`, `#[ignore]`, `@Disabled`, `@Ignore`, `it.todo`)
#   2. a whole test file being emptied or deleted through Write — content that no
#      longer contains a single test function while the file on disk did
#
# WHY THIS AND NOT PROSE. Skipping the failing test to get a green run is the
# best-documented way a model reports success it did not earn, and it is invisible in
# a summary: the suite passes, the count drops by one, nobody reads counts. Every
# collection surveyed on 2026-09-14 ships the doctrine in prose ("never skip a test to
# pass"); the model follows it until a test is the last thing between it and done.
# `.only` is the same failure inverted — it does not skip one test, it skips all the
# others, and a committed `.only` silently shrinks CI to a single case.
#
# WHAT IT DOES NOT CATCH, stated because the README tiers this `gate`:
#   - A test weakened rather than skipped (an assertion deleted, an expectation
#     loosened to `toBeTruthy`, a `try/except: pass` around the body). That is
#     `code-architecture:drift-review`'s agent-graded territory and no regex reaches it.
#   - A skip added through a tool this matcher does not name.
#   - A skip that was ALREADY in the file: only a newly introduced marker denies, so
#     editing a legitimately-skipped test is never blocked.
#   - Deleting a test file with `rm` — that is a Bash command, and command-guard's
#     territory, not a write tool's.
#
# ESCAPE HATCH. A skip is sometimes right: a quarantined flake, an unimplemented
# feature, a platform-specific case. The deny reason names the two ways through —
# write the marker with a same-line reason comment (`// skip: flaky under CI, #1421`),
# which this hook accepts, or set CC_PROTECT_TESTS=off for the session. The reason
# requirement is the point: an intentional skip has one, a fake-green skip does not.
#
# Fail-open on every error path, missing jq included.
{
  [ "${CC_PROTECT_TESTS:-on}" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *apply_patch|*create_new_file) ;;
    *) exit 0 ;;
  esac

  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
  [ -n "$file" ] || exit 0

  # Test files only. A skip marker in production code is not this hook's business.
  base=$(basename "$file")
  case "$base" in
    *.test.*|*.spec.*|*Test.php|*Test.java|*Test.kt|*_test.go|*_test.py|test_*.py|*_test.rb|*_spec.rb|*_test.rs|*.test.ts|*.test.tsx) ;;
    *)
      case "/$file" in
        */tests/*|*/test/*|*/__tests__/*|*/spec/*|*/Tests/*) ;;
        *) exit 0 ;;
      esac
      ;;
  esac

  # The text being INTRODUCED, across every tool shape.
  new=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      .tool_input.text // empty,
      .tool_input.input // empty,
      .tool_input.patch // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0

  # The text being REPLACED — a marker already present there is not newly introduced.
  old=$(printf '%s' "$input" | jq -r '
    [ .tool_input.old_string // empty,
      ( .tool_input.edits // [] | map(.old_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null)

  skip_re='(\.(skip|only|todo|failing)[[:space:]]*\(|\bx(it|describe|test|context)[[:space:]]*\(|@pytest\.mark\.skip|markTestSkipped|markTestIncomplete|\bt\.Skip(Now)?[[:space:]]*\(|#\[ignore\]|@Disabled\b|@Ignore\b|\bpending[[:space:]]*\(|\.skipIf[[:space:]]*\()'

  hit=""
  if printf '%s' "$new" | grep -qE "$skip_re"; then
    # Count occurrences added vs already there. A rewrite that carries an existing
    # marker through unchanged must not deny.
    n_new=$(printf '%s' "$new" | grep -oE "$skip_re" | grep -c . || true)
    n_old=$(printf '%s' "$old" | grep -oE "$skip_re" | grep -c . || true)
    case "$n_new" in ''|*[!0-9]*) n_new=0 ;; esac
    case "$n_old" in ''|*[!0-9]*) n_old=0 ;; esac
    # For a full-file Write, compare against the file on disk instead of old_string.
    if [ "$tool" = "Write" ] || [ -z "$old" ]; then
      if [ -f "$file" ]; then
        n_old=$(grep -oE "$skip_re" "$file" 2>/dev/null | grep -c . || true)
        case "$n_old" in ''|*[!0-9]*) n_old=0 ;; esac
      fi
    fi
    if [ "$n_new" -gt "$n_old" ]; then
      # An intentional skip carries its reason on the same line. Accept those.
      unreasoned=$(printf '%s' "$new" | grep -E "$skip_re" \
        | grep -ivE '(#|//|/\*|\*)[[:space:]]*(skip|todo|reason|why|flaky|quarantin|pending|because)|reason[[:space:]]*[:=]' \
        | grep -c . || true)
      case "$unreasoned" in ''|*[!0-9]*) unreasoned=0 ;; esac
      [ "$unreasoned" -gt 0 ] && hit="a test skip/exclusive marker with no reason on its line"
    fi
  fi

  # Shape 2: a Write that empties a test file which currently holds tests.
  if [ -z "$hit" ] && [ "$tool" = "Write" ] && [ -f "$file" ]; then
    test_re='(\b(it|test|describe|context)[[:space:]]*\(|def[[:space:]]+test_|function[[:space:]]+test|public[[:space:]]+function[[:space:]]+test|func[[:space:]]+Test[A-Z]|#\[test\]|@Test\b)'
    had=$(grep -cE "$test_re" "$file" 2>/dev/null || true)
    has=$(printf '%s' "$new" | grep -cE "$test_re" || true)
    case "$had" in ''|*[!0-9]*) had=0 ;; esac
    case "$has" in ''|*[!0-9]*) has=0 ;; esac
    [ "$had" -gt 0 ] && [ "$has" -eq 0 ] && hit="a rewrite that removes every test from a file that had $had"
  fi

  [ -n "$hit" ] || exit 0

  reason="testing: this edit introduces $hit in $base. A suite that goes green because a test stopped running is a false report, and the drop in test count is invisible in a summary. Fix the code, or — if the skip is genuinely right (a quarantined flake, an unimplemented feature, a platform gap) — put the reason on the same line, e.g. \`it.skip('…')  // skip: flaky on CI, see #1421\`, and this guard allows it. CC_PROTECT_TESTS=off disables the guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
