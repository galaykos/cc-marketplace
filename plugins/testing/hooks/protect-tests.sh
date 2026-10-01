#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PreToolUse guard against FAKE GREEN: an edit that makes a test stop running rather
# than makes the code pass. DENIES two shapes in a test file, and only in a test file:
#
#   1. a skip/exclusive marker being ADDED (`.skip`, `.only`, `xit(`, `xdescribe(`,
#      `@pytest.mark.skip`, `markTestSkipped`, `$this->markTestIncomplete`, Go's
#      `t.Skip(`, `#[ignore]`, `@Disabled`, `@Ignore`, `it.todo`, and the paren-less
#      Ruby/bats spellings `xit "…" do`, `pending "…"`, `skip "…"`)
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
#   - A paren-less skip whose argument is not a quoted string — `skip` alone on its own
#     line, or `pending reason_variable`. The quote is what tells a skip declaration from
#     `items.skip 2`, so dropping it would deny ordinary Ruby; the narrower miss is the
#     cheaper of the two, and it is a miss, not a false deny.
#   - A skip that was ALREADY in the file: only a newly introduced marker denies, so
#     editing a legitimately-skipped test is never blocked.
#   - Deleting a test file with `rm` — that is a Bash command, and command-guard's
#     territory, not a write tool's.
#   - A marker inside a STRING LITERAL rather than in code — a meta-test asserting
#     `expect(src).toContain("it.skip(")` denies. Deliberately not fixed: telling code
#     from a string with a line regex is guesswork, and guessing wrong in the permissive
#     direction is how a guard becomes decoration. The same-line reason comment clears
#     it in one keystroke, which is the same escape every other case uses. (A marker in
#     a PROSE comment is mostly already exempt: `// TODO: drop the it.skip below` matches
#     the reason pattern.)
#
# BASH WRITES (0.11.2). The host steers file writes through Bash (`cat > f <<EOF`), which
# a Write|Edit matcher never sees. On `Bash`, each heredoc body or echo/printf argument
# text (the two shared blocks below) whose pipeline writes a test path is judged as a
# Write of that path: old text is the file on disk; new text is the chunk for `>`, and
# the file on disk plus the chunk for `>>`/`tee -a`, so an append never reads as emptying
# the file. Chunks of one command compose per target (`> f` then `>> f`) and each target
# is judged once on its final text. Text fed to a command that writes no file
# (`node - <<EOF`, `pytest <<EOF`) is not read, and a Bash call with no write target exits
# before any chunk is read. A `~/` target expands to $HOME; a relative one needs a payload
# cwd and is skipped when the command holds a `cd`/`pushd` (it would resolve wrongly).
# NOT caught on Bash: interpreter writes (python `open()`, php `file_put_contents`),
# `cp`/`mv`/`install` of a prepared test file, `{ …; } > f` groups, a path held in a
# variable, a here-string `<<<`, printf format substitution, `sed -i`/`perl -i` edits
# (their replacement text is not a chunk), a second heredoc opened on one line, any
# target after a writer's first (`tee a.test.ts b.test.ts` judges only a.test.ts),
# emptying with no chunk text (`: > a.test.ts`, `cat other > a.test.ts`, `truncate -s0`),
# a file written across SEVERAL calls (each call is judged alone), a relative target in a
# command holding a `cd`, and a `>>` inside a quoted echo string (read as an append). The
# body of `python3 - <<PY > tests/test_x.py` is judged as the file's text though the
# script is not what lands there (the chunks block's own caveat).
# `rm` of a test file stays command-guard's.
#
# ESCAPE HATCH. A skip is sometimes right: a quarantined flake, an unimplemented
# feature, a platform-specific case. The deny reason names the two ways through —
# write the marker with a same-line reason comment (`// skip: flaky under CI, #1421`),
# which this hook accepts, or set CC_PROTECT_TESTS=off for the session. The reason
# requirement is the point: an intentional skip has one, a fake-green skip does not.
#
# Fail-open on every error path, missing jq included.
# CC_PROTECT_TESTS unset: the /config option cc_protect_tests decides.

