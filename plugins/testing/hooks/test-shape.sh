#!/bin/bash
# PostToolUse on an Edit/Write/MultiEdit of a test path: names up to 4 findings per file, 3 files per context: blocks that assert nothing, repeat one body 3+ times differing only in literals, or reach a private member by reflection.
# Misses: test count vs behaviour, duplicate layers across files, a dialect outside the opener set (silent: JUnit @Test, Rust #[test], C++ TEST_F, Elixir) or the assertion set (a false finding); advisory. CC_REMIND=off or CC_TEST_SHAPE=off, else /config; fails open.
# Why, limits, history: rationale/derivations/plugin-testing.md § plugins/testing/hooks/test-shape.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}

{
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  [ "$(cc_option CC_TEST_SHAPE on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0

  case "$fp" in
    *.test.*|*.spec.*|*/tests/*|*/test/*|*Test.php|*_test.py|*_test.go|*_spec.rb) ;;
    *) exit 0 ;;
  esac

  # `-d`, not just `-n`: the mkdir below would rebuild a deleted project tree. Rooted at the repository: one bound per repo, not per subdirectory.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
  [ -n "$root" ] || root="$cwd"

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  MAX_FILES=3          # files reported per context
  MAX_FINDINGS=4       # findings reported per file
  DUP_MIN=3            # blocks sharing a normalized body before it is worth saying

  dir=$(cc_plugin_state "$root" testing)
  state="$dir/shape-$ctx"
  # Unwritable state means silence: a bound that cannot be recorded would warn on every edit.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself
  if [ -r "$state" ]; then
    grep -qxF "$fp" "$state" 2>/dev/null && exit 0          # this file already reported
    [ "$(grep -c . "$state" 2>/dev/null || echo 0)" -ge "$MAX_FILES" ] && exit 0
  fi

  findings=$(awk -v maxf="$MAX_FINDINGS" -v dupmin="$DUP_MIN" '
    # A block runs from one opener to the next, no brace matching. The paren arm needs an argument (Pest `test()->` is no opener); `xit "x" do` is none.
    function is_opener(l) {
      return (l ~ /(^|[^[:alnum:]_])(it|test|describe|context)[[:space:]]*\([[:space:]]*[^)[:space:]]/) ||
             (l ~ /(^|[^[:alnum:]_])(it|describe|context|specify|scenario)[[:space:]]+["\047]/) ||
             (l ~ /function[[:space:]]+test[[:alnum:]_]*[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])def[[:space:]]+test/) ||
             (l ~ /(^|[^[:alnum:]_])func[[:space:]]+Test/) ||
             (l ~ /#\[Test\]/)
    }
    # `describe`/`context` group tests: boundaries, never findings, or every Vitest/Jest/RSpec file reads assertion-free.
    function is_group(l) {
      return (l ~ /(^|[^[:alnum:]_])(describe|context)[[:space:]]*\(/) ||
             (l ~ /(^|[^[:alnum:]_])(describe|context)[[:space:]]+["\047]/)
    }
    # A skip on the opener, on any body line (`pytest.skip(`, `t.Skip(`, `pending`) or in a decorator above excludes a block; Go `TestMain` is setup.
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
             # pytest asserts with a bare `assert` statement: no paren or dot after the keyword.
             (b ~ /(^|[^[:alnum:]_])assert[[:space:]]+[^[:space:]]/) ||
             # Go stdlib reports a failure (`t.Error`, `t.Fatal`); the generic clause does not reach testify `require.`.
             (b ~ /(^|[^[:alnum:]_.])t[[:space:]]*\.[[:space:]]*(Error|Fatal)f?[[:space:]]*\(/) ||
             (b ~ /(^|[^[:alnum:]_])require[[:space:]]*\.[[:alnum:]_]/) ||
             # RSpec forms the expect( clause misses: `expect { … }.to`, `is_expected`, paren-less `x.should eq(2)`.
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
      # The last block absorbs the closing braces of its class or describe(): strip them so it joins its duplicates.
      sub(/[ });]+$/, "", s)
      return s
    }
    # Classified in END: a block in a near-duplicate group is reported once, with its group, never again as assertion-free.
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
      # Duplicate groups first: one line covers N blocks and claims them from the assertion-free list.
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
