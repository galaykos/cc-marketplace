# testing hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the hooks named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed. Each `###` block is a comment block, or a contiguous part of a header, as it stood; the file kept a short summary in its place (a header of at most three lines, a one-line trap), or nothing where the code already says it. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/plugin-testing.md § <path>`. Standing: `recorded` — no gate reads this file, and its dates, measurements, line citations and file names are as they stood on the day it moved.

## plugins/testing/hooks/protect-tests.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.

PreToolUse guard against FAKE GREEN: an edit that makes a test stop running rather
than makes the code pass. DENIES two shapes in a test file, and only in a test file:

  1. a skip/exclusive marker being ADDED (`.skip`, `.only`, `xit(`, `xdescribe(`,
     `@pytest.mark.skip`, `markTestSkipped`, `$this->markTestIncomplete`, Go's
     `t.Skip(`, `#[ignore]`, `@Disabled`, `@Ignore`, `it.todo`, Pest's `})->skip()`,
     `->only()`, `->skipOn…()`, `->skipLocally()`, `->onlyOn…()`, `->todo()` and
     `beforeEach()->skip()`, and the paren-less Ruby/bats spellings `xit "…" do`, `skip "…"`,
     and `pending "…"` in a Ruby file only)
  2. a whole test file being emptied or deleted through Write — content that no
     longer contains a single test function while the file on disk did

