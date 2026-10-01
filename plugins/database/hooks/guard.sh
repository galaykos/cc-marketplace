#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
# PreToolUse destructive-SQL guard — the name its ask message and the README use. On a
# Write/Edit that introduces one of the shapes below it returns permissionDecision
# "ask", so the user confirms a backup or a tested rollback exists first. It does NOT
# hard-deny: a down-migration legitimately drops, and a deny that fires on the
# legitimate case is a deny that gets turned off.
#
# WHAT IT MATCHES, in priority order (the first hit wins the message; relational data
# loss outranks a lock hazard, which outranks the NoSQL analogues):
#   1. DATA LOSS — DROP TABLE/DATABASE/SCHEMA, TRUNCATE, an unqualified DELETE/UPDATE
#      with no WHERE on the line; Laravel's `Schema::drop*(`; and the LISTED drop
#      spellings of the other migration DSLs, matched case-insensitively and followed
#      by `(` or a Ruby symbol `:` — `dropTable`, `dropTableIfExists`, `drop_table`,
#      `dropSchema`, `drop_schema`, `dropAll`, `drop_all`, plus Django's `DeleteModel`,
#      `RemoveField` and `DeleteField` (Prisma, Drizzle, TypeORM, Doctrine, Knex,
#      Alembic, Rails, GORM, Django). Plus the NoSQL twins: `deleteMany` / `updateMany`
#      / `remove` with an EMPTY filter `({})`, a bare `deleteMany()` (Prisma's
#      delete-everything call takes no argument at all), and `.drop()` /
#      `.dropCollection()` / `.dropDatabase()` / `.dropIndexes()` called with no
#      arguments.
#   2. LOCK HAZARD — `CREATE [UNIQUE] INDEX` with no `CONCURRENTLY`, a table-rewriting
#      `ALTER` (column TYPE change or `SET NOT NULL`), and a DynamoDB `Scan` whose path
#      does not look like a script (`script`, `migration`, `seed`, `backfill`, `bin/`,
#      `tools/`, `__tests__`, `.test.`, `.spec.`). Same ask tier, a different message:
#      these do not lose data, they hold a lock or read the whole table per request.
#
# WHAT IT DOES NOT MATCH, stated because the README tiers this an ask:
#   - A RENAME of a column or table. The expand→migrate→contract rule for that lives
#     in `sql-best-practices` § Migrations and is agent-graded; no regex here reads it.
#   - Documentation surfaces. `.md`, `.mdx`, `.markdown`, `.txt`, `.rst` and anything
#     under `taskmaster-docs/` exit early: a card or spec that QUOTES a migration
#     executes nothing, and gating them would storm one permission prompt per card and
#     stall a headless run that has nobody to answer "ask".
#   - A drop spelled outside the list above — the alternation is literal, not "every
#     DSL". `drop_table 'users'` with a quoted string instead of a Ruby symbol, a name
#     built at runtime, or an ORM that spells it some third way, passes silently.
#   - A destructive statement run through Bash with no file written (`psql <<EOF`,
#     `mysql -e`, `sqlite3 db 'DROP …'`), or fed to a SQL client whose output is logged
#     (`psql <<EOF > run.log`, `… | psql > out.log`) — that stays `command-guard`'s
#     territory, which is why this row yields to it in lane.tsv.
#   - BASH WRITES (0.10.2): heredoc bodies and echo/printf arguments whose pipeline writes
#     a file are scanned like a Write (cc_bash_write_chunks + cc_bash_write_targets), with
#     the same doc-surface exemption applied to the written path (a relative target is
#     joined to the payload cwd first, as a Write's path is absolute). NOT caught:
#     interpreter writes (python open(), php file_put_contents), cp/mv/install of a file
#     already holding the statement, `sed -i`/`perl -i` substitution text, `{ …; } > f`
#     groups, a path held in a variable, a relative target after an in-command `cd`, a
#     doc surface listed first in a multi-target `tee` (only a writer's first target is
#     classified), a here-string, printf format substitution, a quoted string or `\`
#     continuation spanning lines, and a second heredoc opened on one line.
#   - Single-line matching: a DELETE whose WHERE sits on the next line still asks
#     (false positive, accepted), and a filter built across lines never does.
#
# CC_DB_GUARD=off disables it for the session, and the ask message says so.
# CC_DB_GUARD unset: the /config option cc_db_guard decides.
# Fail-open: any error or missing jq allows the write.

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
  input=$(cat)
  # OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
  # uninstalling the plugin. Every other guard in the marketplace ships one,
  # and a global install makes "turn it off here" a real need.
  [ "$(cc_option CC_DB_GUARD on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  # Reads text and flc; sets hit (data loss) or lockhit (lock hazard).
  judge_sql() {
    hit=""
    [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\bdrop[[:space:]]+(table|database|schema)\b' && hit="DROP TABLE/DATABASE/SCHEMA"
    # Laravel's schema builder spells the same statement without the SQL keywords:
    # `Schema::dropIfExists('users')` in a migration's up() IS `DROP TABLE users`. The
    # rule above was blind to it, so the one migration shape an agent writes most in a
    # Laravel repo was the one this guard never asked about. Same ask tier, same escape
    # (a down() legitimately drops).
    [ -z "$hit" ] && printf '%s' "$text" | grep -qE 'Schema::(drop|dropIfExists|dropAllTables|dropAllViews|dropDatabase|dropDatabaseIfExists)[[:space:]]*\(' && hit="a Schema::drop* call (Laravel's DROP TABLE)"
    # Every other migration DSL spells the same statement its own way, and until 2026-09-14
    # this guard recognised exactly one of them — so a Prisma, Drizzle, TypeORM, Doctrine,
    # Knex or Alembic repo got the SQL-keyword rule only, which their DSLs never emit.
    # Shapes, one per tool: Prisma/Drizzle/Knex/Alembic all spell a drop as a call whose
    # name contains `dropTable`/`drop_table`/`dropSchema`/`drop_all`; TypeORM and Doctrine
    # write `dropTable(` / `->dropTable(` in a migration class. Ask tier and escape are
    # identical to the Laravel row: a down()/rollback legitimately drops.
    #
    # Three things this row got wrong until 2026-09-22, each silencing a whole ecosystem:
    # it was case-SENSITIVE, so GORM's `Migrator().DropTable(` never matched; it required
    # a `(`, so Rails' `drop_table :users` never matched; and it listed no Django
    # operation, so `migrations.DeleteModel`/`RemoveField` never matched. `-i`, a second
    # argument form, and the three Django names fix all three. The symbol form REQUIRES a
    # space before the `:` and an identifier after it (`drop_table :users`): a bare `[(:]`
    # also matched `dropAll: boolean` in a TS interface and `dropTable: false` in a config
    # file, both measured, neither a migration. A quoted-string argument
    # (`drop_table 'users'`) still passes — stated in the header.
    [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '(\.|->|\b)(dropTable|dropTableIfExists|drop_table|dropSchema|drop_schema|dropAll|drop_all|DeleteModel|RemoveField|DeleteField)([[:space:]]*\(|[[:space:]]+:[A-Za-z_])' && hit="a drop-table call in a migration DSL (Prisma/Drizzle/TypeORM/Doctrine/Knex/Alembic/Rails/GORM/Django)"
    [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\btruncate[[:space:]]+(table[[:space:]]+)?[^;]' && hit="TRUNCATE"
    # unqualified DELETE/UPDATE: a line with DELETE FROM or UPDATE … SET and no WHERE on it
    if [ -z "$hit" ]; then
      if printf '%s' "$text" | grep -iE '\b(delete[[:space:]]+from|update[[:space:]]+[^;]+[[:space:]]set)\b' \
           | grep -ivE '\bwhere\b' | grep -qiE '(delete[[:space:]]+from|update)'; then
        hit="an unqualified DELETE/UPDATE (no WHERE)"
      fi
    fi
    # Lock-hazard detection (same warn/ask lane): schema changes that take a long-held
    # lock on a large table. Only checked if no destructive hit already fired (data loss wins).
    lockhit=""
    if [ -z "$hit" ]; then
      # CREATE [UNIQUE] INDEX without CONCURRENTLY: a CREATE INDEX line carrying no CONCURRENTLY.
      if printf '%s' "$text" | grep -iE '\bcreate[[:space:]]+(unique[[:space:]]+)?index\b' \
           | grep -qivE '\bconcurrently\b'; then
        lockhit="a CREATE INDEX without CONCURRENTLY (PostgreSQL; other engines lock regardless)"
      fi
      # Table-rewriting ALTERs: a column TYPE change or adding a NOT NULL constraint.
      [ -z "$lockhit" ] && printf '%s' "$text" | grep -qiE '\balter[[:space:]]+table\b[^;]*\balter\b[^;]*\btype\b|\balter[[:space:]]+table\b[^;]*\bset[[:space:]]+not[[:space:]]+null\b' && lockhit="a table-rewriting ALTER (column TYPE change or SET NOT NULL)"
    fi

    # NoSQL analogues of the same two hazards, same warn/ask lane. The relational
    # branches above are blind to them by construction: an unfiltered deleteMany({})
    # is the exact shape of a DELETE with no WHERE, and a Scan on a request path is
    # the read-side twin of a full-table sweep — it is O(table) per request, gets
    # slower as data grows, and passes every test written against a small fixture.
    # Only checked when nothing above fired; relational data loss wins the message.
    if [ -z "$hit" ] && [ -z "$lockhit" ]; then
      # deleteMany / updateMany / remove with an EMPTY filter, and .drop() outright.
      # Prisma spells delete-everything as `deleteMany()` with NO argument, so the
      # empty-object requirement made the commonest shape the one this never asked about.
      # The bare-parens alternative is scoped to `deleteMany` alone on purpose: extending
      # it to `remove` would fire on every DOM `element.remove()`.
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

  hit=""; lockhit=""; file=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    # A non-write Bash call is the common case: exit before any chunk is read.
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    # A chunk whose writer names no file (`psql <<SQL`), or whose text feeds a SQL client
    # even when that client's output is logged (`psql <<SQL > run.log`), executes the SQL:
    # command-guard's lane, so one statement never asks twice.
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
      # Classify the path a Write would carry (absolute), so the doc-surface and script-path
      # tests agree with the Write path; the message keeps the target as spelled.
      case "$file" in
        /*) abs=$file ;;
        "~/"*) abs="${HOME:-}/${file#??}" ;;
        *) abs="${cwd:+$cwd/}$file" ;;
      esac
      flc=$(printf '%s' "$abs" | tr '[:upper:]' '[:lower:]')
      case "$flc" in *.md|*.mdx|*.markdown|*.txt|*.rst|*/taskmaster-docs/*) continue ;; esac
      text=${ctext[$i]}
      judge_sql
    done
  else
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    [ -n "$text" ] || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

    # Documentation surfaces execute nothing — a taskmaster card, README, or spec that
    # QUOTES a migration is prose, not SQL about to run. Gating them would storm a
    # permission prompt per card and, under a headless / ultra-goal run with no one to
    # answer "ask", stall the whole hands-off pipeline. Exempt only unambiguous doc
    # surfaces; .sql, code files, and migration paths still gate.
    flc=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    case "$flc" in
      *.md|*.mdx|*.markdown|*.txt|*.rst|*/taskmaster-docs/*) exit 0 ;;
    esac
    judge_sql
  fi

  [ -n "$hit" ] || [ -n "$lockhit" ] || exit 0

  if [ -n "$hit" ]; then
    reason="destructive-SQL guard: this change introduces ${hit}. Confirm a backup or a tested rollback path exists before applying it, and that the statement is scoped as intended (an unqualified DELETE/UPDATE rewrites every row). Proceed only if that is verified."
  else
    reason="destructive-SQL guard: this change introduces ${lockhit}. On a large table this holds a lock that blocks concurrent reads/writes for the whole operation; prefer the non-blocking path (CREATE INDEX CONCURRENTLY; for a type change or NOT NULL, backfill then validate in a separate step, or add-column-and-copy). Proceed only if the table is small or a maintenance window is planned."
  fi
  [ -n "$file" ] && reason="$reason (file: $file)"
  # Name the escape in the message that blocks you.
  reason="$reason CC_DB_GUARD=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
