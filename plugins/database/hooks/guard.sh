#!/bin/bash
# PreToolUse on Write/Edit/MultiEdit and Bash heredoc/echo writes: asks (never denies) before a change adds DROP, TRUNCATE, a DELETE/UPDATE with no WHERE, a migration-DSL drop, an empty-filter deleteMany/remove or .drop(), or a lock hazard (CREATE INDEX without CONCURRENTLY, a rewriting ALTER, a DynamoDB Scan off a script path).
# Misses: a rollback method (down/downgrade), renames, doc surfaces (.md .mdx .markdown .txt .rst, taskmaster-docs/), a drop off its list (`drop_table 'users'`, a runtime-built name), lowercase `truncate x`, SQL run by a client with no file written (command-guard's), scratch targets, a CREATE INDEX in a SQLite project, a filter built across lines (a WHERE on the next line still asks). On Bash: interpreter writes (python open(), php file_put_contents), cp/mv/install, `sed -i`/`perl -i` text, `{ …; } > f` groups, a path in a variable, a relative target after an in-command `cd`, a doc surface listed first in a multi-target `tee`, a here-string, printf format substitution, a quoted string or `\` continuation spanning lines, a second heredoc on one line. CC_DB_GUARD=off, else /config cc_db_guard; fails open.
# Why, limits, history: rationale/derivations/plugin-database.md § plugins/database/hooks/guard.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
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

