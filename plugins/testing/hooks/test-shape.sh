#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
# stripped or broken PATH, where `env bash` itself exits 127.
#
# PostToolUse on a written TEST file. Reads the file's BODY and names the test blocks that
# do not earn their place. Nothing else in this marketplace reads a test body: every other
# mechanism reads a surrogate — the card's Verify line as text (taskmaster verify-teeth),
# the runner's collected COUNT (task-runner behavioral-gate, which only fires at zero), the
# comment:code ratio (comment-discipline density.sh), or a reviewer's judgment of prose
# (testing-best-practices/references/proportionality.md, whose own first line reads
# "Standing: agent-graded. No script measures this."). A suite of twenty assertion-free
# blocks therefore passes every gate this repo ships, and each gate is correct to pass it.
#
# THREE DETECTORS, chosen because each is a text fact rather than a judgment:
#   1. ASSERTION-FREE — a test block with no assertion token from its language's
#      vocabulary. This is `it_can_be_instantiated`, and it is coverage theatre's
#      load-bearing move: the line executes, so the coverage number moves.
#   2. NEAR-DUPLICATE — three or more blocks whose bodies are identical once digit runs
#      and quoted strings are blanked. One arithmetic identity restated N times. The
#      finding says "parameterize", not "delete", because a boundary sweep looks the same
#      and only a reader can tell them apart.
#   3. PRIVATE REACH — a block using PHP reflection to reach a non-public member, which
#      pins an implementation name so the next rename breaks the test.
#
# STANDING: advisory. `additionalContext` is not a blocking key and this exits 0 on every
# path, including every failure. It cannot be a gate, and the reason is on the record
# rather than a limitation of effort: lean/skills/cost-model/SKILL.md:114-120 and
# proportionality.md:3 both refuse a test-count or ratio threshold, because there is no
# correct ratio — a number would fire on legitimately dense work and wave through a
# bloated suite that sits under it. Naming three specific shapes at a location is a
# different claim from scoring a count, which is why this ships and a ratio gate does not.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - PostToolUse: the file is already on disk. This informs the NEXT write.
#   - ONE FILE, NO DIFF. It cannot see test count growing faster than behaviour count —
#     the aggregate blind spot density.sh and lean/hooks/budget.sh each name for
#     themselves. That question stays agent-graded, deliberately.
#   - It cannot see duplicate-layer assertions (the same rule proved at the action, the
#     controller and the browser): those blocks live in different files and each asserts
#     something real.
#   - An assertion inside a project helper whose name carries neither `assert` nor
#     `expect` (`verifyOrder($o)`) reads as assertion-free. A false positive, accepted
#     rather than widening the vocabulary into noise. The vocabulary covers Pest/PHPUnit,
#     Vitest/Jest, chai should-style and ava/tape/node:test — an adversarial audit on
#     2026-08-18 found the last two missing, which meant flagging whole correct dialects
#     while the limitation admitted only the helper case. A dialect absent from that list
#     will read as assertion-free, and the honest fix is to add it, not to widen to any
#     function call.
#   - It does not judge whether a flagged near-duplicate group is bloat or a boundary
#     sweep, and does not detect a test that merely restates the spec.
#   - ITS COST IS UNMETERED, and not because nobody looked. `scripts/context-budget.sh`
#     measures the dynamic channel with one synthetic `Edit`, and that Edit does not target
#     a test path — so this hook returns nothing during measurement and scores 0 in the
#     table while the message it emits on a real test write is ~120 tokens. Same class as
#     the two gaps that script already reports by name (skill BODIES, remote MCP). The
#     bounds above are what stands in for a meter: 4 findings per file, 3 files per context.
#
# Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
# CC_TEST_SHAPE=off silences only this one.
#
# FAIL-OPEN: missing jq or awk, unreadable file, unwritable state dir, or any error
# exits 0 with no output.
{
  [ "${CC_REMIND:-}" = "off" ] && exit 0
  [ "${CC_TEST_SHAPE:-}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0

  # Test-path globs: the same three rules.tsv already trusts for test routing, plus the
  # xUnit filename conventions. Every non-test write leaves through this case statement.
  case "$fp" in
    *.test.*|*.spec.*|*/tests/*|*/test/*|*Test.php|*_test.py|*_test.go|*_spec.rb) ;;
    *) exit 0 ;;
  esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0

  # CONTEXT KEY, not session key: a subagent shares its parent's session_id while getting
  # its own transcript, and PostToolUse is the only hook channel that reaches subagents at
  # all — which is where fan-out tests actually get written. HASHED before it becomes a
  # filename: the key is normally an absolute path, and interpolating one raw names a
  # nested file whose parents are never created, so every write fails and the bound
  # silently stops existing. Gated by pc_context_key and pc_marker_key respectively.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  MAX_FILES=3          # files reported per context
  MAX_FINDINGS=4       # findings reported per file
  DUP_MIN=3            # blocks sharing a normalized body before it is worth saying

  dir="$cwd/.claude/testing"
  state="$dir/shape-$ctx"
  # A bound that cannot be recorded is not a bound: unwritable state means silence, not a
  # warning on every edit for the rest of the run. Same rule as comment-discipline.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  if [ -r "$state" ]; then
    grep -qxF "$fp" "$state" 2>/dev/null && exit 0          # this file already reported
    [ "$(grep -c . "$state" 2>/dev/null || echo 0)" -ge "$MAX_FILES" ] && exit 0
  fi

  findings=$(awk -v maxf="$MAX_FINDINGS" -v dupmin="$DUP_MIN" '
    # Block boundaries only need to be good enough to bucket lines, so there is no brace
    # matching here: a block runs from one test opener to the next.
    function is_opener(l) {
      return (l ~ /(^|[^[:alnum:]_])(it|test|describe|context)[[:space:]]*\(/) ||
             (l ~ /function[[:space:]]+test[[:alnum:]_]*[[:space:]]*\(/) ||
             (l ~ /#\[Test\]/)
    }
    # `describe`/`context` GROUP tests; they are boundaries but never findings. Without
    # this they read as assertion-free by construction — a false positive on every
    # correctly written Vitest/Jest/RSpec file, which would have made the hook noise.
    function is_group(l) {
      return (l ~ /(^|[^[:alnum:]_])(describe|context)[[:space:]]*\(/)
    }
    function is_excluded(l) {
      return (l ~ /(it|test|describe)[[:space:]]*\.[[:space:]]*(skip|todo|failing)/) ||
             (l ~ /markTestSkipped|expectNotToPerformAssertions/) ||
             (l ~ /(doesNotPerformAssertions|DoesNotPerformAssertions)/) ||
             (l ~ /(^|[^[:alnum:]_])arch[[:space:]]*\(/)
    }
    function has_assertion(b) {
      return (b ~ /expect[[:space:]]*\(/) ||
             (b ~ /\.(toBe|toEqual|toContain|toHaveCount|toHaveLength|toThrow|toMatch|toMatchObject|toMatchSnapshot|toMatchInlineSnapshot|toBeGreaterThan|toBeLessThan|toBeNull|toBeTruthy|toBeFalsy|toBeDefined|toHaveBeenCalled)/) ||
             (b ~ /\.(resolves|rejects)\./) ||
             (b ~ /(\$this|self|static)[[:space:]]*(->|::)[[:space:]]*assert/) ||
             (b ~ /->[[:space:]]*assert[A-Z]/) ||
             (b ~ /->[[:space:]]*(toBe|toEqual|toHaveCount|toThrow|toBeGreaterThan|toMatchArray)/) ||
             (b ~ /->[[:space:]]*throws[[:space:]]*\(/) ||
             (b ~ /(^|[^[:alnum:]_])assert[[:space:]]*[\(\.]/) ||
             (b ~ /assert(DatabaseHas|DatabaseMissing|SoftDeleted|Queued|Pushed|Dispatched|Sent|NothingSent)/) ||
             (b ~ /expectException|expectExceptionMessage|expectError/) ||
             # chai should-style: `user.name.should.equal("Ann")` carries no `expect`.
             (b ~ /\.should[[:space:]]*[\.\(]/) || (b ~ /\.should\.(not|be|have|eql|equal|deep)/) ||
             # ava / tape / node:test: the assertion IS the test callback argument.
             (b ~ /(^|[^[:alnum:]_.])t[[:space:]]*\.[[:space:]]*(is|not|deepEqual|notDeepEqual|true|false|truthy|falsy|throws|throwsAsync|notThrows|regex|like|snapshot|pass|fail|plan|end)[[:space:]]*\(/)
    }
    function reaches_private(b) {
      return (b ~ /setAccessible/) ||
             (b ~ /Reflection(Method|Property|Class|Object)/)
    }
    # Blank the values so two blocks that differ only in a literal collapse together.
    function normalize(b,  s) {
      s = b
      gsub(/"[^"]*"/, "S", s); gsub(/\047[^\047]*\047/, "S", s)
      gsub(/[0-9]+(\.[0-9]+)?/, "N", s)
      gsub(/[[:space:]]+/, " ", s)
      # Strip a trailing run of structural punctuation. Blocks are delimited by the NEXT
      # opener, so the last block in a file absorbs the closing braces of its class or
      # describe() — which made its body differ from its own duplicates and left the last
      # of N identical tests permanently outside the group it belongs to.
      sub(/[ });]+$/, "", s)
      return s
    }
    # Blocks are RECORDED here and classified in END, because a block cannot be classified
    # until every block is known: one that belongs to a near-duplicate group is reported
    # as part of that group and not a second time as assertion-free, or three restatements
    # of one identity spend three of the four finding slots saying the same thing.
    function flush() {
      if (!open) return
      if (!excluded && !isgroup) {
        nb++
        b_start[nb] = start
        b_key[nb] = normalize(body)
        b_noassert[nb] = has_assertion(body) ? 0 : 1
        b_priv[nb] = reaches_private(body) ? 1 : 0
        dupc[b_key[nb]]++
        if (dupc[b_key[nb]] == 1) dupline[b_key[nb]] = start
      }
      open = 0; body = ""; excluded = 0; isgroup = 0
    }
    { line = $0 }
    is_opener(line) {
      flush()
      open = 1; start = NR; excluded = is_excluded(line); isgroup = is_group(line)
      name = line; sub(/^[[:space:]]+/, "", name)
      if (length(name) > 58) name = substr(name, 1, 55) "..."
      body = line
      next
    }
    open { body = body "\n" line }
    END {
      flush()
      n = 0
      # Duplicate groups first: one line covers N blocks, so it is the densest finding and
      # it claims those blocks, keeping them out of the assertion-free list below.
      for (k in dupc) {
        if (n >= maxf) break
        if (dupc[k] >= dupmin) {
          printf "  L%s — %d near-identical blocks differing only in a literal: parameterize them, or keep the ones that pin a real boundary.\n", dupline[k], dupc[k]
          n++
        }
      }
      for (i = 1; i <= nb && n < maxf; i++) {
        if (!b_noassert[i]) continue
        if (dupc[b_key[i]] >= dupmin) continue        # already reported as a group
        printf "  L%s — no assertion: the block runs code and proves nothing. Assert the behaviour, or delete it.\n", b_start[i]
        n++
      }
      for (i = 1; i <= nb && n < maxf; i++) {
        if (!b_priv[i]) continue
        printf "  L%s — reaches a non-public member by reflection: the next rename breaks this test without the behaviour changing.\n", b_start[i]
        n++
      }
    }
  ' "$fp" 2>/dev/null)

  [ -n "$findings" ] || exit 0

  printf '%s\n' "$fp" >> "$state" 2>/dev/null || exit 0

  msg=$(printf 'testing: shapes in %s that may not earn their place —\n%s\nEach line is a location, not a verdict; the rubric is the testing-best-practices skill. A test earns its place by failing first for a break no sibling already catches.' "$fp" "$findings")
  jq -cn --arg ctx "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