# --- option resolver -----------------------------------------------------------
# Canonical copy: templates/blocks/option-resolver.md. Every hook defining cc_option must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# cc_option <ENV_NAME> <default> [<level-file>] prints one line, the first non-empty of: the
# variable ENV_NAME; the first word of <level-file>, if given and readable; the userConfig
# option CLAUDE_PLUGIN_OPTION_<ENV_NAME>, true/false read as on/off; <default>. The shell wins
# because the environment is the one state independently installed plugins share (CC_REMIND
# or CC_BOOST there mutes every plugin at once); the option gives one plugin a /config row.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# Status 0, no stderr: a malformed name, an expansion error that exits bash 5, yields <default>.
# WHAT IT DOES NOT CATCH: a caller passing a variable instead of a literal name, or a value
# outside the switch's vocabulary — each hook still validates the value it gets.
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

# --- bash write targets --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
# cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
# The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
# 233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
# Write|Edit.
# Prints one target path per line, as spelled in the command (relative or absolute).
# Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
# HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
# (`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
# `[sudo] tee [-a] <paths>`, and every file operand of `sed -i`/`-I`/`--in-place` / `perl -i`
# after the script or its `-e`/`-f` arguments, never a redirect word or its target. BSD's
# `-I` always takes the next word as its backup suffix; a `''` or a `.`-led word with no `/`
# right after sed's bare `-i` is read as one too, unless it would be the only file.
# Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed),
# a globbed operand (`sed -i … tests/*.js`: a word with `*`/`?` is dropped), a `\` line
# continuation, sed/perl behind another command word (`gsed`, `/usr/bin/sed`, `env`,
# `xargs`, `command`, `sudo -u x`, `find … -exec sed -i`), a digit- or `&`-led redirect onto
# a file (`2> f`, `&> f`). A lone `&` does not end a command, so words after it can read as
# sed/perl/tee operands.
# The caller filters to existing files under its root.
cc_bash_write_targets() {
  printf '%s\n' "$1" | awk '
    function emit(p) {
      gsub(/^["\047]|["\047]$/, "", p)
      if (p == "" || p ~ /^\/dev\// || p ~ /[$`*?]/ || p ~ /^[&0-9-]/ && p !~ /[\/.]/) return
      print p
    }
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, x, c, a, inp, scr, eo, sfx, nf, f) {
      rest = ms; off = 0
      while (match(rest, /(^|[^0-9&=<>-])>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t&|;<>()"\047]+)/)) {
        tok = substr(os, off + RSTART, RLENGTH)
        off += RSTART + RLENGTH - 1; rest = substr(ms, off + 1)
        sub(/^[^>]*>>?[ \t]*/, "", tok)
        emit(tok)
      }
      n = 0; j = 1
      while (j <= length(ms)) {
        while (j <= length(ms) && substr(ms, j, 1) ~ /[ \t]/) j++
        if (j > length(ms)) break
        st = j; while (j <= length(ms) && substr(ms, j, 1) !~ /[ \t]/) j++
        n++; ws[n] = st; we[n] = j - 1
      }
      if (n == 0) return
      k = 1; word = substr(os, ws[1], we[1] - ws[1] + 1)
      if (word == "sudo" && n > 1) { k = 2; word = substr(os, ws[2], we[2] - ws[2] + 1) }
      if (word == "tee") {
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1)
          if (w == "<" || w == "<<<") { k++; continue }
          if (w !~ /^-/ && w !~ /^[<>0-9]/) emit(w)
        }
      } else if (word == "sed" || word == "perl") {
        inp = 0; scr = 0; eo = 0; sfx = ""; nf = 0
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1); x = substr(ms, ws[k], we[k] - ws[k] + 1)
          if (x ~ /[<>]/) {
            a = substr(w, 1, match(x, /[<>]/) - 1)
            if (a !~ /^[0-9&]*$/) f[++nf] = a
            if (x ~ /[<>][&|]?$/) k++
            continue
          }
          if (eo || x !~ /^-./) { f[++nf] = w; if (word == "perl") eo = 1; continue }
          if (x == "--") { eo = 1; continue }
          if (x ~ /^--/) {
            if (word == "sed" && x ~ /^--in-place(=|$)/) inp = 1
            if (word == "sed" && x ~ /^--(expression|file)(=|$)/) { scr = 1; if (x !~ /=/) k++ }
            continue
          }
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (c == "i" || word == "sed" && c == "I") {
              inp = 1
              if (word == "sed" && j == length(x) && k < n) {
                a = substr(os, ws[k + 1], we[k + 1] - ws[k + 1] + 1); gsub(/^["\047]|["\047]$/, "", a)
                if (c == "I") k++
                else if (a == "" || a ~ /^\.[^\/<>]*$/) { k++; sfx = a }
              }
              break
            }
            if (c == "e" || c == (word == "sed" ? "f" : "E")) { scr = 1; if (j == length(x)) k++; break }
            if (c == (word == "sed" ? "l" : "I")) { if (j == length(x)) k++; break }
            if (word == "perl" && c ~ /[MmFxdDVC]/) break
            if (word == "perl" && c ~ /[l0]/) while (substr(x, j + 1, 1) ~ /[0-7]/) j++
          }
        }
        if (!inp) return
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/) { emit(f[j]); sfx = "" }
        if (sfx != "") emit(sfx)
      }
    }
    skip { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) skip = 0; next }
    {
      line = $0; m = mask(line)
      if (match(m, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        if (substr(m, RSTART, 1) != "<") { RSTART++; RLENGTH-- }
        term = substr(line, RSTART, RLENGTH + 1)
        sub(/^<<-?[ \t]*["\047]?/, "", term); sub(/[^A-Za-z0-9_].*$/, "", term)
        skip = 1
      }
      st = 1
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c == "|" || c2 == "&&") {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

# --- bash write chunks --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-chunks.md. Every hook defining
# cc_bash_write_chunks must carry this block byte-for-byte (pc_shared_blocks).
# cc_bash_write_chunks <command> — what a Bash command puts INTO files: the text a content
# guard reads on Bash where its Write path reads tool_input.content. Prints chunks: a line that
# starts with \036 and carries the WRITER — the pipeline (split on ; && ||, never inside
# quotes) whose targets the caller resolves with cc_bash_write_targets — then the
# chunk's text lines. Two sources, and only two:
#   - a heredoc BODY: the lines between `<<TERM` (`<<-`, quoted or `\`-escaped TERM too)
#     and TERM; writer = the pipeline holding the `<<` (`cat > f <<EOF`,
#     `cat <<EOF | tee -a f`);
#   - the ARGUMENTS of an `echo`/`printf` segment, as written: the rest of the segment after
#     the command word, quotes, escapes and any `> file` redirect kept (so match inside the
#     text, never anchored at its start); writer = its pipeline
#     (`echo "K=v" >> .env.example`, `printf '%s\n' v | tee f`).
# A chunk whose writer names no file is dropped by the caller, so `git commit -F - <<EOF`
# and `echo x | grep y` yield nothing. The body of ANY heredoc whose pipeline writes a file
# is read, whatever consumes it — `python3 - <<PY > out.txt` included, where the script is
# not what lands in out.txt. Accepted: the text sits in a file-writing command either
# way.
# NOT read, stated: a `{ echo …; } > f` group (the redirect sits on the closer, not on
# the echo's pipeline); a here-string `<<<`; printf's format substitution (`printf
# 'K=%s' v` is read as written: the format and the argument, never the substituted
# line); a quoted string or a `\` continuation spanning lines; a second heredoc opened
# on one line.
# mask() copies the one inside cc_bash_write_targets: the block is byte-locked and its
# awk functions are not reachable from outside it.
cc_bash_write_chunks() {
  printf '%s\n' "$1" | awk '
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function echo_args(p, mp,   i, st, seg, out) {
      out = ""; st = 1
      for (i = 1; i <= length(mp) + 1; i++) {
        if (i > length(mp) || substr(mp, i, 1) == "|") {
          seg = substr(mp, st, i - st)
          if (match(seg, /^[ \t]*(echo|printf)[ \t]/)) out = out substr(p, st + RLENGTH, i - st - RLENGTH) "\n"
          st = i + 1
        }
      }
      return out
    }
    inbody { if (trim($0) == term) inbody = 0; else print; next }
    {
      line = $0; m = mask(line); st = 1; opener = ""
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c2 == "&&" || c2 == "||") {
          if (i > st) {
            p = substr(line, st, i - st); mp = substr(m, st, i - st)
            a = echo_args(p, mp)
            if (a != "") printf "\036%s\n%s", p, a
            if (opener == "" && match(mp, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
              t = substr(p, RSTART, RLENGTH)
              sub(/^[^<]*<<-?[ \t]*["\047]?/, "", t); sub(/^\\/, "", t); sub(/[^A-Za-z0-9_].*$/, "", t)
              if (t != "") { opener = p; term = t }
            }
          }
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
      if (opener != "") { printf "\036%s\n", opener; inbody = 1 }
    }'
}
{
  [ "$(cc_option CC_PROTECT_TESTS on)" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

  # Test files only. A skip marker in production code is not this hook's business.
  is_test_path() {
    case "$(basename "$1")" in
      *.test.*|*.spec.*|*Test.php|*Test.java|*Test.kt|*_test.go|*_test.py|test_*.py|*_test.rb|*_spec.rb|*_test.rs|*.test.ts|*.test.tsx) return 0 ;;
    esac
    case "/$1" in
      */tests/*|*/test/*|*/__tests__/*|*/spec/*|*/Tests/*) return 0 ;;
    esac
    return 1
  }

  # `.skip(` and `.only(` must be anchored to a TEST identifier. Unanchored they match
  # `list.stream().skip(1)` in Java, `items.iter().skip(2)` in Rust, and every other
  # iterator/stream adapter of that name — languages this hook deliberately covers, so
  # an ordinary edit to a Java or Rust test file was denied. Found by a branch review
  # before merge. The anchored forms below still catch every real spelling
  # (`it.skip`, `test.only`, `describe.skip`, `Scenario.only`, `it.each(...).skip`)
  # because a test framework's skip always hangs off a test keyword. The `\b` after the
  # keyword list is load-bearing too: `[A-Za-z]*` there let `it` match inside `iter`, so
  # `items.iter().skip(2)` denied — the same false positive one layer down.
  # RSpec AND minitest CALL WITHOUT PARENTHESES, which is how `xit "adds" do`,
  # `pending "not ready"` and a bare `skip "needs db"` walked past a guard whose own header
  # claimed Ruby coverage: every Ruby arm here required a `(`. The paren-less arms below
  # demand a QUOTE after the keyword, because that is what separates a skip declaration
  # from `items.skip 2` or an English word — the same reason the `.skip(` arm is anchored
  # to a test identifier rather than left bare.
  skip_re='(\b(it|test|describe|context|suite|scenario|feature|bench|fixture|story)\b(\.[A-Za-z]+(\([^)]*\))?)*\.(skip|only|todo|failing)[[:space:]]*\(|\bx(it|describe|test|context|specify)[[:space:]]*[("'\''"]|@pytest\.mark\.skip|markTestSkipped|markTestIncomplete|\bt\.Skip(Now)?[[:space:]]*\(|#\[ignore\]|@Disabled\b|@Ignore\b|\bpending[[:space:]]*\(|\b(pending|skip)[[:space:]]+["'\'']|\.skipIf[[:space:]]*\()'

  # Reads tool, file, new and old; sets hit, empty when the write is allowed.
  judge_tests() {
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
        # An intentional skip carries its reason on the same line. Accept those — but
        # judge only the ADDED marker lines. Counting every marker line in `new` denied an
        # edit whose own new marker was properly reasoned whenever the same hunk carried a
        # pre-existing unreasoned one through unchanged, which made the documented escape
        # hatch fail exactly when it was used. Found by a branch review before merge.
        reason_re='(#|//|/\*|\*)[[:space:]]*(skip|todo|reason|why|flaky|quarantin|pending|because)|reason[[:space:]]*[:=]'
        prior="$old"
        if [ "$tool" = "Write" ] || [ -z "$old" ]; then
          [ -f "$file" ] && prior=$(cat "$file" 2>/dev/null)
        fi
        # Lines carrying a marker, minus the ones that were already there verbatim.
        added_markers=$(printf '%s\n' "$new" | grep -E "$skip_re" \
          | grep -vxF "$(printf '%s\n' "$prior" | grep -E "$skip_re")" 2>/dev/null)
        [ -z "$added_markers" ] && added_markers=$(printf '%s\n' "$new" | grep -E "$skip_re")
        unreasoned=$(printf '%s\n' "$added_markers" | grep -ivE "$reason_re" | grep -c . || true)
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
  }

  hit=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    n=0; keep=0; sep=$(printf '\036')
    while IFS= read -r l; do
      case "$l" in
        "$sep"*)
          tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
          if [ -n "$tgt" ]; then n=$((n + 1)); ctgt[$n]=$tgt; cwrt[$n]=${l#?}; ctext[$n]=""; keep=1; else keep=0; fi ;;
        *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
      esac
    done <<EOF_C
$(cc_bash_write_chunks "$cmd")
EOF_C
    # A relative target after an in-command `cd` would resolve against the wrong directory
    # and read a kept marker as new: skip relative targets then (a miss, never a false deny).
    # Only a `cd` outside heredoc bodies counts; a body line is text and moves nothing.
    hascd=0
    printf '%s\n' "$cmd" | awk '
      inh { if ($0 ~ ("^[\t]*" term "[ \t]*$")) inh = 0; next }
      { print; l = $0; gsub(/<<</, "", l); o = "<<-?[ \t]*[\"\047\\\\]?"
        if (match(l, o "[A-Za-z_][A-Za-z0-9_]*")) { term = substr(l, RSTART, RLENGTH); sub(o, "", term); inh = 1 } }' \
      | grep -qE '(^|[;&|(])[[:space:]]*(cd|pushd)[[:space:]]' && hascd=1
    # Chunks of one command compose per target (`> f` then `>> f`), and each target is
    # judged once on its final text, so a clear-then-append is not read as emptying f.
    m=0; i=1
    while [ "$i" -le "$n" ]; do
      p=${ctgt[$i]}; i=$((i + 1))
      case "$p" in
        /*) ;;
        "~/"*) [ -n "${HOME:-}" ] || continue; p="$HOME/${p#??}" ;;
        *) [ -n "$cwd" ] && [ "$hascd" = 0 ] || continue; p="$cwd/$p" ;;
      esac
      is_test_path "$p" || continue
      k=0; j=1
      while [ "$j" -le "$m" ]; do [ "${tpath[$j]}" = "$p" ] && { k=$j; break; }; j=$((j + 1)); done
      if [ "$k" = 0 ]; then m=$((m + 1)); k=$m; tpath[$k]=$p; tseen[$k]=0; fi
      if printf '%s' "${cwrt[$((i - 1))]}" | grep -qE '(^|[^0-9&>])>>|(^|[[:space:]|])tee([[:space:]]+-[A-Za-z-]+)*[[:space:]]+(-[A-Za-z]*a[A-Za-z]*|--append)([[:space:]]|$)'; then
        if [ "${tseen[$k]}" = 0 ]; then
          ttext[$k]=""
          [ -f "$p" ] && ttext[$k]=$(head -c 1048576 "$p" 2>/dev/null)
        fi
        ttext[$k]="${ttext[$k]}"$'\n'"${ctext[$((i - 1))]}"
      else
        ttext[$k]=${ctext[$((i - 1))]}
      fi
      tseen[$k]=1
    done
    k=1
    while [ "$k" -le "$m" ] && [ -z "$hit" ]; do
      new=${ttext[$k]}; tool=Write; file=${tpath[$k]}; base=$(basename "$file"); old=""
      judge_tests
      k=$((k + 1))
    done
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
    [ -n "$file" ] || exit 0
    is_test_path "$file" || exit 0
    base=$(basename "$file")

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
    judge_tests
  fi

  [ -n "$hit" ] || exit 0

  reason="testing: this edit introduces $hit in $base. A suite that goes green because a test stopped running is a false report, and the drop in test count is invisible in a summary. Fix the code, or — if the skip is genuinely right (a quarantined flake, an unimplemented feature, a platform gap) — put the reason on the same line, e.g. \`it.skip('…')  // skip: flaky on CI, see #1421\`, and this guard allows it. CC_PROTECT_TESTS=off disables the guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