# Shared block templates/blocks/bash-write-targets.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-targets.md
# cc_bash_write_targets <command> prints each path the command writes through `>`/`>>`, `[sudo] tee` or `sed -i`/`perl -i`,
# one per line as spelled; heredoc bodies and quoted text never match. A path guard keeps existing files under its root.
# A backup suffix is never a target: the word after BSD sed's -I, or a `''` or `.`-led word after a bare sed -i unless it is the only file.
# Misses: interpreter writes, cp/mv/install, a path in a variable, a glob, a `\` line continuation, a digit- or &-led
# redirect and `>&`, sed/perl/tee behind another command word (gsed, /usr/bin/sed, env, xargs, sudo -u), a `-`-led
# operand with no `/` or `.`, operands cut short by a `&` inside `$(( ))`/`${ }`, every line after a `<<\EOF` opener.
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
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/ || eo) { emit(f[j]); sfx = "" }
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
        if (i > length(m) || c == ";" || c == "|" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||" || c2 == "|&") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

# Shared block templates/blocks/bash-write-chunks.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-chunks.md
# cc_bash_write_chunks <command> prints a \036 + WRITER line, then the text as written, per heredoc body and echo/printf
# argument list, any `> file` redirect kept (never anchor a match); the caller resolves WRITER with cc_bash_write_targets.
# mask() repeats the one in cc_bash_write_targets: a byte-locked block's awk program cannot call another block's functions.
# Misses: `{ echo …; } > f`, here-strings, printf's substituted output, a string or `\` continuation spanning lines,
# two heredocs on one line, text after a `&` inside `$(( ))`/`${ }`.
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
        if (i > length(m) || c == ";" || c2 == "||" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>|]/) {
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

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

# Shared block templates/blocks/write-scope.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/write-scope.md
# cc_scope_init <state root> sets the roots a written path is judged against, each symlink-resolved: CLAUDE_PROJECT_DIR, which the
# shell's cd does not move, <state root> (cc_state_root of the payload cwd, empty for none) and $TMPDIR (default /tmp).
# cc_scope_skip <path>: status 0 for scratch, a target under neither root or under the temp dir while the root holding it is not;
# a path not created yet is judged by its nearest existing directory (cc_scope_dir prints it resolved). cc_scope_root <dir> sets
# cc_scope_r to the root holding a resolved dir, the state root first; status 1 when neither does.
# Misses: a sibling repo or worktree written by absolute path from outside both roots is skipped; with no cwd and no
# CLAUDE_PROJECT_DIR only the temp-dir rule holds.
cc_scope_init() {
  cc_scope_pd=""; [ -z "${CLAUDE_PROJECT_DIR:-}" ] || cc_scope_pd=$(CDPATH= cd -- "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P) || cc_scope_pd=""
  cc_scope_sr=""; [ -z "${1:-}" ] || cc_scope_sr=$(CDPATH= cd -- "$1" 2>/dev/null && pwd -P) || cc_scope_sr=""
  cc_scope_tmp=$(CDPATH= cd -- "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || cc_scope_tmp=""
  cc_scope_pd=${cc_scope_pd%/}; cc_scope_sr=${cc_scope_sr%/}; cc_scope_tmp=${cc_scope_tmp%/}
}
cc_scope_dir() {
  local d
  d=$(dirname -- "$1")
  while [ ! -d "$d" ]; do d=$(dirname -- "$d"); done
  CDPATH= cd -- "$d" 2>/dev/null && pwd -P
}
cc_scope_root() {
  local r
  cc_scope_r=""
  for r in "$cc_scope_sr" "$cc_scope_pd"; do
    [ -n "$r" ] || continue
    case "$1/" in "$r"/*) cc_scope_r=$r; return 0 ;; esac
  done
  return 1
}
cc_scope_skip() {
  local d
  d=$(cc_scope_dir "$1") || return 1
  if cc_scope_root "$d"; then
    [ -n "$cc_scope_tmp" ] || return 1
    case "$cc_scope_r/" in "$cc_scope_tmp"/*) return 1 ;; esac
  elif [ -n "$cc_scope_sr$cc_scope_pd" ]; then
    return 0
  fi
  [ -n "$cc_scope_tmp" ] || return 1
  case "$d/" in "$cc_scope_tmp"/*) return 0 ;; esac
  return 1
}

{
  input=$(cat)
  [ "$(cc_option CC_DB_GUARD on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  # Scratch (the write-scope block: under $TMPDIR, or outside both roots) is not the project; computed only for a target that would ask.
  scoped=""; sroot=""
  scope_init() {
    [ -z "$scoped" ] || return 0
    scoped=1
    cwd=${cwd:-$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)}
    [ -z "$cwd" ] || sroot=$(cc_state_root "$cwd") || sroot=""
    cc_scope_init "$sroot"
  }
  out_of_scope() { scope_init; cc_scope_skip "$1"; }
  # SQLite has no CREATE INDEX CONCURRENTLY. Laravel's .env is not read: DB_CONNECTION=sqlite is its default local config, whatever production runs.
  sqlite_project() { # <path>
    local d f root
    scope_init
    d=$(cc_scope_dir "$1") && cc_scope_root "$d" || return 1
    root=$cc_scope_r
    while :; do
      case "$d/" in "$root"/*) ;; *) return 1 ;; esac
      for f in "$d/wrangler.toml" "$d/wrangler.json" "$d/wrangler.jsonc"; do [ -f "$f" ] && grep -q 'd1_databases' "$f" && return 0; done
      [ -f "$d/prisma/schema.prisma" ] && grep -qE '^[[:space:]]*provider[[:space:]]*=[[:space:]]*"sqlite"' "$d/prisma/schema.prisma" && return 0
      for f in "$d"/drizzle.config.*; do [ -f "$f" ] && grep -qE "dialect[\"' ]*:[[:space:]]*[\"'](sqlite|turso)" "$f" && return 0; done
      [ "$d" != "$root" ] || return 1
      d=$(dirname -- "$d")
    done
  }

  # Reads text and flc; sets hit (data loss) or lockhit (lock hazard).
  judge_sql() {
    hit=""
    # A rollback method, its opener leading the line, is cut to the next method before judging; a \036 line restarts the cut between MultiEdit edits.
    case "$flc" in
      migrations/*.php|*/migrations/*.php) rbo='^[ \t]*((public|protected|private|static|final)[ \t]+)*function[ \t]+down[ \t]*[(]' rbe='function[ \t]+&?[A-Za-z_]' ;;
      db/migrate/*.rb|*/db/migrate/*.rb) rbo='^[ \t]*def[ \t]+down([ \t;(]|$)' rbe='^[ \t]*def[ \t]' ;;
      alembic/versions/*.py|*/alembic/versions/*.py|migrations/versions/*.py|*/migrations/versions/*.py) rbo='^def[ \t]+downgrade[ \t]*[(]' rbe='^def[ \t]' ;;
      *) rbo='' ;;
    esac
    [ -n "$rbo" ] && text=$(printf '%s\n' "$text" | awk -v o="$rbo" -v e="$rbe" '$0 == "\036" { s = 0; next } $0 ~ o { s = 1; next } $0 ~ e { s = 0 } !s')
    [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\bdrop[[:space:]]+(table|database|schema)\b' && hit="DROP TABLE/DATABASE/SCHEMA"
    # Laravel's `Schema::dropIfExists('users')` is `DROP TABLE users` without the SQL keywords.
    [ -z "$hit" ] && printf '%s' "$text" | grep -qE 'Schema::(drop|dropIfExists|dropAllTables|dropAllViews|dropDatabase|dropDatabaseIfExists)[[:space:]]*\(' && hit="a Schema::drop* call (Laravel's DROP TABLE)"
    # Case-insensitive; the symbol form needs a space before `:` and a name after (`drop_table :users`), so `dropAll: boolean` stays silent.
    [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '(\.|->|\b)(dropTable|dropTableIfExists|drop_table|dropSchema|drop_schema|dropAll|drop_all|DeleteModel|RemoveField|DeleteField)([[:space:]]*\(|[[:space:]]+:[A-Za-z_])' && hit="a drop-table call in a migration"
    # Uppercase `TRUNCATE <x>`, or any-case `truncate table <name>` off a class list: Tailwind's `truncate` and `truncate table-cell` must stay silent.
    [ -z "$hit" ] && { printf '%s' "$text" | grep -qE '\bTRUNCATE[[:space:]]+[^;]' || printf '%s' "$text" | grep -iE '\btruncate[[:space:]]+table[[:space:]]+[^;[:space:]]' | grep -vE '(class(Name)?=|class:|\b(clsx|cn|cva)\(|\btw`)' | grep -q .; } && hit="TRUNCATE"
    # unqualified DELETE/UPDATE: a line with DELETE FROM or UPDATE … SET and no WHERE on it
    if [ -z "$hit" ]; then
      if printf '%s' "$text" | grep -iE '\b(delete[[:space:]]+from|update[[:space:]]+[^;]+[[:space:]]set)\b' \
           | grep -ivE '\bwhere\b' | grep -qiE '(delete[[:space:]]+from|update)'; then
        hit="an unqualified DELETE/UPDATE (no WHERE)"
      fi
    fi
    # Lock hazards are checked only when no data-loss hit fired: data loss wins the message.
    lockhit=""
    if [ -z "$hit" ]; then
      # CREATE [UNIQUE] INDEX without CONCURRENTLY: a CREATE INDEX line carrying no CONCURRENTLY.
      if printf '%s' "$text" | grep -iE '\bcreate[[:space:]]+(unique[[:space:]]+)?index\b' \
           | grep -qivE '\bconcurrently\b' && ! sqlite_project "$target"; then
        lockhit="a CREATE INDEX without CONCURRENTLY (PostgreSQL; other engines lock regardless)"
      fi
      # Table-rewriting ALTERs: a column TYPE change or adding a NOT NULL constraint.
      [ -z "$lockhit" ] && printf '%s' "$text" | grep -qiE '\balter[[:space:]]+table\b[^;]*\balter\b[^;]*\btype\b|\balter[[:space:]]+table\b[^;]*\bset[[:space:]]+not[[:space:]]+null\b' && lockhit="a table-rewriting ALTER (column TYPE change or SET NOT NULL)"
    fi

    # NoSQL twins, only when nothing above fired: an empty-filter delete is a DELETE with no WHERE, a request-path Scan a full-table read.
    if [ -z "$hit" ] && [ -z "$lockhit" ]; then
      # Bare `deleteMany()` is Prisma's delete-everything; the bare-parens arm stays off `remove`, which every DOM element.remove() would hit.
      if printf '%s' "$text" | grep -qE '\b(deleteMany|updateMany|remove)\([[:space:]]*\{[[:space:]]*\}|\bdeleteMany\([[:space:]]*\)'; then
        hit="an unfiltered deleteMany/updateMany/remove (empty filter matches every document)"
      elif printf '%s' "$text" | grep -qE '\.drop(Collection|Database|Indexes)?\([[:space:]]*\)'; then
        hit="a collection/database drop"
      # DynamoDB Scan outside a script/migration path: full-table read per request.
      elif printf '%s' "$text" | grep -qE '\b(ScanCommand|\.scan\()' \
        && ! printf '%s' "$flc" | grep -qE '(script|migration|seed|backfill|bin/|tools/|__tests__|\.test\.|\.spec\.)'; then
        lockhit="a DynamoDB Scan outside a script path (reads the whole table per request; derive a key schema or a GSI from the access pattern instead)"
      fi
    fi
  }

  hit=""; lockhit=""; file=""; target=""; cwd=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    # A non-write Bash call is the common case: exit before any chunk is read.
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    # A chunk fed to a SQL client, even one whose output is logged (`psql <<SQL > run.log`), executes it: command-guard's lane, never asked twice.
    sqlcli='(^|[|;&(])[[:space:]]*(sudo[[:space:]]+)?(psql|mysql|mariadb|sqlite3|sqlcmd|clickhouse-client)([[:space:]]|$)'
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    n=0; keep=0; sep=$(printf '\036')
    while IFS= read -r l; do
      case "$l" in
        "$sep"*)
          tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
          printf '%s' "${l#?}" | grep -qE "$sqlcli" && tgt=""
          if [ -n "$tgt" ]; then n=$((n + 1)); ctgt[$n]=$tgt; ctext[$n]=""; keep=1; else keep=0; fi ;;
        *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
      esac
    done <<EOF_C
$(cc_bash_write_chunks "$cmd")
EOF_C
    i=0
    while [ "$i" -lt "$n" ] && [ -z "$hit" ] && [ -z "$lockhit" ]; do
      i=$((i + 1))
      file=${ctgt[$i]}
      # Classify the absolute path a Write would carry, so both branches agree; the message keeps the target as spelled.
      case "$file" in
        /*) abs=$file ;;
        "~/"*) abs="${HOME:-}/${file#??}" ;;
        *) abs="${cwd:+$cwd/}$file" ;;
      esac
      flc=$(printf '%s' "$abs" | tr '[:upper:]' '[:lower:]')
      case "$flc" in *.md|*.mdx|*.markdown|*.txt|*.rst|*/taskmaster-docs/*) continue ;; esac
      text=${ctext[$i]}; target=$abs
      judge_sql
      if { [ -n "$hit" ] || [ -n "$lockhit" ]; } && out_of_scope "$abs"; then hit=""; lockhit=""; fi
    done
  else
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n\u001e\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    [ -n "$text" ] || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

    # Doc surfaces execute nothing, and an ask per card quoting a migration stalls a headless run; .sql, code and migration paths still ask.
    flc=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    case "$flc" in
      *.md|*.mdx|*.markdown|*.txt|*.rst|*/taskmaster-docs/*) exit 0 ;;
    esac
    target=$file
    judge_sql
    { [ -n "$hit" ] || [ -n "$lockhit" ]; } && out_of_scope "$file" && exit 0
  fi

  [ -n "$hit" ] || [ -n "$lockhit" ] || exit 0

  if [ -n "$hit" ]; then
    reason="destructive-SQL guard: this change adds ${hit}. Confirm a backup or tested rollback exists and that it touches only the rows you mean."
  else
    reason="destructive-SQL guard: this change adds ${lockhit}, which is slow on a large table and can block other queries. Use the non-blocking form (CREATE INDEX CONCURRENTLY; for a type change add a column and copy; for NOT NULL backfill, then validate) unless the table is small or a maintenance window is planned."
  fi
  [ -n "$file" ] && reason="$reason (file: $file)"
  # Name the escape in the message that blocks you.
  reason="$reason CC_DB_GUARD=off turns this check off."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