WHY THIS AND NOT PROSE. Skipping the failing test to get a green run is the
best-documented way a model reports success it did not earn, and it is invisible in
a summary: the suite passes, the count drops by one, nobody reads counts. Every
collection surveyed on 2026-09-14 ships the doctrine in prose ("never skip a test to
pass"); the model follows it until a test is the last thing between it and done.
`.only` is the same failure inverted — it does not skip one test, it skips all the
others, and a committed `.only` silently shrinks CI to a single case.

WHAT IT DOES NOT CATCH, stated because the README tiers this `gate`:
  - A test weakened rather than skipped (an assertion deleted, an expectation
    loosened to `toBeTruthy`, a `try/except: pass` around the body). That is
    `code-architecture:drift-review`'s agent-graded territory and no regex reaches it.
  - A skip added through a tool this matcher does not name.
  - A paren-less skip whose argument is not a quoted string — `skip` alone on its own
    line, or `pending reason_variable`. The quote is what tells a skip declaration from
    `items.skip 2`, so dropping it would deny ordinary Ruby; the narrower miss is the
    cheaper of the two, and it is a miss, not a false deny.
  - A Pest skip whose argument is on the next line (`->skip()` on the line after `})` is
    read, in a .php file), one whose condition is an expression (`->skip($onCi)`), one after
    `it('x', fn () => …)`, or past a chained call whose argument holds parentheses
    (`->with(fn () => […])`). The matcher reads one line, and Pest's own argument shapes are
    what tell its skip from a Collection's `->skip($n)` — the same miss-over-false-deny trade.
  - A skip that was ALREADY in the file: only a newly introduced marker denies, so
    editing a legitimately-skipped test is never blocked.
  - Deleting a test file with `rm`: no guard stops a plain `rm` of a test file
    (destructive-guard denies only dangerous `rm` targets such as `~`, `.` and `.env`;
    a plain `rm` passes; a recursive one asks when git cannot restore the dir).
  - A marker inside a STRING LITERAL rather than in code — a meta-test asserting
    `expect(src).toContain("it.skip(")` denies. Deliberately not fixed: telling code
    from a string with a line regex is guesswork, and guessing wrong in the permissive
    direction is how a guard becomes decoration. The same-line reason comment clears
    it in one keystroke, which is the same escape every other case uses. (A marker in
    a PROSE comment is mostly already exempt: `// TODO: drop the it.skip below` matches
    the reason pattern.)

BASH WRITES (0.11.2). The host steers file writes through Bash (`cat > f <<EOF`), which
a Write|Edit matcher never sees. On `Bash`, each heredoc body or echo/printf argument
text (the two shared blocks below) whose pipeline writes a test path is judged as a
Write of that path: old text is the file on disk; new text is the chunk for `>`, and
the file on disk plus the chunk for `>>`/`tee -a`, so an append never reads as emptying
the file. Chunks of one command compose per target (`> f` then `>> f`) and each target
is judged once on its final text. Text fed to a command that writes no file
(`node - <<EOF`, `pytest <<EOF`) is not read, and a Bash call with no write target exits
before any chunk is read. A `~/` target expands to $HOME; a relative one needs a payload
cwd and is skipped when the command holds a `cd`/`chdir`/`pushd` (it would resolve wrongly).
NOT caught on Bash: interpreter writes (python `open()`, php `file_put_contents`),
`cp`/`mv`/`install` of a prepared test file, `{ …; } > f` groups, a path held in a
variable, a here-string `<<<`, printf format substitution, `sed -i`/`perl -i` edits
(their replacement text is not a chunk), a second heredoc opened on one line, any
target after a writer's first (`tee a.test.ts b.test.ts` judges only a.test.ts),
emptying with no chunk text (`: > a.test.ts`, `cat other > a.test.ts`, `truncate -s0`),
a file written across SEVERAL calls (each call is judged alone), a relative target in a
command holding a `cd`, and a `>>` inside a quoted echo string (read as an append). The
body of `python3 - <<PY > tests/test_x.py` is judged as the file's text though the
script is not what lands there (the chunks block's own caveat).

ESCAPE HATCH. A skip is sometimes right: a quarantined flake, an unimplemented
feature, a platform-specific case. The deny reason names the two ways through —
write the marker with a same-line reason comment (`// skip: flaky under CI, #1421`),
which this hook accepts, or set CC_PROTECT_TESTS=off for the session. The reason
requirement is the point: an intentional skip has one, a fake-green skip does not.

Fail-open on every error path, missing jq included.
CC_PROTECT_TESTS unset: the /config option cc_protect_tests decides.
```

### Test files only: is_test_path

```text
Test files only. A skip marker in production code is not this hook's business.
```

### skip_re, rspec_re and pest_next_re: anchoring and Pest

```text
`.skip(` and `.only(` must be anchored to a TEST identifier. Unanchored they match
`list.stream().skip(1)` in Java, `items.iter().skip(2)` in Rust, and every other
iterator/stream adapter of that name — languages this hook deliberately covers, so
an ordinary edit to a Java or Rust test file was denied. Found by a branch review
before merge. The anchored forms below still catch every real spelling
(`it.skip`, `test.only`, `describe.skip`, `Scenario.only`, `it.each(...).skip`)
because a test framework's skip always hangs off a test keyword. The `\b` after the
keyword list is load-bearing too: `[A-Za-z]*` there let `it` match inside `iter`, so
`items.iter().skip(2)` denied — the same false positive one layer down.
RSpec AND minitest CALL WITHOUT PARENTHESES, which is how `xit "adds" do`,
`pending "not ready"` and a bare `skip "needs db"` walked past a guard whose own header
claimed Ruby coverage: every Ruby arm here required a `(`. The paren-less arms below
demand a QUOTE after the keyword, because that is what separates a skip declaration
from `items.skip 2` or an English word — the same reason the `.skip(` arm is anchored
to a test identifier rather than left bare.
Paren-less `pending "…"` is RSpec's alone, so that arm reads Ruby files only: in any file it
denied a bash harness whose stub took a mode string (`stub pending 'build'`). Pest chains
`->skip(`/`->only()` onto the test call, which the `.skip(` arm never matched: after `})`, or
after `it(…)`/`test(…)` with no inner parenthesis, past chained calls (`->with([1, 2])`). A
Collection or query builder spells both too, so `->only` needs empty parentheses and `->skip(`
Pest's own argument: none, a quoted reason, a closure or a boolean literal (`->skip(2)`,
`->skip(count($h))` and `->only(['id'])` stay silent). Pest's named helpers (`->skipOnCi()`,
`->skipLocally()`, `->onlyOnLinux()`, `->todo()`) have no Collection twin, so any argument
counts, and `beforeEach()->skip()` skips the whole file. Pest's skip message is not a reason (a
same-line comment is); the shapes this misses are in the header.
A chain split after `})` puts the skip on a line that OPENS with `->` (2026-10-15: it passed).
That arm reads .php files only, with the same argument shapes, so `->skip(2)` on a Collection's
continuation line stays silent; a scheduler's `->skip(fn () => …)` there denies.
```

### Markers added vs already there

```text
Count occurrences added vs already there. A rewrite that carries an existing
marker through unchanged must not deny.
```

### A same-line reason, judged on added marker lines only

```text
An intentional skip carries its reason on the same line. Accept those — but
judge only the ADDED marker lines. Counting every marker line in `new` denied an
edit whose own new marker was properly reasoned whenever the same hunk carried a
pre-existing unreasoned one through unchanged, which made the documented escape
hatch fail exactly when it was used. Found by a branch review before merge.
```

### A relative target after an in-command cd

```text
A relative target after an in-command `cd` would resolve against the wrong directory
and read a kept marker as new: skip relative targets then (a miss, never a false deny).
A `cd` in a heredoc body counts only where this shell may run the body (`. /dev/stdin <<EOF`).
```

### Chunks composed per target

```text
Chunks of one command compose per target (`> f` then `>> f`), and each target is
judged once on its final text, so a clear-then-append is not read as emptying f.
```

## plugins/testing/hooks/test-shape.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
stripped or broken PATH, where `env bash` itself exits 127.

PostToolUse on a written TEST file. Reads the file's BODY and names the test blocks that
do not earn their place. Nothing else in this marketplace reads a test body: every other
mechanism reads a surrogate — the card's Verify line as text (taskmaster verify-teeth),
the runner's collected COUNT (task-runner behavioral-gate, which only fires at zero), the
comment:code ratio (comment-discipline density.sh), or a reviewer's judgment of prose
(testing-best-practices/references/proportionality.md, whose own first line reads
"Standing: agent-graded. No script measures this."). A suite of twenty assertion-free
blocks therefore passes every gate this repo ships, and each gate is correct to pass it.

THREE DETECTORS, chosen because each is a text fact rather than a judgment:
  1. ASSERTION-FREE — a test block with no assertion token from its language's
     vocabulary. This is `it_can_be_instantiated`, and it is coverage theatre's
     load-bearing move: the line executes, so the coverage number moves.
  2. NEAR-DUPLICATE — three or more blocks whose bodies are identical once digit runs
     and quoted strings are blanked. One arithmetic identity restated N times. The
     finding says "parameterize", not "delete", because a boundary sweep looks the same
     and only a reader can tell them apart.
  3. PRIVATE REACH — a block using PHP reflection to reach a non-public member, which
     pins an implementation name so the next rename breaks the test.

STANDING: advisory. `additionalContext` is not a blocking key and this exits 0 on every
path, including every failure. It cannot be a gate, and the reason is on the record
rather than a limitation of effort: proportionality.md:3 refuses a test-count or ratio
threshold (so did lean's cost-model skill, removed 2026-09-14), because there is no
correct ratio — a number would fire on legitimately dense work and wave through a
bloated suite that sits under it. Naming three specific shapes at a location is a
different claim from scoring a count, which is why this ships and a ratio gate does not.

LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - PostToolUse: the file is already on disk. This informs the NEXT write.
  - ONE FILE, NO DIFF. It cannot see test count growing faster than behaviour count —
    the aggregate blind spot code-review/hooks/density.sh names for itself. That
    question stays agent-graded, deliberately.
  - It cannot see duplicate-layer assertions (the same rule proved at the action, the
    controller and the browser): those blocks live in different files and each asserts
    something real.
  - TWO VOCABULARIES, AND THEY FAIL IN OPPOSITE DIRECTIONS. The OPENER set decides
    whether a block exists; the ASSERTION set decides whether it earns its place.
    * A dialect missing from the OPENER set reads as NO TEST FILE, not as assertion-free:
      zero blocks are found, nothing is compared, and the hook is silent. Silence is also
      what a clean file produces, so the gap is invisible from the outside — which is how
      `*_test.py`, `*_test.go` and `*_spec.rb` sat inside the path glob at :82 for a year
      while the opener set matched only JS and PHP. Openers now covered: JS/TS
      (`it(`/`test(`/`describe(` with an argument on the same line, so Pest's `test()->`
      helper is not one), PHP and JS `function test…(`, pytest/minitest
      `def test…`, Go `func Test…`, RSpec/minitest paren-less `it "…" do`, `#[Test]`.
      Still absent, and therefore still SILENT rather than wrong: JUnit/Kotlin `@Test` +
      `void shouldX()`, Rust `#[test] fn …`, C++ `TEST_F(`, Elixir `test "…" do` (`test`
      is only matched with a paren). `*/test/*` admits all of them by path.
    * A dialect missing from the ASSERTION set reads as assertion-free — a false positive
      on correct code, which is the louder failure. The set covers Pest/PHPUnit,
      Vitest/Jest, chai should-style, ava/tape/node:test, pytest's bare `assert`
      statement, Go's `t.Error`/`t.Fatal` and testify's `require.`/`assert.`, and RSpec's
      `expect`/`is_expected`/`should` forms. An assertion inside a project helper whose
      name carries none of those words (`verifyOrder($o)`) still reads as assertion-free:
      accepted rather than widening the vocabulary to any function call. The honest fix
      for either gap is to add the dialect, not to loosen the pattern.
  - It does not judge whether a flagged near-duplicate group is bloat or a boundary
    sweep, and does not detect a test that merely restates the spec.
  - ITS COST IS UNMETERED, and not because nobody looked. `scripts/context-budget.sh`
    measures the dynamic channel with one synthetic `Edit`, and that Edit does not target
    a test path — so this hook returns nothing during measurement and scores 0 in the
    table while the message it emits on a real test write is ~120 tokens. Same class as
    the two gaps that script already reports by name (skill BODIES, remote MCP). The
    bounds above are what stands in for a meter: 4 findings per file, 3 files per context.

Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
CC_TEST_SHAPE=off silences only this one.
CC_REMIND / CC_TEST_SHAPE unset: the /config options cc_remind / cc_test_shape decide.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/testing/ is only the fallback.

FAIL-OPEN: missing jq or awk, unreadable file, unwritable state dir, or any error
exits 0 with no output.
```

### The test-path globs

```text
Test-path globs: the same three rules.tsv already trusts for test routing, plus the
xUnit filename conventions. Every non-test write leaves through this case statement.
```

### The payload cwd tested with -d, and the repository root

```text
`-d`, not just `-n`: the payload's cwd is where the session STARTED, and a session
outlives the directory — `mkdir -p "$dir"` below rebuilt a deleted three-level project
tree so it could hold this hook's state file. `.claude/testing` has exactly one writer
(this hook), so unlike the code-review battery it is free to re-root: one bound per
REPOSITORY is what "3 files per context" was always meant to mean, and a subagent
running from a subdirectory otherwise gets its own fresh budget. Shape copied from
overseer/hooks/track-read.sh's `[ -d "$cwd" ]` test. Does NOT catch a cwd that exists but is the wrong
checkout, and outside a git repo the root is the cwd exactly as before.
```

### The context key, hashed

```text
CONTEXT KEY, not session key: a subagent shares its parent's session_id while getting
its own transcript, and PostToolUse is the only hook channel that reaches subagents at
all — which is where fan-out tests actually get written. HASHED before it becomes a
filename: the key is normally an absolute path, and interpolating one raw names a
nested file whose parents are never created, so every write fails and the bound
silently stops existing. Gated by pc_context_key and pc_marker_key respectively.
```

### Unwritable state means silence

```text
A bound that cannot be recorded is not a bound: unwritable state means silence, not a
warning on every edit for the rest of the run. Same rule as comment-discipline.
```

### is_opener: block boundaries and the opener set

```text
Block boundaries only need to be good enough to bucket lines, so there is no brace
matching here: a block runs from one test opener to the next.
The FOUR-dialect opener set below is what decides whether this hook sees a file at
all. The path glob at :82 already admits `*_test.py`, `*_test.go` and `*_spec.rb`; for
a year the opener set did not, so all three detected zero blocks and the hook was
silent on them — not wrong, ABSENT, which no limitation disclosed. The paren-less
arm is RSpec/minitest (`it "adds" do`), and it is anchored on `[^[:alnum:]_]` so
`xit "later" do` is not an opener: a skipped block is excluded in every other dialect
and must not become a finding here.
The paren arm needs an argument after the `(`: in Pest `test()` returns the running
test case, so a `test()->account` line inside a hook or a test body split it into a
hollow block and the hook reported assertion-free tests that were not (2026-10-14).
Residual: an opener whose title starts on the NEXT line (`it(` alone) is not seen.
```

### is_group

```text
`describe`/`context` GROUP tests; they are boundaries but never findings. Without
this they read as assertion-free by construction — a false positive on every
correctly written Vitest/Jest/RSpec file, which would have made the hook noise.
```

### is_excluded

```text
A block that DECLARES it does not run is never a finding. In JS the declaration is on
the opener (`it.skip(`); in Python, Go and Ruby it is a line INSIDE the body
(`pytest.skip(`, `t.Skip(`, RSpec `pending`/bare `skip`) or a decorator on the line
ABOVE (`@pytest.mark.skip`), which is why this is now tested against every line of a
block rather than its first. `func TestMain(m *testing.M)` is the Go suite entry point,
not a test: it wires setup and calls m.Run(), so it carries no assertion by
construction and would be flagged on every Go package that has one.
```

### has_assertion: pytest

```text
pytest: the assertion is the `assert` STATEMENT, so there is no paren or dot
after the keyword — the clause above cannot see it and every pytest file read
as assertion-free once the Python opener started matching.
```

### has_assertion: Go and testify

```text
Go stdlib testing: a failure is reported, not asserted. Plus testify, whose
`assert.` the generic clause already reaches but whose `require.` it does not.
```

### has_assertion: RSpec

```text
RSpec: `expect(x).to eq(2)` is reached by the expect clause above, but its
block form `expect { … }.to raise_error`, the one-liner `it { is_expected.to
be_valid }` and paren-less `x.should eq(2)` are not.
```

### normalize: the trailing punctuation

```text
Strip a trailing run of structural punctuation. Blocks are delimited by the NEXT
opener, so the last block in a file absorbs the closing braces of its class or
describe() — which made its body differ from its own duplicates and left the last
of N identical tests permanently outside the group it belongs to.
```

### flush: blocks recorded, classified in END

```text
Blocks are RECORDED here and classified in END, because a block cannot be classified
until every block is known: one that belongs to a near-duplicate group is reported
as part of that group and not a second time as assertion-free, or three restatements
of one identity spend three of the four finding slots saying the same thing.
```

### END: duplicate groups first

```text
Duplicate groups first: one line covers N blocks, so it is the densest finding and
it claims those blocks, keeping them out of the assertion-free list below.
```
