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
# rather than a limitation of effort: proportionality.md:3 refuses a test-count or ratio
# threshold (so did lean's cost-model skill, removed 2026-09-14), because there is no
# correct ratio — a number would fire on legitimately dense work and wave through a
# bloated suite that sits under it. Naming three specific shapes at a location is a
# different claim from scoring a count, which is why this ships and a ratio gate does not.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - PostToolUse: the file is already on disk. This informs the NEXT write.
#   - ONE FILE, NO DIFF. It cannot see test count growing faster than behaviour count —
#     the aggregate blind spot code-review/hooks/density.sh names for itself. That
#     question stays agent-graded, deliberately.
#   - It cannot see duplicate-layer assertions (the same rule proved at the action, the
#     controller and the browser): those blocks live in different files and each asserts
#     something real.
#   - TWO VOCABULARIES, AND THEY FAIL IN OPPOSITE DIRECTIONS. The OPENER set decides
#     whether a block exists; the ASSERTION set decides whether it earns its place.
#     * A dialect missing from the OPENER set reads as NO TEST FILE, not as assertion-free:
#       zero blocks are found, nothing is compared, and the hook is silent. Silence is also
#       what a clean file produces, so the gap is invisible from the outside — which is how
#       `*_test.py`, `*_test.go` and `*_spec.rb` sat inside the path glob at :82 for a year
#       while the opener set matched only JS and PHP. Openers now covered: JS/TS
#       (`it(`/`test(`/`describe(`), PHP and JS `function test…(`, pytest/minitest
#       `def test…`, Go `func Test…`, RSpec/minitest paren-less `it "…" do`, `#[Test]`.
#       Still absent, and therefore still SILENT rather than wrong: JUnit/Kotlin `@Test` +
#       `void shouldX()`, Rust `#[test] fn …`, C++ `TEST_F(`, Elixir `test "…" do` (`test`
#       is only matched with a paren). `*/test/*` admits all of them by path.
#     * A dialect missing from the ASSERTION set reads as assertion-free — a false positive
#       on correct code, which is the louder failure. The set covers Pest/PHPUnit,
#       Vitest/Jest, chai should-style, ava/tape/node:test, pytest's bare `assert`
#       statement, Go's `t.Error`/`t.Fatal` and testify's `require.`/`assert.`, and RSpec's
#       `expect`/`is_expected`/`should` forms. An assertion inside a project helper whose
#       name carries none of those words (`verifyOrder($o)`) still reads as assertion-free:
#       accepted rather than widening the vocabulary to any function call. The honest fix
#       for either gap is to add the dialect, not to loosen the pattern.
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

  # `-d`, not just `-n`: the payload's cwd is where the session STARTED, and a session
  # outlives the directory — `mkdir -p "$dir"` below rebuilt a deleted three-level project
  # tree so it could hold this hook's state file. `.claude/testing` has exactly one writer
  # (this hook), so unlike the code-review battery it is free to re-root: one bound per
  # REPOSITORY is what "3 files per context" was always meant to mean, and a subagent
  # running from a subdirectory otherwise gets its own fresh budget. Shape copied from
  # overseer/hooks/track-read.sh:30-31. Does NOT catch a cwd that exists but is the wrong
  # checkout, and outside a git repo the root is the cwd exactly as before.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
  [ -n "$root" ] || root="$cwd"

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

  dir="$root/.claude/testing"
  state="$dir/shape-$ctx"
  # A bound that cannot be recorded is not a bound: unwritable state means silence, not a
  # warning on every edit for the rest of the run. Same rule as comment-discipline.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself
  if [ -r "$state" ]; then
    grep -qxF "$fp" "$state" 2>/dev/null && exit 0          # this file already reported
    [ "$(grep -c . "$state" 2>/dev/null || echo 0)" -ge "$MAX_FILES" ] && exit 0
  fi

  findings=$(awk -v maxf="$MAX_FINDINGS" -v dupmin="$DUP_MIN" '
    # Block boundaries only need to be good enough to bucket lines, so there is no brace
    # matching here: a block runs from one test opener to the next.
    # The FOUR-dialect opener set below is what decides whether this hook sees a file at
    # all. The path glob at :82 already admits `*_test.py`, `*_test.go` and `*_spec.rb`; for
    # a year the opener set did not, so all three detected zero blocks and the hook was
    # silent on them — not wrong, ABSENT, which no limitation disclosed. The paren-less
    # arm is RSpec/minitest (`it "adds" do`), and it is anchored on `[^[:alnum:]_]` so
    # `xit "later" do` is not an opener: a skipped block is excluded in every other dialect
    # and must not become a finding here.
    function is_opener(l) {
      return (l ~ /(^|[^[:alnum:]_])(it|test|describe|context)[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])(it|describe|context|specify|scenario)[[:space:]]+["\047]/) ||
             (l ~ /function[[:space:]]+test[[:alnum:]_]*[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])def[[:space:]]+test/) ||
             (l ~ /(^|[^[:alnum:]_])func[[:space:]]+Test/) ||
             (l ~ /#\[Test\]/)
    }
    # `describe`/`context` GROUP tests; they are boundaries but never findings. Without
    # this they read as assertion-free by construction — a false positive on every
    # correctly written Vitest/Jest/RSpec file, which would have made the hook noise.
    function is_group(l) {
      return (l ~ /(^|[^[:alnum:]_])(describe|context)[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])(describe|context)[[:space:]]+["\047]/)
    }
    # A block that DECLARES it does not run is never a finding. In JS the declaration is on
    # the opener (`it.skip(`); in Python, Go and Ruby it is a line INSIDE the body
    # (`pytest.skip(`, `t.Skip(`, RSpec `pending`/bare `skip`) or a decorator on the line
    # ABOVE (`@pytest.mark.skip`), which is why this is now tested against every line of a
    # block rather than its first. `func TestMain(m *testing.M)` is the Go suite entry point,
    # not a test: it wires setup and calls m.Run(), so it carries no assertion by
    # construction and would be flagged on every Go package that has one.
    function is_excluded(l) {
      return (l ~ /(it|test|describe)[[:space:]]*\.[[:space:]]*(skip|todo|failing)/) ||
             (l ~ /markTestSkipped|expectNotToPerformAssertions/) ||
             (l ~ /(doesNotPerformAssertions|DoesNotPerformAssertions)/) ||
             (l ~ /(^|[^[:alnum:]_])func[[:space:]]+TestMain[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])(pytest\.skip|pytest\.xfail)[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])t[[:space:]]*\.[[:space:]]*Skip(Now)?[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])(pending|skip)[[:space:]]*(["\047]|$)/) ||
             (l ~ /(^|[^[:alnum:]_])arch[[:space:]]*\(/)
    }
    # A decorator sits on the line ABOVE its test, so it has to be carried forward.
    function is_pre_excluded(l) {
      return (l ~ /^[[:space:]]*@/) && (l ~ /(skip|xfail|Disabled|Ignore)/)
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
             (b ~ /(^|[^[:alnum:]_.])t[[:space:]]*\.[[:space:]]*(is|not|deepEqual|notDeepEqual|true|false|truthy|falsy|throws|throwsAsync|notThrows|regex|like|snapshot|pass|fail|plan|end)[[:space:]]*\(/) ||
             # pytest: the assertion is the `assert` STATEMENT, so there is no paren or dot
             # after the keyword — the clause above cannot see it and every pytest file read
             # as assertion-free once the Python opener started matching.
             (b ~ /(^|[^[:alnum:]_])assert[[:space:]]+[^[:space:]]/) ||
             # Go stdlib testing: a failure is reported, not asserted. Plus testify, whose
             # `assert.` the generic clause already reaches but whose `require.` it does not.
             (b ~ /(^|[^[:alnum:]_.])t[[:space:]]*\.[[:space:]]*(Error|Fatal)f?[[:space:]]*\(/) ||
             (b ~ /(^|[^[:alnum:]_])require[[:space:]]*\.[[:alnum:]_]/) ||
             # RSpec: `expect(x).to eq(2)` is reached by the expect clause above, but its
             # block form `expect { … }.to raise_error`, the one-liner `it { is_expected.to
             # be_valid }` and paren-less `x.should eq(2)` are not.
             (b ~ /(^|[^[:alnum:]_])expect[[:space:]]*\{/) ||
             (b ~ /(^|[^[:alnum:]_])is_expected[[:space:]]*\./) ||
             (b ~ /\.should[[:space:]]+[[:alnum:]_]/)
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
      open = 1; start = NR; excluded = (is_excluded(line) || pre_ex); isgroup = is_group(line)
      pre_ex = 0
      name = line; sub(/^[[:space:]]+/, "", name)
      if (length(name) > 58) name = substr(name, 1, 55) "..."
      body = line
      next
    }
    open { body = body "\n" line; if (is_excluded(line)) excluded = 1 }
    { pre_ex = is_pre_excluded(line) ? 1 : 0 }
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
