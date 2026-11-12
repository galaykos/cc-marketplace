#!/bin/bash
# PreToolUse on Bash and MCP shell/SQL tools: denies irreversible data loss, asks on scoped destruction, on a git hook or signing bypass and on gh publishing review text, denies a write to the allow-file, asks before a Write replaces a live .env; .claude/command-guard-strict only raises a verdict. --check '<command>' prints the tier whatever the mode and exits 0/1/2 = allow/ask/deny.
# Misses an allow-file path built from a variable, glob, script or git-config program; unlisted MCP write tools; a heredoc body fed to anything but a shell or SQL client; some wrapper and git option spellings; a bypass set by export, git alias or GIT_CONFIG_*; review text a script or a query file posts. Fails open on its own errors; past GUARD_DEADLINE it asks. CLAUDE_DESTRUCTIVE_GUARD (else /config): deny-only, ask, off. hooks.json starts it with PATH bash and onFailure: block, so a run that cannot start or overruns 15 s blocks the call.
# Why, limits, history: rationale/derivations/plugin-command-guard.md § plugins/command-guard/hooks/destructive-guard.sh

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

GUARD_VERSION=0.10.0

# Quotes and backslashes go so a quoted evasion (artisan "migrate:fresh") meets the rule the plain form does.
norm_cmd() {
  printf '%s' "$1" \
    | tr '\n\t' '  ' \
    | sed -e "s/[\"'\\\\]//g" -e 's/>/ > /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//'
}

# Git rules are written ` git <subcommand>`, so the global options before it are dropped; where git does not lead only the short list goes, so quoted prose is not read as git.
strip_git_global_options() { # normalised segment, lead word
  local o='-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace)(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)|--no-pager|--no-optional-locks|--literal-pathspecs|--bare' n=6
  [ "$2" = git ] && { o='-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|config-env|attr-source|super-prefix|shallow-file)(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)|--exec-path=[^[:space:]]+|-p|-P|--paginate|--no-pager|--no-optional-locks|--no-replace-objects|--no-lazy-fetch|--no-advice|--(literal|glob|noglob|icase)-pathspecs|--bare'; n=7; }
  printf '%s' "$1" | sed -E "s/(^|[[:space:]])git([[:space:]]+($o))+([[:space:]])/\\1git\\$n/g"
}

# Quote-aware on the RAW string: dequoting first would turn `grep -E "a|rm -rf /"` into a fake rm segment. One walk in END (BWK awk reads RS = "\0" as paragraph mode); after $$' bash and zsh disagree, so `raw` splits on every separator. check_cd_chain copies this walk.
split_segments() {
  printf '%s' "$1" | awk '
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    END {
      n = length(buf); sq = 0; dq = 0; ans = 0; raw = 0; dl = 0; seg = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        d = dl; dl = (c == "$" && !sq && !dq ? d + 1 : 0)
        if (c == "\\" && !raw && (!sq || ans)) { seg = seg c nx; i++; continue }
        if (c == "'"'"'" && !dq && !raw) {
          if (!sq && d > 1) raw = 1; else { if (!sq) ans = (d == 1); sq = !sq }
          seg = seg c; continue
        }
        if (c == "\"" && !sq && !raw) { dq = !dq; seg = seg c; continue }
        if (!sq && !dq) {
          if (c == ";" || c == "\n" || c == "|" || c == "&") {
            if ((c == "|" && nx == "|") || (c == "&" && nx == "&")) i++
            print seg; seg = ""; continue
          }
          if (c == "(" || c == ")" || c == "{" || c == "}") { print seg; seg = ""; continue }
        }
        seg = seg c
      }
      print seg
    }'
}

# Shared block templates/blocks/heredoc-bodies.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/heredoc-bodies.md
# cc_strip_heredoc_bodies <mode> <command> [<reader ERE>] prints the command without the heredoc bodies the scan can place,
# their terminators dropped with them. Mode all drops every such body. Mode inert keeps a body a reader may run: its opener's line
# names a shell (rbash, mksh too), ssh, su, sudo -i/-s, runuser, chroot, exec, xargs, eval, source or `.`, or matches <reader ERE>
# (tested lowercased, unquoted, space-padded), or the reader can sit off that line: a `\` continuation, a trailing | ( { do then
# else, an unquoted $( ) ( ) <( ) but x=$( ), an fd number, a $ or quoted command word, a done/fi/esac/}/) lead. Once it drops a
# body, inert keeps every line if a later line pipes into a reader (other words may sit before it, but a grep or rg lead is a filter
# whatever its pattern names; `.`, source, eval or a $ command word first), or runs eval, a shell's -c or a $ command word after an
# x=$( ) or x="$( )" body. Mode cd is inert with eval, source, `.` and the ERE the only named readers, for a cd test: a body this
# shell runs is kept, one a named subshell runs is not. Every mode keeps every line after a `<<` the scan cannot place (quoted,
# after a #, in arithmetic, ${ } or $[ ], an odd delimiter, a quote or ${ open across its line, a backtick, $$', an unmatched ),
# a terminator with stray blanks) and a body with no terminator.
# Misses: inert drops a body fed to anything else (python3 -, node, at, a function, alias or coproc), written to a script a later
# line runs, or read into a variable by read; a case pattern's ) inside $( ) closes it early.
cc_strip_heredoc_bodies() {
  printf '%s\n' "$2" | heredoc_readers="${3:-}" LC_ALL=C awk -v how="$1" '
    BEGIN {
      rd = ENVIRON["heredoc_readers"]; sw = "((ba|z|da|k|c|tc|a|rba|mk|ok|ya)?sh|fish)"; hr = "[ /](eval|source|\\.) "
      sh = "[ /](" sw "|ssh|su|runuser|chroot|exec|xargs) |[ /](sudo|doas) ([^;&|()]* )?(-[a-z]*[is][a-z]*|--login|--shell) "
      shc = "[ /]" sw "( -[-a-z]+)* -[a-z]*c "
    }
    function reads(w) { return rd != "" && w ~ rd || w ~ hr || how != "cd" && w ~ sh }
    function norm(s) { s = tolower(s); gsub(/\\[^a-z0-9_]/, "", s); gsub(/["\047\\]/, "", s); gsub(/[<>|;&()]/, " & ", s); gsub(/[ \t]+/, " ", s); return " " s " " }
    function delim(s, j,   c, q, w) {
      q = ""; w = ""
      for (; j <= length(s); j++) {
        c = substr(s, j, 1)
        if (q != "") { if (c == q) q = ""; else w = w c; continue }
        if (c ~ /[ \t;&|<>()]/) break
        if (c == "\\") { j++; w = w substr(s, j, 1) } else if (c == "\047" || c == "\"") q = c; else w = w c
      }
      return q == "" ? w : ""
    }
    # One physical line; quote and $( ) state (st: p plain, v after =, q in "", w in ="", a/b arithmetic, e ${, s $[) carry across lines. 1 = ends in \.
    function scan(s,   n, i, c, nx, d, t, w, j) {
      n = length(s); cc = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1); d = dl; dl = 0
        if (sq) {
          if (c == "<" && nx == "<") { off = 1; return 0 }
          if (c == "\\" && ans) i++; else if (c == "\047") sq = 0
          continue
        }
        if (c == "\\") { if (i == n) { dl = d; return 1 }; i++; pc = "x"; cs = 0; continue }
        if (dq) {
          if (c == "\"") { dq = 0; pc = c }
          else if (c == "`" || c == "<" && nx == "<") { off = 1; return 0 }
          else if (c == "$" && nx == "(") {
            if (substr(s, i + 2, 1) == "(") { st = st "b"; i += 2 } else { st = st (dq > 1 ? "w" : "q"); i++ }
            dq = 0; pc = "("; cs = 1
          }
          continue
        }
        if (cs && c !~ /[ \t]/) {
          if (c ~ /[$"`\047]/) cw = 1
          else if (c == ")" || match(substr(s, i, 6), /^(done|fi|esac|[}])([ \t;&|<>)]|$)/)) cl = 1
          else if (match(substr(s, i, 7), /^([{!]|then|do|else|elif|if|while|until)[ \t]/)) { i += RLENGTH - 1; pc = " "; continue }
          cs = 0
        }
        if (c == "\047") { if (d > 1) { off = 1; return 0 }; sq = 1; ans = (d == 1); pc = c; continue }
        if (c == "\"") { dq = 1 + (pc == "="); pc = c; continue }
        if (c == "`") { off = 1; return 0 }
        if (c == "#") {
          if (pc ~ /[ \t\n;&|()<>]/) { cc = i; if (index(substr(s, i), "<<") || substr(s, n, 1) == "\\") off = 1; return 0 }
          hash = 1
        }
        if (c == "$") {
          dl = d + 1
          if (nx == "(") {
            if (substr(s, i + 2, 1) == "(") { st = st "a"; i += 2 } else { st = st (pc == "=" ? "v" : "p"); i++ }
            pc = "("; cs = 1; continue
          }
          if (nx ~ /[{[]/) { st = st (nx == "{" ? "e" : "s"); i++; pc = nx; continue }
        }
        t = substr(st, length(st))
        if (c ~ /[]}[]/ && t == (c == "}" ? "e" : "s")) { if (c == "[") st = st t; else { st = substr(st, 1, length(st) - 1); pc = "x" }; continue }
        if (c == "(") { if (nx == "(") { st = st "a"; i++ } else st = st "p"; pc = c; cs = 1; continue }
        if (c == ")") {
          if (t ~ /^[es]?$/) { off = 1; return 0 }
          if (t ~ /[ab]/) { if (nx != ")") { off = 1; return 0 }; i++ }
          st = substr(st, 1, length(st) - 1); if (t ~ /[qbw]/) dq = 1 + (t == "w")
          pc = "x"; continue
        }
        if (c == "<" && nx == "<") {
          if (substr(s, i + 2, 1) == "<") { i += 2; pc = "<"; continue }
          if (hash || st ~ /[abes]/) { off = 1; return 0 }
          if (st ~ /p/ || sd0 != "" || substr(s, i - 1, 1) ~ /[0-9]/) k2 = 1
          j = i + 2; t = (substr(s, j, 1) == "-"); j += t
          while (substr(s, j, 1) ~ /[ \t]/) j++
          w = delim(s, j)
          if (w !~ /^[A-Za-z0-9_.-]+$/) { off = 1; return 0 }
          term[++nc] = w; tdash[nc] = t
          i++; pc = "<"; continue
        }
        if (c ~ /[;&|]/) cs = 1
        pc = c
      }
      return 0
    }
    { all[++na] = $0 }
    mode == 2 { out[++no] = $0; next }
    mode == 1 {
      t = $0; if (tdash[qi]) sub(/^\t+/, "", t)
      if (t == term[qi]) { if (keep) out[++no] = $0; else held[++nh] = $0; if (++qi > nc) { mode = 0; if (!keep) cut = 1; nh = 0 }; next }
      t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == term[qi]) { for (k = 1; k <= nh; k++) out[++no] = held[k]; nh = 0; out[++no] = $0; mode = 2; next }
      if (keep) out[++no] = $0; else held[++nh] = $0
      next
    }
    {
      out[++no] = $0
      if (cont) cflag = 1
      else { sd0 = st; startq = sq || dq; nc = 0; hash = 0; cw = 0; cl = 0; k2 = 0; cflag = 0; pc = "\n"; cs = 1; lw = ""; dl = 0 }
      lw = lw " " $0
      cont = scan($0)
      if (off) { mode = 2; next }
      if (cont || !nc) next
      if (startq || sq || dq || st ~ /[es]/) { mode = 2; next }
      t = cc ? substr($0, 1, cc - 1) : $0; sub(/[ \t]+$/, "", t)
      keep = how != "all" && (k2 || cw || cl || cflag || st ~ /[pab]/ || t ~ /(\|&?|[({]|(^|[ \t;&|])(do|then|else|elif))$/ || reads(norm(lw)))
      if (!keep && !c0) c0 = no; if (!keep && st ~ /[vw]/) cv = 1
      qi = 1; mode = 1; nh = 0
      next
    }
    END {
      if (mode == 1 && !keep) for (k = 1; k <= nh; k++) out[++no] = held[k]
      for (k = c0; cut && how != "all" && k <= no; k++) {
        t = out[k]; if (t ~ /[|(]&?[ \t]*$/ && k < no) t = t " " out[k + 1]
        u = t = norm(t); r = cv && (t ~ / eval |(^|[;&|]) \$/ || how != "cd" && t ~ shc)
        while (!r && match(u, /\|/)) { u = substr(u, RSTART + 1); p = u; sub(/^( [&(])+ /, " ", p); sub(/[;&|()].*/, " ", p); r = p !~ /^ ([ef]?grep|rg) / && (rd != "" && p ~ rd || how != "cd" && p ~ sh || p ~ /^ (\$[a-z_{]|(\.|source|eval) )/) }
        if (r) { for (k = 1; k <= na; k++) print all[k]; exit }
      }
      for (k = 1; k <= no; k++) print out[k]
    }'
}

lead_word() {
  printf '%s' "$1" | awk '
    # 1 when w is a wrapper option whose value is the next word; env -S is absent: it splits its string into the utility and its arguments.
    function takes(wr, w,   l, s, x) {
      if (wr == "env") { l = "unset|chdir|argv0"; s = "uCPa"; x = "uCPSa" }
      else if (wr == "sudo") { l = "user|group|host|prompt|chdir"; s = "ughpCDrtUT"; x = s }
      else if (wr == "doas") { l = ""; s = "aCu"; x = s }
      else if (wr == "nice") { l = "adjustment"; s = "n"; x = s }
      else if (wr == "ionice") { l = ""; s = "cnp"; x = s }
      else if (wr == "time") { l = ""; s = "fo"; x = s }
      else if (wr == "exec") { l = ""; s = "a"; x = s }
      else return 0
      if (l != "" && w ~ ("^--(" l ")$")) return 1
      return w ~ ("^-[^-" x "]*[" s "]$")
    }
    function lead(vals,   i, w, wr) {
      wr = ""
      for (i = 1; i <= NF; i++) {
        w = $i
        if (w ~ /^(sudo|doas|nohup|time|command|builtin|exec|nice|ionice)$/) { wr = w; continue }
        if (w ~ /^(.*\/)?env$/) { wr = "env"; continue }
        if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
        if (w ~ /^-/) { if ((vals || wr == "env") && takes(wr, w)) i++; continue }
        sub(/^.*\//, "", w)
        return w
      }
      return ""
    }
    # A value skip that leaves no command word (sudo -u rm -rf /) falls back to the unskipped reading, so a misread value keeps the old verdict.
    { l = lead(1); if (l == "") l = lead(0); print l }'
}

READERS=' echo printf cat grep egrep fgrep rg ag ack less more head tail wc sort uniq jq yq column ls tree stat file diff comm man which type printenv true false date basename dirname pwd '

is_reader() {
  local w="$1"
  case "$w" in
    git) return 1 ;;  # `git` is decided by its subcommand, not by being git
    "") return 0 ;;
  esac
  case "$READERS" in *" $w "*) return 0 ;; esac
  return 1
}

# commit can lose nothing, and its message is prose: "remove the drop table step" would otherwise trip the SQL rules.
git_safe_subcmd() {
  case "$1" in
    log|show|diff|status|blame|ls-files|ls-remote|rev-parse|describe|config|remote|fetch|shortlog|grep|cat-file|whatchanged) return 0 ;;
    commit|add|tag|merge|revert|cherry-pick|rebase|pull|clone|init|apply|am|submodule|bisect|notes|mv) return 0 ;;
  esac
  return 1
}

# Matched against the whole command: a heredoc body (mysql <<SQL, DROP TABLE x;) splits into segments that no longer name the client.
SQL_CLIENT_RE=' (mysql|mysqldump|mariadb|psql|pgcli|sqlite3|sqlcmd|mongosh|mongo|redis-cli|clickhouse-client|cockroach|snowsql|usql|sqlplus|dbmate|tinker|artisan|rails|sequelize|knex|prisma|wrangler|supabase|pscale|planetscale|bq|duckdb|influx|cqlsh|turso|libsql|flyway|liquibase|doctrine|alembic|typeorm) '

# TAB-separated: tier (deny or ask; +sql fires only in SQL context), ERE over the space-padded segment, what it does, the alternative.
rules() {
  cat <<'RULES'
deny	[ /]artisan (migrate:(fresh|reset|refresh)|db:wipe)	drops every table in the configured database and re-runs migrations	`php artisan migrate` applies pending migrations without touching existing rows
deny	[ /](rails|rake) db:(drop|reset|schema:load|structure:load|migrate:reset)	drops or reloads the whole schema, discarding every row	`rails db:migrate` for pending migrations
deny	manage.py (flush|sqlflush)( |$)	deletes all rows from every table	a targeted queryset delete, or a fixture load into a test database
deny	manage.py migrate [a-z_]+ zero( |$)	unapplies every migration for the app, dropping its tables	migrate to a named migration instead of `zero`
deny	prisma migrate reset	drops the database and replays all migrations	`prisma migrate dev` for a new migration; `prisma migrate deploy` in CI
deny	prisma db push .*(--force-reset|--accept-data-loss)	rewrites the schema accepting row loss	generate a migration and review its SQL first
deny	sequelize[a-z-]* db:drop	drops the database	`db:migrate:undo` unapplies one migration
deny	db:migrate:undo:all	unapplies every migration, dropping the schema	undo a single migration by name
deny	typeorm schema:drop	drops every table the entities map to	generate and review a migration
deny	knex migrate:rollback .*--all	rolls back every migration, dropping the schema	roll back one batch
deny	alembic downgrade base	unapplies every migration, dropping the schema	downgrade to a named revision
deny	supabase db reset	drops the local/linked database and replays migrations	`supabase migration up`
deny	doctrine:(schema:drop|database:drop)	drops the schema or the database	`doctrine:migrations:migrate`
deny	doctrine:fixtures:load( |$)	purges every table before loading fixtures	add `--append` to load without purging
deny	flyway clean	drops every object in the configured schemas	`flyway migrate`
deny	liquibase (drop-all|dropall)	drops every object in the schema	`liquibase update`
deny	[ /]wp db (reset|drop)	drops the WordPress database	`wp db export` first, then a scoped query
denysql	 drop (table|database|schema)( |$)	an executed DROP removes the object and its data outright	take a dump first, and scope the statement
denysql	 alter table [^;]* drop column 	an executed DROP COLUMN removes the column and every value in it	take a dump first, and scope the statement
denysql	 truncate (table )?[a-z_`\[]	TRUNCATE empties the table and is not transactional on every engine	a DELETE with a WHERE clause inside a transaction
deny	[ /]dropdb( |$)	drops a PostgreSQL database	dump it first
deny	mysqladmin .*drop	drops a MySQL database	dump it first
denysql	(flushall|flushdb)( |$)	empties the Redis keyspace, including anything persisted	delete the specific keys or use a scoped pattern
denysql	dropdatabase\(	drops the MongoDB database	drop the specific collection, after a dump
denysql	\.drop\( *\)	drops the MongoDB collection and every document in it	`deleteMany` with a filter, after a dump
denysql	deletemany\( *\{ *\}	an empty filter matches every document in the collection	pass a filter
deny	 git (filter-branch|filter-repo)	rewrites every commit; old objects become unreachable	work on a copy of the repo, or a scratch clone
deny	 git reflog expire	discards the reflog, which is the recovery path for a bad reset	leave the reflog alone; it expires on its own
deny	 git gc .*--prune=now	prunes unreachable objects immediately, destroying the recovery path	plain `git gc`
deny	 git push( [^ ]+)* (--force|-[a-eg-z]*f[a-z]*)( |$)	overwrites remote history for everyone who has pulled it	`--force-with-lease`, and only on a branch you own
deny	 git push .* [+][a-z0-9_./*-]+( |$|:)	a leading + on the refspec is a force push under another name	`--force-with-lease`, and only on a branch you own
deny	 git push .*(--delete|--mirror)	deletes remote refs	delete the branch in the host UI where it is reviewable
deny	 git push( [^ ]+)* :[^ :]+( |$)	an empty source before the colon deletes the remote ref, as --delete does	delete the branch in the host UI where it is reviewable
deny	 git update-ref -d	deletes a ref directly, bypassing the reflog protections	`git branch -d`
deny	 git clean ((([^ -][^ ]*|-|-[^ -][^ ]*|--[^ ]+) )*(--force|--interactive|--[^ =]+=[^ ]*|[^ -][^ ]*|-([^ e-]|[^ -][^ ]*[^ e-])|--([^ e-]|[^ e-][^ ]*[^ e-])) )?-[a-df-z]*x[a-z]*( |$)	-x also removes IGNORED files: .env, local configs, credentials	`git clean -fd` (leaves ignored files), or `git stash -u`
deny	 rm ([^ ]+ )*\.env( |$|\.)	.env holds the only copy of local credentials; it is not in git	copy it aside first
deny	 > \.env( |$)	truncates .env to empty; the credentials are gone	write to a temp file and move it into place
deny	docker(-| )compose .*down .*(-v( |$)|--volumes)	removes named volumes, which is where the database lives	`docker compose down` keeps volumes
deny	 docker volume (rm|prune)	deletes container volumes and everything stored in them	inspect first; remove one volume by name after a dump
deny	 docker system prune .*(-a|--all|--volumes)	removes volumes and all unused images across the machine	prune images only, or scope to one project
deny	 kubectl delete (ns|namespace|pvc|persistentvolumeclaim|statefulset|sts)( |$)	deletes persistent storage or the whole namespace	scale to zero, or delete a single pod
deny	 terraform destroy	tears down every managed resource, including databases	`terraform plan -destroy` and read it
deny	 pulumi destroy	tears down every resource in the stack	`pulumi preview --diff`
deny	 aws s3 (rb |rm .*--recursive|sync .*--delete)	deletes bucket contents; versioning may not be on	list the keys first, delete a prefix explicitly
deny	 (gsutil|gcloud storage)( [^ ]+)* rm( [^ ]+)* (-[a-z]*r[a-z]*|--recursive)( |$)	deletes every object under the prefix; versioning may not be on	list the objects first, delete a prefix explicitly
deny	 aws [a-z0-9-]+ (delete|terminate|purge)[a-z-]*	an AWS delete/terminate call is not undoable from the CLI	do it in the console where the confirmation names the resource
deny	 (gcloud|az|doctl|pscale|wrangler|flyctl|fly|heroku) .*(delete|destroy)( |$)	a cloud delete removes a live resource for everyone	do it in the provider console
deny	 heroku pg:reset	drops every table in the Heroku Postgres database	`heroku pg:backups:capture` first
deny	 gh (repo|release|secret|cache) delete	deletes a GitHub resource for the whole repository	delete it in the web UI
deny	 firebase( [^ ]+)* firestore:delete( [^ ]+)* --all-collections	deletes every document in every Firestore collection	export first (`gcloud firestore export`), then delete one collection path
deny	 npm unpublish	removes a published package version other projects may depend on	deprecate it instead
deny	 mkfs(\.[a-z0-9]+)?( |$)	formats a filesystem	nothing about this belongs in an agent session
deny	 dd .*of= */dev/	writes directly over a block device	nothing about this belongs in an agent session
deny	 > /dev/(sd|nvme|disk|hd)	writes over a raw disk	nothing about this belongs in an agent session
ask	 git reset --hard	discards every uncommitted change in the working tree	`git stash` keeps them recoverable
ask	 git reset( [^ ]+)* --merge( |$)	resets the index and the files a merge touched, discarding staged changes	`git stash` keeps them recoverable
ask	 git clean 	deletes untracked files, which are not recoverable from git	`git stash -u` stashes untracked files instead
ask	 git checkout (-- )?\.( |$)	discards all unstaged changes	`git stash`
ask	 git checkout( [^ ]+)* (-f|--force)( |$)	throws away local changes to switch or reset the tree	`git stash`, then a plain checkout
ask	 git switch( [^ ]+)* (-f|--force|--discard-changes)( |$)	throws away local changes to switch branches	`git stash`, then a plain switch
ask	 git worktree remove( [^ ]+)* (-f|--force)( |$)	deletes the worktree directory with its uncommitted and untracked files	plain `git worktree remove` refuses when work would be lost
ask	 git restore (-s [^ ]+ |--source[= ][^ ]+ |-w |--worktree |-- )*\.( |$)	discards all unstaged changes	`git stash`
ask	 git restore( [^ ]+)* (-W|--worktree)( [^ ]+)* \.( |$)	discards all unstaged changes	`git stash`
ask	 git branch -D 	force-deletes a branch even if it is unmerged	`git branch -d` refuses when work would be lost
ask	 git stash (clear|drop)	discards stashed work with no reflog to recover it	`git stash list` and drop one entry by index
ask	 git push .*--force-with-lease	rewrites remote history, but only if nobody else pushed	confirm the branch is yours
ask	[ /]artisan migrate .*--force	runs pending migrations in production, including destructive ones	read the pending migrations first
asksql	 delete from 	runs a DELETE from the shell; with no WHERE clause it removes every row	confirm the WHERE clause, and run it inside a transaction
ask	 docker (rm|container rm) .*-f	force-removes running containers	stop them first
ask	 docker system prune	removes unused containers, networks and images	scope it to one project
ask	 kubectl delete 	removes a live cluster object	`--dry-run=client` first
ask	 helm (uninstall|delete) 	removes a release and possibly its storage	`helm get manifest` first
ask	 (terraform|tofu) apply .*-auto-approve	applies without showing the plan, which may include destroys	apply without -auto-approve and read the plan
ask	 vagrant destroy	deletes the VM and its disk	`vagrant halt`
ask	 (vercel|railway|netlify) (remove|rm|down)( |$)	removes a deployment or project	do it in the dashboard
ask	 gh api( [^ ]+)* (-x|--method)( |=)?delete( |$)	sends a DELETE to the GitHub API, removing whatever the endpoint names	read the endpoint first; a repo, release or secret is better deleted in the web UI
ask	 npm publish	publishes to a public registry; the version can never be reused	`npm publish --dry-run`
ask	 find [^ ]* .*-delete( |$)	deletes every path the find matched	drop -delete and read the list first
ask	 (xargs|-exec|-execdir)( [^ ]+)* ([^ ]*/)?rm( [^ ]+)* (-[a-z]*r[a-z]*|--recursive)( |$)	recursively deletes every path find or xargs hands it, none of which the command shows	run it without the rm, read the list, then delete named paths
ask	 (shred|srm) 	overwrites files so they cannot be recovered	plain rm leaves the file recoverable by backup
ask	 truncate -s ?0	empties the file in place	move it aside instead
ask	 history -c	clears the shell history for the user	nothing in the task needs this
ask	 crontab -r( |$)	removes every cron job for the user with no confirmation and no backup	`crontab -l > crontab.bak` first, or `crontab -e` to remove one line
ask	 chmod -[a-z]*r[a-z]* (777|666) 	recursively makes a tree world-writable	set the narrowest mode on the specific path
RULES
}

# An uppercase letter makes a rule case-sensitive, matched on the case-preserved form: git branch -D is not -d.
match_rule_table() { # padded segment, the same lowercased, sql_ctx 0|1
  local segn="$1" segn_lc="$2" sql_ctx="$3" tier re what alt
  while IFS=$'\t' read -r tier re what alt; do
    [ -n "$tier" ] || continue
    case "$tier" in
      *sql) [ "$sql_ctx" -eq 1 ] || continue
            tier="${tier%sql}" ;;
    esac
    if printf '%s' "$re" | grep -q '[A-Z]'; then
      [[ $segn =~ $re ]] && set_verdict "$tier" "$what" "$alt" "$segn"
    else
      [[ $segn_lc =~ $re ]] && set_verdict "$tier" "$what" "$alt" "$segn_lc"
    fi
    [ "$VERDICT" = "deny" ] && break
  done < <(rules)
}

VERDICT=allow   # allow | ask | deny
CWD_MOVED=0     # 1 when the command cds: its relative paths do not resolve against this process's cwd
CD_RE='[ ;&|(](cd|pushd)[ ;&|)]|[ ;&|(/]env( -[upa] [^ ]+| -[^ ]*| [a-z_][a-z0-9_]*=[^ ]*)* (-[a-z]*c|--chdir)[ =]'
V_WHAT=""       # what the command does
V_ALT=""        # the non-destructive alternative
V_MATCH=""      # the segment that matched

V_KIND=""      # "cd" for a failing-cd deny, whose reason invites the corrected retry

set_verdict() { # tier what alt match [kind]
  [ "$VERDICT" = "deny" ] && return 0
  [ "$VERDICT" = "ask" ] && [ "$1" = "ask" ] && return 0
  VERDICT="$1"; V_WHAT="$2"; V_ALT="$3"; V_MATCH="$4"; V_KIND="${5:-}"
}

# Regenerated by a build, so rm -rf on them is ordinary work; a prompt here trains the user to click through prompts.
ARTIFACT_RE='^(\./)?(node_modules|vendor|dist|build|out|target|coverage|\.next|\.nuxt|\.turbo|\.cache|\.parcel-cache|__pycache__|\.pytest_cache|\.venv|venv|tmp|temp|\.tmp|storage/framework/(cache|views|sessions)|bootstrap/cache)/?\*?$'

# Prints what sits under an OS temp root (scratch, so deleting it is ordinary work), nothing when the path is not under one; the roots themselves stay denied.
temp_remainder() { # lowercased token
  local p="$1"
  case "$p" in /private/*) p="${p#/private}" ;; esac   # macOS: /private/tmp IS /tmp
  case "$p" in
    /tmp/*)     printf '%s' "${p#/tmp/}" ;;
    /var/tmp/*) printf '%s' "${p#/var/tmp/}" ;;
    # /var/folders/<ab>/<hash>/<T|C> is the macOS per-user root itself: only awk's field 7 onward is inside it.
    /var/folders/*)
      printf '%s' "$p" | awk -F/ '{ if (NF >= 7 && $7 != "") { s = $7; for (i = 8; i <= NF; i++) s = s "/" $i; print s } }' ;;
  esac
}

is_temp_path() { # lowercased token -> 0 scratch, 1 not
  local p="$1" root="" rest="" first
  # `..` can walk back out of the root, so the prefix stops proving containment.
  case "$p" in *..*) return 1 ;; esac
  # The hook's own TMPDIR/TMP is the Bash tool shell's; unset means unresolvable, so rm -rf $TMPDIR/build falls to the variable ask.
  case "$p" in
    '$tmpdir/'*|'${tmpdir}/'*) root="${TMPDIR:-}"; rest="${p#*/}" ;;
    '$tmp/'*|'${tmp}/'*)       root="${TMP:-}";    rest="${p#*/}" ;;
  esac
  if [ -n "$rest" ]; then
    [ -n "$root" ] || return 1
    p=$(printf '%s/%s' "${root%/}" "$rest" | tr '[:upper:]' '[:lower:]')
  fi
  case "$p" in *'$'*) return 1 ;; esac   # any other variable: expansion unknown
  rest=$(temp_remainder "$p")
  [ -n "$rest" ] || return 1
  # A glob as the first component is the root emptied under another spelling (/tmp/*).
  first="${rest%%/*}"
  case "$first" in ''|'*'|'?'|'.'|'..') return 1 ;; esac
  return 0
}

# "name<TAB>byte offset<TAB>guard" per variable whose every assignment is a lone mktemp substitution, one of them a top-level
# unconditional command (not in ( ), $( ), { }, a block, a heredoc body, a pipeline or after && ||); guard 1 when that is its only
# assignment and a failed mktemp exits instead of emptying it.
mktemp_vars() { # raw command, heredoc bodies stripped; the raw command
  local r="${2:-}"
  [ "$r" != "$1" ] || r=""   # an environment string over 128 KiB fails exec, and then nothing is credited
  printf '%s' "$1" | mk_raw="$r" LC_ALL=C awk '
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    # The heredoc delimiter at j in s, quotes and backslashes removed, "" when a quote stays open; sets de past it.
    function delim(s, j,   c, q, w) {
      q = ""; w = ""
      for (; j <= length(s); j++) {
        c = substr(s, j, 1)
        if (q != "") { if (c == q) q = ""; else w = w c; continue }
        if (c ~ /[ \t\n;&|<>()]/) break
        if (c == "\\") { j++; w = w substr(s, j, 1) } else if (c == "\047" || c == "\"") q = c; else w = w c
      }
      de = j
      return q == "" ? w : ""
    }
    # Past the heredoc bodies opened on the line ending at p: the last terminator'"'"'s end, p if the strip dropped them, -1 if one may run to the end.
    function body(p,   h, q, r, s) {
      for (h = 1; h <= nh; h++) {
        for (q = p; q <= n; q = r) {
          r = index(substr(buf, q + 1), "\n"); r = r ? q + r : n + 1
          s = substr(buf, q + 1, r - q - 1); if (ht[h]) sub(/^\t+/, "", s)
          if (s == hd[h]) break
        }
        if (q <= n) p = r; else if (unterm) return -1
      }
      nh = 0; return p
    }
    # 1 when t opens with || exit [N] or || { ...; exit [N]; }, exit a command word of a flat group: no nesting, pipe, &, && ||, heredoc.
    function exits(t,   m, i, c, cs, f, k, w) {
      if (!sub(/^\|\|[ \t]*/, "", t)) return 0
      if (sub(/^exit([ \t]+[^ \t\n;&|<>(){}`\\"\047]+)?/, "", t)) return t ~ /^[ \t]*($|[\n#;]|&&|\|\|)/
      if (!sub(/^\{[ \t\n]/, "", t)) return 0
      m = length(t); cs = 1; f = 0
      for (i = 1; i <= m; i++) {
        c = substr(t, i, 1)
        if (c == " " || c == "\t") continue
        if (c == "\n" || c == ";") { if (substr(t, i + 1, 1) == ";") return 0; cs = 1; continue }
        if (c == "#" && (cs || substr(t, i - 1, 1) ~ /[ \t]/)) { k = index(substr(t, i), "\n"); if (!k) return 0; i += k - 1; cs = 1; continue }
        if (c == "}" && cs) return f && substr(t, i + 1) ~ /^[ \t]*($|[\n#;]|&&|\|\|)/
        if (c == "&" && (substr(t, i - 1, 1) == ">" || substr(t, i + 1, 1) == ">")) { cs = 0; continue }
        if (c ~ /[|&()<{`]/ || c == "$" && substr(t, i + 1, 1) ~ /[({\047]/) return 0
        if (c == "\047") { k = index(substr(t, i + 1), "\047"); if (!k) return 0; i += k; cs = 0; continue }
        if (c == "\"") {
          for (i++; i <= m && (c = substr(t, i, 1)) != "\""; i++) { if (c == "`" || c == "$" && substr(t, i + 1, 1) == "(") return 0; if (c == "\\") i++ }
          if (i > m) return 0
          cs = 0; continue
        }
        if (c == "\\") { i++; cs = 0; continue }
        if (cs) {
          match(substr(t, i), /^[^ \t\n;&|<>(){}`"\047\\]*/); w = substr(t, i, RLENGTH)
          if (w ~ /^(if|then|else|elif|fi|while|until|do|done|for|select|case|esac|function|coproc)$/) return 0
          if (w == "exit" && substr(t, i + 4, 1) ~ /^([ \t\n;]|)$/) f = 1
          cs = 0; i += RLENGTH - 1 + !RLENGTH
          continue
        }
      }
      return 0
    }
    # 1 when the and-or list going on at k ends in a lone &, which runs all of it in a subshell; 1 too past an if/while/case it does not parse.
    function bg(k,   c, nx, d, op, cs, m) {
      d = 0; op = 0; cs = 0
      for (; k <= n; k++) {
        c = substr(buf, k, 1); nx = substr(buf, k + 1, 1)
        if (c == "\\") { k++; op = cs = 0; continue }
        if (c == "\047") { m = index(substr(buf, k + 1), c); if (!m) return 1; k += m; op = cs = 0; continue }
        if (c == "\"" || c == "`") { for (k++; k <= n && substr(buf, k, 1) != c; k++) if (substr(buf, k, 1) == "\\") k++; if (k > n) return 1; op = cs = 0; continue }
        if (c == "#" && substr(buf, k - 1, 1) ~ /^([ \t\n;&|]|)$/) { m = index(substr(buf, k), "\n"); if (!m) return 0; k += m - 2; continue }
        if (c == "(" || c == "{") { d++; op = 0; cs = 1; continue }
        if (c == ")" || c == "}") { if (!d) return 0; d--; cs = 0; continue }
        if (d || c == " " || c == "\t") continue
        if (c == "\n") { if (!op) return 0; cs = 1; continue }
        if (c == ";") return 0
        if (c == "&") {
          if (nx == "&") { k++; op = cs = 1; continue }
          if (nx == ">" || substr(buf, k - 1, 1) ~ /[<>]/) { op = cs = 0; continue }
          return 1
        }
        if (c == "|") { k += (nx == "|" || nx == "&"); op = cs = 1; continue }
        if (cs && match(substr(buf, k), /^(if|while|until|for|select|case|function|coproc)([ \t\n;&|()]|$)/)) return 1
        op = cs = 0
      }
      return 0
    }
    # The $( ) or backtick opener at j holds only mktemp (|| mktemp fallbacks, 2>/dev/null), not -u: sets e past it and a closing " when q.
    function lone(j, q,   o, k, c, s, p, np, x) {
      o = substr(buf, j, 1) == "`" ? "`" : ")"; k = j + (o == "`" ? 1 : 2); s = ""
      for (; k <= n; k++) { c = substr(buf, k, 1); if (c == o) break; if (c ~ /[(`\n]/) return 0; s = s c }
      if (k > n) return 0
      e = k + 1
      if (q) { if (substr(buf, e, 1) != "\"") return 0; e++ }
      gsub(/2>[ \t]*\/dev\/null/, " ", s)
      np = split(s, p, /\|\|/)
      for (x = 1; x <= np; x++) if (p[x] !~ /^[ \t]*mktemp([ \t][^;&|<>]*)?$/ || p[x] ~ /[ \t]-[A-Za-z]*u|--dr/) return 0
      return 1
    }
    function kw(w, re) { return match(w, "^(" re ")") && substr(w, RLENGTH + 1, 1) ~ /^([ \t\n;&|)]|)$/ ? RLENGTH : 0 }
    END {
      n = length(buf)
      if (buf ~ /(^|[;&|({\n \t])(eval|source)[ \t]|(^|[;&|({\n])[ \t]*\.[ \t]|mktemp[ \t]*\([ \t]*\)|(function|alias)[ \t]+mktemp/) exit
      # A quoted-delimiter heredoc whose body survived the strip feeds another shell that never sees this one'"'"'s variables.
      np = split(buf, p, "\n")
      for (x = 1; x <= np; x++) if (match(p[x], /<<-?[ \t]*(\\|["\047])[A-Za-z0-9_.-]+/)) {
        t = substr(p[x], RSTART, RLENGTH); sub(/^<<-?[ \t]*(\\|["\047])/, "", t)
        for (k = x + 1; k <= np; k++) { s = p[k]; sub(/^\t+/, "", s); if (s == t) exit }
      }
      # Any << the raw command never terminates (read loosely, so a false one only costs credit) makes a missing terminator ambiguous.
      nr = split(ENVIRON["mk_raw"] != "" ? ENVIRON["mk_raw"] : buf, rl, "\n")
      for (x = 1; x <= nr && !unterm; x = y + 1) {
        s = rl[x]; y = x
        while (!unterm && (k = index(s, "<<"))) {
          s = substr(s, k + 2); if (substr(s, 1, 1) == "<") { s = substr(s, 2); continue }
          t = sub(/^-/, "", s); z = s; sub(/^[ \t]+/, "", z); w = delim(z, 1)
          for (y++; y <= nr; y++) { z = rl[y]; if (t) sub(/^\t+/, "", z); if (z == w) break }
          unterm = w == "" || y > nr
        }
      }
      for (pos = 1; pos <= n && match(substr(buf, pos), /(^|[^A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*="?(\$\(|`)/); ) {
        b = pos + RSTART - 1; if (substr(buf, b, 1) !~ /[A-Za-z_]/) b++
        match(substr(buf, b), /^[A-Za-z_][A-Za-z0-9_]*=/); j = b + RLENGTH; q = substr(buf, j, 1) == "\""
        if (lone(j + q, q)) { ns++; sn[ns] = substr(buf, b, RLENGTH - 1); sb[ns] = b; se[ns] = e; at[b] = ns; pos = e } else pos = j + 1
      }
      if (!ns) exit
      sq = 0; dq = 0; bq = 0; ans = 0; st = ""; bd = 0; cs = 1; sp = ";"; nh = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        if (sq) { if (c == "\\" && ans) i++; else if (c == "\047") sq = 0; continue }
        if (c == "\\") { i++; cs = 0; continue }
        if (dq) { if (c == "\"") dq = 0; else if (c == "$" && nx == "(") { st = st "q"; dq = 0; i++; cs = 1; sp = "(" }; continue }
        if (c == " " || c == "\t") continue
        if (c == "#" && (cs || substr(buf, i - 1, 1) ~ /[ \t]/)) { k = index(substr(buf, i), "\n"); if (!k) break; i += k - 2; continue }
        if (c == "\047") { sq = 1; ans = substr(buf, i - 1, 1) == "$"; cs = 0; continue }
        if (c == "\"") { dq = 1; cs = 0; continue }
        if (c == "`") { bq = !bq; cs = bq; sp = "("; continue }
        # A heredoc body is the reading program'"'"'s text, an unquoted one expanded here first: nothing in it assigns in this shell.
        if (c == "<" && nx == "<") {
          if (substr(buf, i + 2, 1) == "<") { i += 2; cs = 0; continue }
          k = i + 2; t = substr(buf, k, 1) == "-"; k += t
          while (substr(buf, k, 1) ~ /[ \t]/) k++
          if ((x = delim(buf, k)) == "") break
          nh++; hd[nh] = x; ht[nh] = t; i = de - 1; cs = 0; continue
        }
        if (c == "\n" && nh) { if ((k = body(i)) < 0) break; if (k > i) { i = k - 1; continue } }
        if (c == "\n" || c == ";") { cs = 1; sp = ";"; continue }
        if (c == "&" || c == "|") {
          if (c == "&" && (substr(buf, i - 1, 1) == ">" || nx == ">")) { cs = 0; continue }
          if (nx == c) { i++; sp = c c } else sp = c
          cs = 1; continue
        }
        if (c == "$" && nx == "{") { k = 1; for (i += 2; i <= n && k > 0; i++) { x = substr(buf, i, 1); k += (x == "{") - (x == "}") }; i--; cs = 0; continue }
        if (c == "(" || c == "$" && nx == "(") {
          if (substr(buf, i + 1 + (c == "$"), 1) == "(") { k = index(substr(buf, i), "))"); if (!k) break; i += k; cs = 0; continue }
          i += (c == "$"); st = st "p"; cs = 1; sp = "("; continue
        }
        if (c == ")") { x = substr(st, length(st)); st = substr(st, 1, length(st) - (st != "")); if (x == "q") dq = 1; cs = 0; continue }
        # A function body is a { } group that may never run, so { opens a block wherever it stands.
        if (c == "{" && nx ~ /[ \t\n]/) { bd++; cs = 1; continue }
        if (!cs) continue
        w = substr(buf, i)
        if ((k = kw(w, "if|while|until|case|for|select"))) { bd++; i += k - 1; continue }
        if ((k = kw(w, "then|do|else|elif|!|time"))) { i += k - 1; continue }
        if ((k = kw(w, "fi|done|esac|}"))) { bd -= (bd > 0); i += k - 1; cs = 0; continue }
        cs = 0
        if (st != "" || bq || bd || sp != ";") continue
        # local outside a function fails and assigns nothing; export/declare return 0 whatever mktemp did, so || exit never fires.
        pre = match(w, /^(export|declare|typeset|readonly)([ \t]+-[A-Za-z]+)*[ \t]+/) ? RLENGTH : 0
        if (!((x = at[i + pre]) > 0)) continue
        # -n, -i, -a and -A make the value a nameref, a number or an array: a path fails as the first two.
        if (substr(w, 1, pre) ~ /[ \t]-[A-Za-z]*[niaA]/) continue
        t = substr(buf, se[x]); k = sub(/^[ \t]+/, "", t)
        if (t != "" && t !~ /^(\n|;|&&|\|\|)/ && !(k && t ~ /^#/)) continue
        if (t ~ /^(&&|\|\|)/ && bg(se[x])) continue
        ok[x] = 1; g[x] = !pre && exits(t)
        if (!(sn[x] in first)) first[sn[x]] = sb[x]
        i = se[x] - 1
      }
      bl = buf
      # A second assignment whose || exit fires runs an EXIT trap (or a function it calls) with the variable empty.
      for (x = 1; x <= ns; x++) { bl = substr(bl, 1, sb[x] - 1) sprintf("%" (se[x] - sb[x]) "s", "") substr(bl, se[x]); if (!ok[x] || !g[x] || ++na[sn[x]] > 1) ng[sn[x]] = 1 }
      for (v in first) {
        if (v ~ /^(HOME|TMPDIR|PWD|OLDPWD|REPLY|OPTARG|OPTIND|RANDOM|SECONDS|LINENO|MAPFILE|_|BASH.*)$/) continue
        if (bl ~ ("(^|[^A-Za-z0-9_$.-])" v "([[][^]]*[]])?[+]?=") || bl ~ ("[$][{]" v ":?=") || bl ~ ("-v[ \t]*[\"\047]?" v "([^A-Za-z0-9_]|$)")) continue
        bad = 0
        for (s = bl; !bad && match(s, /(^|[^A-Za-z0-9_])(read|mapfile|readarray|unset|getopts|for|select|let|local|declare|typeset|readonly)[ \t][^;&|\n)]*/); s = substr(s, RSTART + RLENGTH))
          bad = substr(s, RSTART, RLENGTH) ~ ("[ \t=\"\047]" v "([^A-Za-z0-9_]|$)")
        for (s = bl; !bad && match(s, /[(][(][^)]*[)][)]/); s = substr(s, RSTART + RLENGTH))
          bad = substr(s, RSTART, RLENGTH) ~ ("(^|[^A-Za-z0-9_])" v "([^A-Za-z0-9_]|$)")
        if (!bad) printf "%s\t%d\t%d\n", v, first[v], !(v in ng)
      }
    }'
}

# The byte offsets become segment ordinals: split_segments on the prefix (plus a sentinel, so a trailing newline still counts) ends inside that segment.
mktemp_ordinals() { # raw command, mktemp_vars output
  local LC_ALL=C v o g
  while IFS=$'\t' read -r v o g; do
    [ -n "$v" ] || continue
    printf '%s\t%s\t%s\n' "$v" "$(split_segments "${1:0:o-1}x" | wc -l | tr -d ' ')" "$g"
  done <<EOF
$2
EOF
}

# 0 when an rm target is this command's own mktemp path, used after its assignment: $v or ${v} alone (empty is a no-op), or a path
# under it with no `..` when a failed mktemp cannot leave it empty ($v/* would be /*): ${v:?}, or the only assignment's || exit.
mktemp_target() { # case-preserved rm target, raw segment
  local t="$1" v q rest n o g
  [ -n "$MKTEMP_VARS" ] || return 1
  case "$t" in *..*) return 1 ;; esac
  # A single-quoted or escaped $ is expanded by whatever runs the text (bash -c, ssh, docker exec) in its own environment; trap runs it here.
  case "${2:-}" in *"'"*|*'\$'*) [[ $2 =~ ^[[:space:]]*trap[[:space:]] ]] || return 1 ;; esac
  if [[ $t =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)(:\?[^}]*)?\}(/.*)?$ ]]; then v=${BASH_REMATCH[1]}; q=${BASH_REMATCH[2]}; rest=${BASH_REMATCH[3]}
  elif [[ $t =~ ^\$([A-Za-z_][A-Za-z0-9_]*)(/.*)?$ ]]; then v=${BASH_REMATCH[1]}; q=""; rest=${BASH_REMATCH[2]}
  else return 1; fi
  case "$rest" in *'$'*|*'`'*) return 1 ;; esac
  while IFS=$'\t' read -r n o g; do
    [ "$n" = "$v" ] || continue
    [ "$SEG_I" -gt "$o" ] || return 1
    [ -z "$rest" ] || [ -n "$q" ] || [ "$g" = 1 ]
    return
  done <<EOF
$MKTEMP_VARS
EOF
  return 1
}

# Fails closed: a moved cwd, a glob, no git or repo, or untracked, modified or IGNORED content (a .env git has no copy of) asks.
git_recoverable() { # path -> 0 recoverable, 1 ask
  local p="$1" st
  [ "$CWD_MOVED" -eq 1 ] && return 1
  case "$p" in *'*'*|*'?'*|*'['*) return 1 ;; esac
  [ -e "$p" ] || return 0
  command -v git >/dev/null 2>&1 || return 1
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  git ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || return 1
  st=$(git status --porcelain --untracked-files=all --ignored=matching -- "$p" 2>/dev/null) || return 1
  [ -z "$st" ]
}

# The Bash call's cwd from the payload; --check has no payload, so this process's.
command_cwd() {
  local d=""
  [ -n "${input:-}" ] && d=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  printf '%s' "${d:-.}"
}

# The word reader rm_backslash_target and git_gh_bypass both prepend; each defines judge(). Quote removal as bash does it ($'…' decodes
# \\ and \' only, any other escape reads as $), a redirection target is no word, and a $( ) or backtick substitution, an eval's words and
# a shell's -c script are queued for a scan of their own. -v lone_brace=1 splits on a brace only standing alone, as bash does; 0 on every brace.
SHELL_WORDS_AWK='
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    function word() { if (inw) { if (redir) redir = 0; else wv[++nw] = w }; w = ""; inw = 0 }
    function base(x) { sub(/^.*\//, "", x); return x }
    function queue(   j, k, x, c) {
      for (j = 1; j <= nw; j++) {
        x = base(wv[j])
        if (x == "eval") { x = ""; for (k = j + 1; k <= nw; k++) x = x " " wv[k]; q[++nq] = x; return }
        if (x !~ /^((ba|z|da|k|c|tc|a|rba|mk|ok|ya)?sh|fish)$/) continue
        c = 0
        for (k = j + 1; k <= nw && wv[k] ~ /^[-+]./ && wv[k] != "--"; k++) {
          if (wv[k] ~ /^[-+][oO]$|^--(rcfile|init-file)$/) k++
          else if (wv[k] ~ /^-[A-Za-z]*c/) c = 1
        }
        if (c && wv[k] == "--") k++
        if (c && k <= nw) { q[++nq] = wv[k]; return }
      }
    }
    # Where the $( or backtick substitution opening at i ends; n + 1 when it never closes.
    function cs_end(s, i,   n, k, c, d, j) {
      n = length(s)
      if (substr(s, i, 1) == "`") { for (k = i + 1; k <= n && (c = substr(s, k, 1)) != "`"; k++) { if (c == "\\") k++ }; return k }
      for (k = i + 1; k <= n; k++) {
        c = substr(s, k, 1)
        if (c == "\\") k++
        else if (c == "\047") { j = index(substr(s, k + 1), "\047"); if (!j) return n + 1; k += j }
        else if (c == "\"") {
          for (k++; k <= n && (c = substr(s, k, 1)) != "\""; k++) { if (c == "\\") k++; else if (c == "`" || c == "$" && substr(s, k + 1, 1) == "(") k = cs_end(s, k) }
          if (k > n) return n + 1
        }
        else if (c == "`") k = cs_end(s, k)
        else if (c == "(") d++
        else if (c == ")" && !--d) return k
      }
      return n + 1
    }
    function cmdsub(s, i,   e) {
      e = cs_end(s, i)
      if (substr(s, i, 1) == "`") q[++nq] = substr(s, i + 1, e - i - 1)
      else if (substr(s, i + 2, 1) != "(") q[++nq] = substr(s, i + 2, e - i - 2)
      w = w substr(s, i, e - i + 1); inw = 1
      return e
    }
    function scan(s, lit,   n, i, c, nx, j) {
      n = length(s); nw = 0; w = ""; inw = 0; redir = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1)
        if (c == "\\") {
          if (i == n) { if (lit) { w = w c; inw = 1 }; continue }
          i++; if (nx != "\n") { w = w nx; inw = 1 }; continue
        }
        if (c == "\047") {
          j = index(substr(s, i + 1), "\047"); if (j == 0) j = n - i + 1
          w = w substr(s, i + 1, j - 1); i += j; inw = 1; continue
        }
        if (c == "\"") {
          for (i++; i <= n && (c = substr(s, i, 1)) != "\""; i++) {
            nx = substr(s, i + 1, 1)
            if (c == "\\" && nx ~ /[$`"\\\n]/) { i++; if (nx != "\n") w = w nx }
            else if (c == "`" || c == "$" && nx == "(") i = cmdsub(s, i)
            else w = w c
          }
          inw = 1; continue
        }
        if (c == "`") { i = cmdsub(s, i); continue }
        if (c == "$" && nx == "\047") {
          for (i += 2; i <= n && (c = substr(s, i, 1)) != "\047"; i++) {
            if (c == "\\") { c = substr(s, ++i, 1); if (c != "\\" && c != "\047") c = "$" }
            w = w c
          }
          inw = 1; continue
        }
        if (c == " " || c == "\t") { word(); continue }
        if (c == "#" && !inw) { while (i < n && substr(s, i + 1, 1) != "\n") i++; continue }
        if (c == "<" || c == ">") {
          if (w ~ /^[0-9]+$/) inw = 0
          word(); while (substr(s, i + 1, 1) ~ /[<>&|]/) i++; redir = 1; continue
        }
        if (c ~ /[;&|()\n]/ || c ~ /[{}]/ && (!lone_brace || !inw && nx ~ /^([ \t\n;&|]|)$/)) { judge(); continue }
        w = w c; inw = 1
      }
      judge()
    }
'

# 0 when a recursive rm's operand is backslashes only, in rm's raw words or a shell -c / eval argument; a lone trailing \ is a word only at the command's end (arg 2 = 1). Misses a variable holding \, ssh's or su -c's command.
rm_backslash_target() { # raw segment, 1 when it ends the command
  printf '%s' "$1" | LC_ALL=C awk -v tail="${2:-0}" -v lone_brace=0 "$SHELL_WORDS_AWK"'
    function judge(   j, k, opts, rec, bs) {
      word()
      for (j = 1; j <= nw && tolower(wv[j]) != "rm"; j++) ;
      rec = 0; bs = 0; opts = 1
      for (k = j + 1; k <= nw; k++) {
        if (opts && wv[k] == "--") opts = 0
        else if (opts && wv[k] ~ /^-./) { if (wv[k] ~ /^-[^-]*[rR]/ || wv[k] == "--recursive") rec = 1 }
        else if (wv[k] ~ /^\\+$/) bs = 1
      }
      if (rec && bs) found = 1
      queue()
      nw = 0; redir = 0
    }
    END { nq = 1; q[1] = buf; for (qi = 1; qi <= nq && qi <= 16 && !found; qi++) scan(q[qi], qi > 1 || tail); exit !found }'
}

# Not a table rule: whether rm -rf is catastrophic depends on each target, not on the flags.
check_rm() { # normalised segment (lowercased, padded), the same case-preserved, the raw segment, the command it came from
  local seg="$1" flags="" targets="" tok sp recursive=0 t
  case "$seg" in *" rm "*) ;; *) return 0 ;; esac

  # Each target lowercased, then as typed for the filesystem tests: on a case-sensitive disk docs is not Docs.
  targets=$(printf '%s\n%s\n' "$seg" "${2:-$seg}" | awk 'NR == 1 { n = split($0, l, " "); next }
    { if (split($0, c, " ") != n) for (i = 1; i <= n; i++) c[i] = l[i]
      seen = 0; for (i = 1; i <= n; i++) { if (!seen) { if (l[i] == "rm") seen = 1; continue }; print l[i] "\t" c[i] } }')
  flags=$(printf '%s\n' "$targets" | awk -F'\t' '/^-/ { printf "%s", $1 }')
  case "$flags" in *r*|*R*) recursive=1 ;; esac
  [ "$recursive" -eq 1 ] || return 0

  # The splitter cuts on {, so xargs -I{} rm -rf {} leaves an rm with no operand right before one.
  if [ -n "${3:-}" ] && ! printf '%s\n' "$targets" | grep -q '^[^-]'; then
    case "${4:-}" in *"$3{"*)
      set_verdict ask "recursively deletes each path substituted for {}, none of which the command shows" \
        "run it without the rm, read the list, then delete named paths" "$seg"
      return 0 ;;
    esac
  fi

  # norm_cmd drops backslashes, so a target that is only backslashes is judged on the raw words.
  t=0; [ -n "${3:-}" ] && [ "${4%"$3"}" != "${4:-}" ] && t=1
  if [ -n "${3:-}" ] && rm_backslash_target "$3" "$t"; then
    set_verdict deny "recursively deletes \\, a path of backslashes only, which Git Bash on Windows can take for the root of the current drive" \
      "name the specific directory to delete" "$seg"
    return 0
  fi

  while IFS=$'\t' read -r tok sp; do
    [ -n "$tok" ] || continue
    case "$tok" in -*) continue ;; esac
    case "$tok" in
      /|/\*|\~|\~/|\~/\*|.|./|./\*|..|../\*|\*|\$home|\$home/|\$home/\*)
        set_verdict deny \
          "recursively deletes ${tok} — the whole filesystem, home directory, or the entire working tree" \
          "name the specific directory to delete" "$seg"
        return 0 ;;
      .git|.git/|.git/\*|./.git|./.git/|./.git/\*)
        set_verdict deny "recursively deletes ${tok}, the repository itself: its history, unpushed branches, stashes and reflog, which nothing restores" \
          "delete the files you mean inside the working tree; if the repository must go, ask the user to run it" "$seg"
        return 0 ;;
    esac
    # A system directory is one component (/etc); a regex, since the case glob /[a-z]* also matches /opt/app/releases/12.
    if printf '%s' "$tok" | grep -qE '^/[a-z0-9_.-]+/?\*?$'; then
      set_verdict deny "recursively deletes the system directory ${tok}" \
        "work inside the project directory" "$seg"
      return 0
    fi
    # The temp roots' longer spellings must agree with the /tmp deny, or the scratch exemption spells the root.
    case "$tok" in
      /private/tmp|/private/tmp/|/private/tmp/\*|/var/tmp|/var/tmp/|/var/tmp/\*|/private/var/tmp|/private/var/tmp/|/private/var/tmp/\*)
        set_verdict deny "recursively deletes ${tok}, the machine's shared temp directory, which holds other processes' state" \
          "delete the specific scratch directory this task created" "$seg"
        return 0 ;;
    esac
    is_temp_path "$tok" && continue   # inside the OS temp dir: scratch, not a loss
    case "$tok" in
      *'$'*)
        mktemp_target "${sp:-$tok}" "${3:-}" && continue
        set_verdict ask "recursively deletes ${tok}; if that variable is unset the path collapses (rm -rf \$X/ becomes rm -rf /)" \
          "expand the variable first and check it is non-empty, or use \${X:?} so the shell refuses when unset" "$seg"
        continue ;;
    esac
    # Only the Playwright MCP's scratch dir, under the command's cwd, unmoved, and not a symlink: rm -rf link/ empties the link's target.
    case "$tok" in
      .playwright-mcp|.playwright-mcp/|./.playwright-mcp|./.playwright-mcp/)
        [ "$CWD_MOVED" -eq 0 ] && [ ! -L "$(command_cwd)/${sp%/}" ] && continue ;;
    esac
    t="$tok"
    printf '%s' "$t" | grep -qE "$ARTIFACT_RE" && continue
    # A path git can restore is no loss; .. and absolute paths are not asked of git, as they can leave its repo.
    case "$tok" in
      /*|*..*) ;;
      *) git_recoverable "${sp:-$tok}" && continue ;;
    esac
    case "$tok" in
      /*) set_verdict ask "recursively deletes ${tok}, which is outside the project" \
            "use a path relative to the project root" "$seg" ;;
      *)  set_verdict ask "recursively deletes ${tok}" \
            "confirm the path is what you mean, and that nothing untracked lives under it" "$seg" ;;
    esac
  done <<EOF
$targets
EOF
  return 0
}

# Per path, like check_rm: checkout <tree> -- or -- paths, restore paths (not --staged alone), rm -f paths ask only when they hold uncommitted changes.
# Fails closed (asks) after a cd, a git -C/--git-dir/--work-tree, or a $ path; a checkout without -- is read as a branch switch.
check_git_discard() { # case-preserved padded segment, the same before the git global-option strip
  local w o sub="" seen=0 dd=0 val=0 st=0 wt=0 force=0 base="" d unknown=0 words pre=() paths=() re=' git( [^ ]+)* (-C|--git-dir|--work-tree)[ =]'
  read -ra words <<< "$1"
  for w in "${words[@]}"; do
    if [ "$seen" -eq 0 ]; then [ "$w" = git ] && seen=1; continue; fi
    if [ -z "$sub" ]; then sub=$w; case "$sub" in checkout|restore|rm) continue ;; *) return 0 ;; esac; fi
    if [ "$val" -eq 1 ]; then val=0; continue; fi
    if [ "$dd" -eq 1 ]; then paths+=("$w"); continue; fi
    case "$sub:$w" in
      *:--) dd=1 ;;
      *:--patch|*:--dry-run|checkout:--orphan|rm:--cached) return 0 ;;
      restore:--staged) st=1 ;;
      restore:--worktree) wt=1 ;;
      restore:--source) val=1 ;;
      rm:--force) force=1 ;;
      *:--*) ;;
      *:-?*)
        o=${w#-}
        case "$sub" in
          checkout) case "$o" in *[bBp]*) return 0 ;; esac ;;
          restore)  case "${o%%s*}" in *p*) return 0 ;; esac
                    case "${o%%s*}" in *S*) st=1 ;; esac
                    case "${o%%s*}" in *W*) wt=1 ;; esac
                    case "$o" in *s) val=1 ;; esac ;;
          rm)       case "$o" in *n*) return 0 ;; esac
                    case "$o" in *f*) force=1 ;; esac ;;
        esac ;;
      *) pre+=("$w") ;;
    esac
  done
  case "$sub" in
    checkout) [ "$dd" -eq 1 ] || return 0; [ "${#pre[@]}" -gt 0 ] && base=HEAD ;;
    restore)  [ "$st" -eq 1 ] && { [ "$wt" -eq 1 ] || return 0; base=HEAD; }; paths=("${pre[@]}" "${paths[@]}") ;;
    rm)       [ "$force" -eq 1 ] || return 0; base=HEAD; paths=("${pre[@]}" "${paths[@]}") ;;
  esac
  [ "${#paths[@]}" -gt 0 ] || return 0
  for w in "${paths[@]}"; do case "$w" in *'$'*) unknown=1 ;; esac; done
  [[ " $2 " =~ $re ]] && unknown=1
  [ "$CWD_MOVED" -eq 1 ] && unknown=1
  if [ "$unknown" -eq 0 ]; then
    command -v git >/dev/null 2>&1 || return 0
    d=$(command_cwd)
    git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$d" diff --quiet ${base:+"$base"} -- "${paths[@]}" >/dev/null 2>&1 && return 0
  fi
  set_verdict ask "discards the uncommitted changes in ${paths[*]}, which git has no copy of" \
    "\`git stash\` keeps them recoverable; \`git diff -- <path>\` shows what would go" "$1"
}

# ERE cannot say "no WHERE", so this is no table row. A WHERE on a later line of the same statement (a heredoc) counts.
check_sql_update() { # padded lowercased segment, the whole body normalised, lowercased and padded
  local stmt frag re=' update [^;]* set .*'
  while IFS= read -r stmt; do
    [[ " $stmt " =~ $re ]] || continue
    frag=${BASH_REMATCH[0]}
    case "$frag" in *' where '*) continue ;; esac
    frag=${frag%"${frag##*[! ]}"}
    printf '%s\n' "$2" | tr ';' '\n' | grep -F -e "$frag" | grep -q ' where ' && continue
    set_verdict ask "runs an UPDATE with no WHERE clause, which rewrites every row in the table" \
      "add the WHERE clause, run \`SELECT count(*)\` with it first, and run it inside a transaction" "$1"
    return 0
  done < <(printf '%s\n' "$1" | tr ';' '\n')
}

# Prints "<code><TAB><words>" for the first git call that skips hooks or signing (verify, hookspath, gpg, hookenv) or gh call that
# publishes review text (review, comment, api, graphql). Words come from SHELL_WORDS_AWK, so a message naming --no-verify is one word.
# A brace splits only standing alone: split_segments cuts gh's {owner}.
git_gh_bypass() { # raw command, heredoc bodies stripped
  printf '%s' "$1" | LC_ALL=C awk -v lone_brace=1 "$SHELL_WORDS_AWK"'
    function hit(c,   k) { if (found != "") return; found = c "\t"; for (k = 1; k <= nw; k++) found = found " " wv[k] }
    function inset(s, x) { return index(" " s " ", " " x " ") > 0 }
    # -n is --no-verify for commit and am only (push: --dry-run; merge, rebase, pull: --no-stat; cherry-pick, revert: --no-commit).
    function git(j, envs,   k, x, n, i, ch, sc, nc, cfg, nv, ng, sv, lv, pos, p, wr, rd, key, val) {
      nc = 0
      for (k = j + 1; k <= nw; k++) {
        x = wv[k]
        if (x == "-c" || x == "--config-env") { cfg[++nc] = tolower(wv[++k]); continue }
        if (x ~ /^--config-env=/) { cfg[++nc] = tolower(substr(x, 14)); continue }
        if (x ~ /^(-C|--git-dir|--work-tree|--namespace|--attr-source|--super-prefix|--shallow-file)$/) { k++; continue }
        if (x ~ /^-/) continue
        break
      }
      sc = wv[k]
      H = "commit push merge rebase am cherry-pick pull revert"
      if (sc == "config") {
        pos = 0; wr = 0; rd = 0
        for (k++; k <= nw; k++) {
          x = wv[k]
          if (x ~ /^--(unset|unset-all|replace-all|add)$/) { wr = 1; continue }
          if (x ~ /^(--get|--get-all|--get-regexp|--get-urlmatch|-l|--list|-e|--edit)$/) { rd = 1; continue }
          if (x ~ /^(-f|--file|--blob|--type|--default|--comment|--value)$/) { k++; continue }
          if (x ~ /^-/) continue
          p[++pos] = x
        }
        if (p[1] == "set" || p[1] == "unset") { wr = 1; key = p[2]; val = (p[1] == "set") ? p[3] : "" }
        else if (p[1] == "get" || p[1] == "list") rd = 1
        else { key = p[1]; val = p[2]; if (pos >= 2) wr = 1 }
        key = tolower(key)
        if (wr && !rd && key == "core.hookspath") hit("hookspath")
        if (wr && !rd && key == "commit.gpgsign" && tolower(val) ~ /^(false|no|off|0)?$/) hit("gpg")
        return
      }
      if (!inset(H, sc)) return
      for (i = 1; i <= nc; i++) {
        if (cfg[i] ~ /^core\.hookspath(=|$)/) hit("hookspath")
        if (cfg[i] ~ /^commit\.gpgsign=(false|no|off|0)?$/ && sc != "push") hit("gpg")
      }
      if (("\n" envs "\n") ~ /\n(HUSKY=0|SKIP=[^\n]+|LEFTHOOK=(0|false))\n/) hit("hookenv")
      sv = sc == "commit" ? "mFcCt" : sc == "merge" ? "mFsX" : sc == "push" ? "o" : sc == "rebase" ? "sXx" : sc == "pull" ? "sX" : sc == "am" ? "" : "mX"
      lv = " --message --file --author --date --template --reuse-message --reedit-message --fixup --squash --trailer --cleanup --pathspec-from-file --strategy --strategy-option --into-name --repo --receive-pack --exec --push-option --onto --whitespace --patch-format --resolvemsg --directory --exclude --include --mainline --upload-pack --depth --deepen --shallow-since --shallow-exclude --negotiation-tip --server-option "
      nv = 0; ng = 0
      for (k++; k <= nw; k++) {
        x = wv[k]
        if (x == "--") break
        if (x ~ /^--./) {
          n = x; sub(/=.*/, "", n)
          if (length(n) >= 9 && index("--no-verify", n) == 1) nv = 1
          else if (n == "--verify") nv = 0
          else if (length(n) >= 6 && index("--no-gpg-sign", n) == 1) ng = 1
          else if (n == "--gpg-sign") ng = 0
          else if (x !~ /=/ && index(lv, " " n " ")) k++
          continue
        }
        if (x !~ /^-./) continue
        for (i = 2; i <= length(x); i++) {
          ch = substr(x, i, 1)
          if (ch == "n" && (sc == "commit" || sc == "am")) { nv = 1; continue }
          if (ch == "S") { ng = 0; break }
          if (index(sv, ch)) { if (i == length(x)) k++; break }
          if (sc == "commit" && ch == "u" || (sc == "rebase" || sc == "am") && ch ~ /[Cp]/) break
        }
      }
      if (nv) hit("verify")
      if (ng && sc != "push") hit("gpg")
    }
    # gh api sends GET unless -X names a method or a -f/-F field or --input body is given, which make it POST. -R/--repo may sit anywhere.
    function gh(j,   k, x, a, b, ka, kb, p, m, f, ep, vals) {
      a = ""; b = ""; ka = nw; kb = nw; p = 0
      for (k = j + 1; k <= nw && p < 2; k++) {
        x = wv[k]
        if (x == "-R" || x == "--repo") k++
        else if (x !~ /^(-R.|--repo=)/) { if (++p == 1) { a = x; ka = k } else { b = x; kb = k } }
      }
      if (a == "pr" && b == "review") {
        for (k = kb + 1; k <= nw; k++) if (wv[k] ~ /^(--(comment|approve|request-changes|body|body-file)(=|$)|-[acrbF])/) { hit("review"); return }
        return
      }
      if ((a == "pr" || a == "issue") && b == "comment") {
        for (k = kb + 1; k <= nw; k++) if (wv[k] ~ /^(--web|-w|--help|-h)$/) return
        hit("comment"); return
      }
      if (a != "api") return
      m = ""; f = 0; ep = ""; vals = ""
      for (k = ka + 1; k <= nw; k++) {
        x = wv[k]
        if (x == "-X" || x == "--method") m = wv[++k]
        else if (x ~ /^--method=/) m = substr(x, 10)
        else if (x ~ /^-X./) m = substr(x, 3)
        else if (x ~ /^(-f|-F|--field|--raw-field|--input)$/) { f = 1; vals = vals " " wv[++k] }
        else if (x ~ /^(-[fF].|--(field|raw-field|input)=)/) { f = 1; vals = vals " " x }
        else if (x ~ /^(-H|--header|-q|--jq|-t|--template|--cache|-p|--preview|--hostname)$/) k++
        else if (x == "--") { if (ep == "") ep = wv[k + 1]; break }
        else if (x !~ /^-/ && ep == "") ep = x
      }
      m = tolower(m); if (m == "") m = f ? "post" : "get"
      ep = tolower(ep)
      sub(/^https?:\/\/[^\/]+\//, "", ep); sub(/^api\/v3\//, "", ep); sub(/^\//, "", ep); sub(/[?#].*$/, "", ep); sub(/\/$/, "", ep)
      if (ep == "graphql" || ep == "api/graphql") {
        if (tolower(vals) ~ /(^|[^a-z0-9_])(addpullrequestreview[a-z]*|addcomment|submitpullrequestreview|updateissuecomment|updatepullrequestreview(comment)?)([^a-z0-9_]|$)/) hit("graphql")
        return
      }
      if (m !~ /^(post|patch|put)$/) return
      if (ep ~ /(^|\/)(pulls|issues)\/[^\/]+\/(comments|reviews)(\/[^\/]+(\/(replies|events|dismissals))?)?$/ || ep ~ /(^|\/)(pulls|issues)\/comments\/[^\/]+(\/replies)?$/) hit("api")
    }
    # A keyword heads a command only before anything else; timeout and flock take one operand (a duration, a lock file) before theirs.
    function judge(   j, x, b, wrap, envs, head, pos) {
      word()
      envs = ""; wrap = 0; head = 1; pos = 0
      for (j = 1; j <= nw; j++) {
        x = wv[j]; b = base(x)
        if (head && x ~ /^(if|then|elif|else|do|while|until|!)$/) continue
        head = 0
        if (x ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { envs = envs "\n" x; continue }
        if (b ~ /^(sudo|doas|nohup|time|command|builtin|exec|nice|ionice|env|timeout|xargs|stdbuf|flock)$/) { wrap = 1; pos = b ~ /^(timeout|flock)$/; continue }
        if (wrap && x ~ /^-/) continue
        if (b == "git" || b == "gh") break
        if (wrap && wv[j - 1] ~ /^-/) continue
        if (wrap && pos) { pos = 0; continue }
        break
      }
      b = j <= nw ? base(wv[j]) : ""
      if (b == "git") git(j, envs); else if (b == "gh") gh(j); else queue()
      nw = 0; redir = 0
    }
    END { nq = 1; q[1] = buf; for (qi = 1; qi <= nq && qi <= 16 && found == ""; qi++) scan(q[qi], 0); if (found != "") print found }'
}

# A case pattern first, so a command naming none of the shapes costs no fork.
check_git_gh() { # raw command (heredoc bodies stripped), the normalised command (lowercased, padded)
  local code="" m
  case "$2" in
    *no-ver*|*no-g*|*hookspath*|*gpgsign*|*husky=*|*skip=*|*lefthook=*) ;;
    *' pr '*'review '*|*' pr '*'comment '*|*' issue '*'comment '*|*' api '*) ;;
    *' commit '*|*' am '*) [[ $2 =~ \ \$?-[a-z]*n ]] || return 0 ;;
    *) return 0 ;;
  esac
  code=$(git_gh_bypass "$1")
  m=${code#*$'\t'}; code=${code%%$'\t'*}
  set -- "$1" "$2" "$m "
  case "$code" in
    verify)    set_verdict ask "skips the repository's git hooks (--no-verify, or -n on commit or am), so the checks they run do not run" \
                 "run it without the bypass and fix what the hook reports; if a hook itself is broken, tell the user" "$3" ;;
    hookspath) set_verdict ask "points git at another hooks directory (core.hooksPath), so the repository's own hooks do not run" \
                 "leave core.hooksPath alone; if a hook itself is broken, tell the user" "$3" ;;
    gpg)       set_verdict ask "turns commit signing off (--no-gpg-sign or commit.gpgsign=false), so the commit is not signed as the repository expects" \
                 "leave signing on; if signing fails, tell the user why" "$3" ;;
    hookenv)   set_verdict ask "turns the hook manager off (HUSKY=0, SKIP= or LEFTHOOK=0), so the hooks it runs are skipped" \
                 "run it without the variable and fix what the hook reports; if a hook itself is broken, tell the user" "$3" ;;
    review)    set_verdict ask "publishes a pull-request review (gh pr review) under the user's name, where everyone on the repository reads it" \
                 "show the user the review text and let them post it" "$3" ;;
    comment)   set_verdict ask "posts a comment (gh pr comment or gh issue comment) under the user's name, where everyone on the repository reads it" \
                 "show the user the comment text and let them post it" "$3" ;;
    api|graphql) set_verdict ask "posts or edits pull-request review or comment text through the GitHub API, under the user's name" \
                 "show the user the text and let them post it; a GET of the same path only reads" "$3" ;;
  esac
}

# The human's opt-out, so the model may not write it: check_self_protection on Bash, guard_file_write on the write tools.
ALLOW_BASENAME=destructive-guard-allow

# Closed on purpose and not READERS: less, sort, jq, env and echo can each write or run a program.
ALLOW_FILE_READERS=' cat head tail wc grep egrep fgrep stat ls file diff cmp '

# Judges every segment, not only the one naming the file: hash -p /bin/cp cat makes a later cat a cp. Keeps 2>&1 and &> whole.
allow_file_pure_read() { # raw command -> 0 when every segment is a pure read
  local s r d x n bad w seen=0
  case "$1" in *'`'*|*'$'*|*'~'*|*'{'*|*'}'*) return 1 ;; esac
  while IFS= read -r s; do
    # stripped BEFORE dequoting, on a literal space: `>&"1 x/f"` and `>&1<CR>x/f` are `&>` onto a file
    r=$(printf ' %s ' "$s" | LC_ALL=C sed -E -e 's# #  #g' \
      -e 's#( [0-9]+)?(>>?|&>>?|>&) */dev/null # #g' \
      -e 's#( [0-9]+)?>& *([0-9]+|-) # #g')
    case "$r" in ''|*'<'*|*'>'*) return 1 ;; esac
    read -ra w <<< "$r"
    [ "${#w[@]}" -gt 0 ] || continue
    seen=1
    # lead and subcommand are judged as typed: `cat\ x` runs a program named "cat x"
    case "$ALLOW_FILE_READERS" in *" ${w[0]} "*) continue ;; esac
    [ "${w[0]}" = git ] || return 1
    case " ${w[1]:-} " in ' log '|' show '|' diff '|' blame '|' grep '|' ls-files '|' cat-file ') ;; *) return 1 ;; esac
    d=${r//\"/}; d=${d//\'/}; d=${d//\\/}
    read -ra w <<< "$d"
    for x in "${w[@]}"; do
      case "$x" in
        --) ;;
        --*) n=${x#--}; n=${n%%=*}
             # both directions: git grep takes an abbreviation (`--open-f=<cmd>`)
             for bad in output open-files-in-pager ext-diff textconv config-env paginate filters; do
               case "$bad" in "$n"*) return 1 ;; esac
               case "$n" in "$bad"*) return 1 ;; esac
             done ;;
        -*[oOc]*) return 1 ;;
      esac
    done
  done < <(printf '%s' "$1" | awk '
    # one walk over the whole input: BWK awk reads RS = "\0" as paragraph mode, splitting at blank lines
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    END {
      n = length(buf); sq = 0; dq = 0; pr = ""; seg = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        if (c == "\\" && !sq) { seg = seg c nx; i++; pr = ""; continue }
        if (c == "'"'"'" && !dq) { sq = !sq; seg = seg c; pr = ""; continue }
        if (c == "\"" && !sq) { dq = !dq; seg = seg c; pr = ""; continue }
        if (sq || dq) { seg = seg c; continue }
        # "#" and a paren each lead their own segment, so it is denied: comment quotes, zsh `f(e:cmd:)`
        if (c == "#" || c == "(" || c == ")") { gsub(/[\t\n]/, " ", seg); print seg; seg = c; pr = c; continue }
        if (c == "&" && (pr == ">" || pr == "<" || nx == ">")) { seg = seg c; pr = c; continue }
        if (c == ";" || c == "\n" || c == "|" || c == "&") {
          gsub(/[\t\n]/, " ", seg); print seg; seg = ""; pr = c; continue
        }
        seg = seg c; pr = c
      }
      gsub(/[\t\n]/, " ", seg); print seg
    }')
  # defensive: no input reaches this with seen=0 (the basename must sit in a non-empty segment); seen=0 means the split itself failed, and unsure is not pure
  [ "$seen" -eq 1 ]
}

# Once per command, before the git global-option strip, which would hide `git -C <file>`.
check_self_protection() { # normalised command (lowercased, padded), raw command
  case "$1" in *"$ALLOW_BASENAME"*) ;; *) return 0 ;; esac
  allow_file_pure_read "$2" && return 0
  set_verdict deny \
    "writes to the guard's own allow-file, which would let the next command through unchecked" \
    "ask the user to add the exemption themselves; the file is theirs by design" "$1"
}

# Shapes the segment splitter would cut in half, because the separator is the hazard.
check_whole() { # normalised full command (lowercased, padded)
  case "$1" in
    *':(){ :|:& };:'*|*':() { :|:& };:'*)
      set_verdict deny "is a fork bomb" "nothing about this belongs in an agent session" "$1"
      return 0 ;;
  esac
  printf '%s' "$1" | grep -qE '(curl|wget) .*\| *(sudo )?[a-z]*sh( |$)' \
    && set_verdict ask "pipes a downloaded script straight into a shell, so nobody reads what runs" \
      "download it to a file, read it, then run it" "$1"
  return 0
}

is_env_secret() { # path token -> 0 when its basename is a local secrets file
  local b="${1##*/}"
  case "$b" in
    .env) return 0 ;;
    .env.example|.env.sample|.env.dist|.env.template|.env.tpl|.env.defaults|.env.*.example|.env.*.sample) return 1 ;;
    .env.*) return 0 ;;
  esac
  return 1
}

# By state, not spelling: cp .env.example .env in a clone with no .env is the setup step, not a loss.
env_target_at_risk() { # case-preserved path token -> 0 at risk, 1 safe
  local t="$1" lc dir base st
  lc=$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')
  case "$t" in /*) is_temp_path "$lc" && return 1 ;; esac
  case "$t" in *'$'*|*'*'*|*'?'*|*'`'*) return 0 ;; esac   # expansion unknown
  case "$t" in /*) ;; *) [ "$CWD_MOVED" -eq 1 ] && return 0 ;; esac
  [ -e "$t" ] || return 1
  command -v git >/dev/null 2>&1 || return 0
  dir=$(dirname "$t"); base=$(basename "$t")
  git -C "$dir" ls-files --error-unmatch -- "$base" >/dev/null 2>&1 || return 0
  st=$(git -C "$dir" status --porcelain -- "$base" 2>/dev/null) || return 0
  [ -n "$st" ]
}

deny_env_overwrite() { # target seg
  local t="$1"
  case "$t" in
    /*) ;;
    *) if [ "$CWD_MOVED" -eq 1 ]; then
         set_verdict deny \
           "writes ${t} by a relative path after a cd; if the cd fails, it overwrites the live project's ${t}, which git has no copy of" \
           "write it by absolute path into a directory you checked exists (test -d DIR) in a separate call" "$2"
         return 0
       fi ;;
  esac
  set_verdict deny \
    "overwrites ${t}, which holds local credentials git has no copy of — every value in it is lost" \
    "leave ${t} alone; if a scratch copy needs one, write it by ABSOLUTE path inside that scratch directory" "$2"
}

check_env_overwrite() { # case-preserved normalised segment (padded), lead word
  local seg="$1" lead="$2" toks tok dest last src f ef
  # Flags are dropped, so a flag's value (-t DIR, -S suffix) reads as an operand: the -t directory form is not resolved.
  toks=$(printf '%s' "$seg" | awk -v L="$lead" '{ s=0; for (i=1;i<=NF;i++) { w=$i; if (!s) { b=w; sub(/^.*\//,"",b); if (b==L) s=1; continue } if (w ~ /^-/) continue; print w } }')

  case "$lead" in
    cp|mv|install|ln|rsync)
      last=$(printf '%s\n' "$toks" | awk 'NF { l=$0 } END { print l }')
      [ -n "$last" ] || return 0
      # `cp /backup/.env ./` and `cp x/.env dir/` land on dir/<source basename>
      if [ "$last" = "." ] || [ "${last%/}" != "$last" ] || { case "$last" in /*) [ -d "$last" ] ;; *) [ "$CWD_MOVED" -eq 0 ] && [ -d "$last" ] ;; esac; }; then
        while IFS= read -r src; do
          [ -n "$src" ] && [ "$src" != "$last" ] || continue
          is_env_secret "$src" || continue
          f="${last%/}/${src##*/}"; [ "$last" = "." ] && f="${src##*/}"
          env_target_at_risk "$f" && { deny_env_overwrite "$f" "$seg"; return 0; }
        done <<EOF
$toks
EOF
        return 0
      fi
      is_env_secret "$last" && env_target_at_risk "$last" && deny_env_overwrite "$last" "$seg"
      ;;
    tee)
      while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        is_env_secret "$tok" && env_target_at_risk "$tok" && { deny_env_overwrite "$tok" "$seg"; return 0; }
      done <<EOF
$toks
EOF
      ;;
  esac

  # A truncating > onto .env.*; norm_cmd spaces every >, so an append arrives as > > and is skipped.
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    is_env_secret "$tok" && env_target_at_risk "$tok" && { deny_env_overwrite "$tok" "$seg"; return 0; }
  done <<EOF
$(printf '%s' "$seg" | awk '{ for (i = 2; i < NF; i++) if ($i == ">" && $(i-1) != ">" && $(i+1) != ">") print $(i+1) }')
EOF

  # artisan key:generate rewrites APP_KEY in the env file. --show only prints.
  case "$seg" in *artisan*key:generate*) ;; *) return 0 ;; esac
  case "$seg" in *' --show'*) return 0 ;; esac
  ef=.env
  f=$(printf '%s' "$seg" | sed -nE 's/.* --env[= ]([^ ]+).*/\1/p')
  [ -n "$f" ] && ef=".env.$f"
  if [ "$CWD_MOVED" -eq 0 ]; then
    [ -f "$ef" ] || return 0                                     # no file: key:generate fails anyway
    grep -qE '^[[:space:]]*APP_KEY=["'\'']?[^"'\''[:space:]]' "$ef" 2>/dev/null || return 0  # empty key: fresh setup
  fi
  set_verdict deny \
    "replaces APP_KEY in ${ef}, so everything encrypted with the old key (sessions, stored tokens, encrypted columns) becomes unreadable" \
    "\`php artisan key:generate --show\` prints a key without writing it; for a test run, export APP_KEY for that process" "$seg"
}

# Denies only a cd certain to fail: a missing absolute or ~ target no earlier step names, its chain ended by ; before more steps, no set -e.
check_cd_chain() { # raw command
  local raw="$1"
  case "$raw" in *cd*) ;; *) return 0 ;; esac
  # One line per segment, <separator after>\t<text>: split_segments' walk, keeping the separator.
  local lines
  lines=$(printf '%s' "$raw" | awk '
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    END {
      n = length(buf); sq = 0; dq = 0; ans = 0; raw = 0; dl = 0; seg = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        d = dl; dl = (c == "$" && !sq && !dq ? d + 1 : 0)
        if (c == "\\" && !raw && (!sq || ans)) { seg = seg c nx; i++; continue }
        if (c == "'"'"'" && !dq && !raw) {
          if (!sq && d > 1) raw = 1; else { if (!sq) ans = (d == 1); sq = !sq }
          seg = seg c; continue
        }
        if (c == "\"" && !sq && !raw) { dq = !dq; seg = seg c; continue }
        if (!sq && !dq) {
          sep = ""
          if (c == ";" || c == "\n") sep = ";"
          else if (c == "&" && nx == "&") { sep = "&&"; i++ }
          else if (c == "|" && nx == "|") { sep = "||"; i++ }
          else if (c == "|" || c == "&") sep = c
          else if (c == "(" || c == ")" || c == "{" || c == "}") sep = "grp"
          if (sep != "") { gsub(/\t/, " ", seg); print sep "\t" seg; seg = ""; continue }
        }
        seg = seg c
      }
      gsub(/\t/, " ", seg); print "end\t" seg
    }' 2>/dev/null) || return 0

  local sep seg words lead target resolved earlier="" rest_nonempty i=0 total chain_end end_at end_sep
  total=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
  while IFS=$'\t' read -r sep seg; do
    i=$((i + 1))
    words=$(printf '%s' "$seg" | sed -e "s/[\"']//g" -e 's/^ *//')
    case " $words " in *' set -e'*|*' set -o errexit'*|*' set -'[a-z]*e[a-z]*' '*) return 0 ;; esac
    lead=${words%% *}
    # A failed cd skips its && / | chain, so the separator that ends the chain decides: only ; hands the rest to the live directory.
    chain_end=$(printf '%s\n' "$lines" | tail -n +"$i" | awk -F'\t' '$1 != "&&" && $1 != "|" { print NR - 1 + '"$i"' "\t" $1; exit }')
    end_at=${chain_end%%$'\t'*}; end_sep=${chain_end#*$'\t'}
    if [ "$lead" = "cd" ] && [ "$end_sep" = ";" ] && [ "${end_at:-$total}" -lt "$total" ]; then
      target=$(printf '%s' "$words" | awk '{ print $2 }')
      rest_nonempty=$(printf '%s\n' "$lines" | tail -n +"$((end_at + 1))" | cut -f2- | tr -d ' ;\n')
      case "$target" in
        /*) resolved="$target" ;;
        '~') resolved="$HOME" ;;
        '~/'*) resolved="$HOME/${target#\~/}" ;;
        *) resolved="" ;;
      esac
      case "$resolved" in *'$'*|*'*'*|*'?'*|*'`'*) resolved="" ;; esac
      if [ -n "$resolved" ] && [ -n "$rest_nonempty" ] && [ ! -d "$resolved" ]; then
        case "$earlier" in
          *"$target"*|*"${resolved%/}"*) ;;   # an earlier step names it: may create it
          *) set_verdict deny "$target" \
               "run \`test -d $target\` in a separate call first, then chain the steps with && (or start with set -e)" \
               "$seg" cd
             return 0 ;;
        esac
      fi
    fi
    earlier="$earlier $seg"
  done <<EOF
$lines
EOF
  return 0
}

# classify: raw command string -> VERDICT / V_WHAT / V_ALT / V_MATCH
classify() {
  local raw="$1" body body_lc="" full full_lc seg segn segn_pre segn_lc lead sub pipe_to_shell=0 sql_ctx=0 redirects=0

  full=$(norm_cmd "$raw")
  full_lc=$(printf '%s' "$full" | tr '[:upper:]' '[:lower:]')
  check_whole " $full_lc "
  check_self_protection " $full_lc " "$raw"

  # A subshell's (cd x && …) and env -C/--chdir move the cwd as a bare cd does.
  CWD_MOVED=0
  [[ " $full_lc " =~ $CD_RE ]] && CWD_MOVED=1

  # SQL rules need a SQL client in the command, or git commit -m "remove the drop table step" reads as executed SQL.
  printf '%s' " $full_lc " | grep -qE "$SQL_CLIENT_RE" && sql_ctx=1
  # The hook sets this for an MCP SQL tool, whose payload names no client; it can only turn SQL rules on.
  [ "${GUARD_SQL_CTX:-0}" = "1" ] && sql_ctx=1

  # Output piped into a shell turns the reader exemption off: echo "rm -rf /" | sh is not an echo.
  printf '%s' " $full_lc " | grep -qE ' \| *(sudo )?[a-z]*sh( |$)| \| *xargs ' && pipe_to_shell=1

  # The whole-command reads above see heredoc bodies; the segment walk and cd chain below see them stripped (inert, SQL clients as readers): judged line by line, a large body overruns the hook timeout.
  body=$raw
  case "$raw" in *'<<'*) body=$(cc_strip_heredoc_bodies inert "$raw" "$SQL_CLIENT_RE"); [ -n "$body" ] || body=$raw ;; esac
  [ "$sql_ctx" -eq 1 ] && body_lc=" $(norm_cmd "$body" | tr '[:upper:]' '[:lower:]') "

  MKTEMP_VARS=""; SEG_I=0
  case "$body" in *mktemp*) MKTEMP_VARS=$(mktemp_ordinals "$body" "$(mktemp_vars "$body" "$raw")") ;; esac

  while IFS= read -r seg; do
    SEG_I=$((SEG_I + 1))
    [ -n "$seg" ] || continue
    segn=$(norm_cmd "$seg")
    [ -n "$segn" ] || continue
    segn_pre=$segn
    segn=$(strip_git_global_options "$segn" "")
    lead=$(lead_word "$segn")
    [ "$lead" = git ] && segn=$(strip_git_global_options "$segn" git)
    segn_lc=" $(printf '%s' "$segn" | tr '[:upper:]' '[:lower:]') "
    segn=" $segn "

    check_env_overwrite "$segn" "$lead"
    [ "$VERDICT" = "deny" ] && break

    # A redirecting segment is a write whatever its lead word claims (echo x > .env), so it skips both exemptions; >> too.
    case "$segn_lc" in *' > '*) redirects=1 ;; *) redirects=0 ;; esac

    if [ "$pipe_to_shell" -eq 0 ] && [ "$redirects" -eq 0 ]; then
      # No self-exemption for this guard's own --check: the shell runs a segment's $( ), backticks and redirects whatever argv says.
      if is_reader "$lead"; then continue; fi
      if [ "$lead" = "git" ]; then
        sub=$(printf '%s' "$segn_lc" | awk '{ for (i=1;i<=NF;i++) if ($i=="git") { print $(i+1); exit } }')
        git_safe_subcmd "$sub" && continue
        # An n flag (-n, -fn) or --dry-run, abbreviations too, is a dry run; -e/--exclude takes the rest of its cluster or the next word, words after -- are paths, and the last of --dry-run/--no-dry-run wins.
        if [ "$sub" = "clean" ]; then
          printf '%s' "$segn_lc" | awk '{ for (i = 1; i <= NF && $i != "git"; i++) ;
            d = 0
            for (i += 2; i <= NF; i++) {
              t = $i
              if (t == "--") break
              if (length(t) >= 3 && index("--dry-run", t) == 1) { d = 1; continue }
              if (length(t) >= 6 && index("--no-dry-run", t) == 1) { d = 0; continue }
              if (t ~ /^--e(x(c[a-z]*)?)?$/) { i++; continue }
              if (t !~ /^-[a-z]+$/) continue
              f = t; sub(/e.*/, "", f)
              if (f ~ /n/) d = 1
              if (t ~ /^-[^e]*e$/) i++
            }
            exit !d }' && continue
        fi
      fi
    fi

    check_rm "$segn_lc" "$segn" "$seg" "$body"
    match_rule_table "$segn" "$segn_lc" "$sql_ctx"
    [ "$VERDICT" = allow ] && [ "$lead" = git ] && check_git_discard "$segn" "$segn_pre"
    [ "$VERDICT" = allow ] && [ "$sql_ctx" -eq 1 ] && check_sql_update "$segn_lc" "$body_lc"

    [ "$VERDICT" = "deny" ] && break
  done < <(split_segments "$body")

  [ "$VERDICT" = allow ] && check_git_gh "$body" " $full_lc "
  [ "$VERDICT" = "deny" ] || check_cd_chain "$body"
  apply_strict "$full_lc"

  # The human opt-out comes last so it can release a deny.
  if [ "$VERDICT" != "allow" ] && allow_listed "$full_lc"; then
    VERDICT=allow
  fi
  return 0
}

# The project's strictness file: "ask <ERE>" or "deny <ERE>" per line, matched like the allow-file. It only raises a verdict; an entry
# that would lower one (an allow line, an ask on a deny) is skipped with a note. Read as data; malformed or over the cap, it is ignored.
STRICT_BASENAME=command-guard-strict
STRICT_MAX_BYTES=16384
STRICT_NOTE=""

apply_strict() { # normalised lowercased command
  local f="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/$STRICT_BASENAME" line n=0 i sz tier word alt re base="$VERDICT" tiers=() res=() nums=()
  local lre='^[[:space:]]*(ask|deny|allow)[[:space:]]+([^[:space:]].*)$'
  STRICT_NOTE=""
  [ -f "$f" ] || return 0
  sz=$(wc -c < "$f" 2>/dev/null) || sz=""; sz=${sz//[[:space:]]/}
  case "$sz" in ''|*[!0-9]*) sz=$((STRICT_MAX_BYTES + 1)) ;; esac
  if [ "$sz" -gt "$STRICT_MAX_BYTES" ]; then
    STRICT_NOTE="command-guard: .claude/$STRICT_BASENAME is ignored: it is unreadable or over $STRICT_MAX_BYTES bytes."
    return 0
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1)); line=${line%$'\r'}
    case "$line" in *[![:space:]]*) ;; *) continue ;; esac
    case "${line#"${line%%[![:space:]]*}"}" in '#'*) continue ;; esac
    if ! [[ $line =~ $lre ]]; then
      STRICT_NOTE="command-guard: .claude/$STRICT_BASENAME is ignored: line $n is not \`ask <regex>\` or \`deny <regex>\`."
      return 0
    fi
    tier=${BASH_REMATCH[1]}; re=${BASH_REMATCH[2]}; re=${re%"${re##*[![:space:]]}"}
    [[ "" =~ $re ]] 2>/dev/null
    if [ $? -eq 2 ]; then
      STRICT_NOTE="command-guard: .claude/$STRICT_BASENAME is ignored: the regex on line $n does not compile."
      return 0
    fi
    tiers+=("$tier"); res+=("$re"); nums+=("$n")
  done < "$f"
  for i in "${!tiers[@]}"; do
    [[ $1 =~ ${res[$i]} ]] || continue
    tier=${tiers[$i]}
    if [ "$tier" = allow ] || { [ "$tier" = ask ] && [ "$base" = deny ]; }; then
      [ "$base" = allow ] || [ -n "$STRICT_NOTE" ] || STRICT_NOTE="command-guard: .claude/$STRICT_BASENAME line ${nums[$i]} would loosen this command's built-in $base, so it is ignored; only .claude/$ALLOW_BASENAME releases one."
      continue
    fi
    word="confirm first"; alt="check with the user first"
    [ "$tier" = deny ] && { word="keep from an agent"; alt="hand the command to the user"; }
    set_verdict "$tier" "matches line ${nums[$i]} of .claude/$STRICT_BASENAME (\`${res[$i]}\`), this project's own list of commands to $word" "$alt" " $1 "
  done
  return 0
}

allow_listed() { # normalised lowercased command
  local cmd="$1" f line
  for f in "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/$ALLOW_BASENAME" "$HOME/.claude/$ALLOW_BASENAME"; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      [[ $cmd =~ $line ]] && return 0
    done < "$f"
  done
  return 1
}

# A deny reason also has to stop the retry loop: without "do not retry" the next turn is the same command requoted.
deny_reason() {
  if [ "$V_KIND" = "cd" ]; then
    printf '%s' "BLOCKED by command-guard — \`cd ${V_WHAT}\` will fail: the directory does not exist (a denied or failed earlier call created nothing), so the steps after its \`;\` would run in the live project. Fix: ${V_ALT}, then re-issue the corrected command."
    return 0
  fi
  printf '%s' "BLOCKED by command-guard — this command ${V_WHAT}. Do not retry it in another form (other quoting, bash -c, a script file). Instead: ${V_ALT}. If the task truly needs it, ask the user to run it, or to allow this exact command with a regex line in .claude/${ALLOW_BASENAME}."
}

# Silent unless devops' plan reader exists at that path: a hint naming a file the reader does not have is worse than none.
plan_audit_hint() {
  case "$V_MATCH" in *"terraform apply"*|*"tofu apply"*) ;; *) return 0 ;; esac
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || return 0
  local p d v
  p="$(dirname "$CLAUDE_PLUGIN_ROOT")/devops/scripts/plan-audit.sh"
  if [ ! -f "$p" ]; then
    # An installed plugin sits at cache/<marketplace>/<plugin>/<version>/: take devops' newest version without .orphaned_at, a release over its pre-release.
    d="$(dirname "$(dirname "$CLAUDE_PLUGIN_ROOT")")/devops"
    v=$(for f in "$d"/*/scripts/plan-audit.sh; do
          f="${f%/scripts/plan-audit.sh}"; n="${f##*/}"
          [ -f "$f/scripts/plan-audit.sh" ] && [ ! -e "$f/.orphaned_at" ] || continue
          r=1; [ "$n" = "${n%%-*}" ] || r=0
          printf '%s.%s\t%s\n' "${n%%-*}" "$r" "$n"
        done | LC_ALL=C sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -n 1 | cut -f2)
    [ -n "$v" ] || return 0
    p="$d/$v/scripts/plan-audit.sh"
  fi
  [ -f "$p" ] || return 0
  printf ' Read the plan before answering: `terraform show -json plan.out | bash %s` exits 2 when the plan deletes or replaces a resource that holds data.' "$p"
}

ask_reason() {
  printf '%s' "command-guard: this command ${V_WHAT}. Confirm that is intended; a safer path: ${V_ALT}.$(plan_audit_hint) CLAUDE_DESTRUCTIVE_GUARD=off turns this guard off."
}

emit() { # decision ("" prints only a pending strictness-file note), reason
  local decision="$1" reason="$2"
  if [ -z "$decision" ]; then
    [ -z "$STRICT_NOTE" ] || jq -cn --arg m "$STRICT_NOTE" '{systemMessage:$m}' 2>/dev/null
    return 0
  fi
  jq -cn --arg d "$decision" --arg r "$reason" --arg m "$STRICT_NOTE" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}} + (if $m == "" then {} else {systemMessage:$m} end)' 2>/dev/null
}

# A judgment still running after GUARD_DEADLINE seconds (12; the harness lowers it) is stopped and asks in every mode, inside hooks.json's 15 s onFailure: block. No mktemp or sleep: unwatched.
judge_in_time() { # guard function, its arguments
  local out timer job
  out=$(mktemp "${TMPDIR:-/tmp}/command-guard.XXXXXX" 2>/dev/null) || { "$@"; return 0; }
  sleep "${GUARD_DEADLINE:-12}" >/dev/null 2>&1 &
  timer=$!
  # Only this shell writes the hook's stdout: the job's verdict goes through the file, so a late one cannot follow the ask.
  { "$@"; kill "$timer" 2>/dev/null; } > "$out" &
  job=$!
  if wait "$timer"; then
    kill "$job" 2>/dev/null
    emit ask "command-guard: this call took over ${GUARD_DEADLINE:-12} s to check, so data loss is not ruled out. Confirm it is safe, or split it into smaller calls. CLAUDE_DESTRUCTIVE_GUARD=off turns this guard off."
  else
    wait "$job"
    cat "$out"
  fi
  rm -f "$out"
}

check_cli() { # command -> prints its tier whatever the mode, then any strictness-file note; exits 0 allow, 1 ask, 2 deny
  local rc=0
  classify "$1"
  case "$VERDICT" in
    deny) printf 'DENY  %s\n      %s\n' "$V_MATCH" "$(deny_reason)"; rc=2 ;;
    ask)  printf 'ASK   %s\n      %s\n' "$V_MATCH" "$(ask_reason)"; rc=1 ;;
    *)    printf 'ALLOW %s\n' "$1" ;;
  esac
  [ -z "$STRICT_NOTE" ] || printf 'NOTE  %s\n' "$STRICT_NOTE"
  exit "$rc"
}

# Write/Edit and the MCP write tools an IDE session uses; apply_patch names no single path, so its body is searched for the allow-file.
guard_file_write() { # tool, payload, mode
  local tool="$1" input="$2" mode="$3" f patch
  f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
  if [ -z "$f" ]; then
    patch=$(printf '%s' "$input" | jq -r '.tool_input.input // .tool_input.patch // empty' 2>/dev/null)
    patch=$(printf '%s' "$patch" | LC_ALL=C tr '[:upper:]' '[:lower:]' 2>/dev/null || printf '%s' "$patch")
    case "$patch" in *"$ALLOW_BASENAME"*) f="$ALLOW_BASENAME" ;; esac
  fi
  case "$(printf '%s' "$f" | LC_ALL=C tr '[:upper:]' '[:lower:]' 2>/dev/null || printf '%s' "$f")" in
    *"$ALLOW_BASENAME") emit deny "BLOCKED by command-guard — ${ALLOW_BASENAME} is the user's own list of allowed destructive commands. Ask the user to add the line, and give them the exact regex." ;;
  esac
  # Ask, not deny: a whole-file Write over a live .env may be meant. Edit is targeted, and creating the file loses nothing.
  if [ "$tool" = "Write" ] && is_env_secret "$f" && [ "$mode" != "deny-only" ]; then
    CWD_MOVED=0
    env_target_at_risk "$f" && emit ask "command-guard: this Write replaces all of ${f}, a local secrets file git has no copy of. Confirm, or use Edit to change only the lines you mean. CLAUDE_DESTRUCTIVE_GUARD=off turns this guard off."
  fi
}

guard_command() { # tool, payload, mode
  local tool="$1" input="$2" mode="$3" cmd
  cmd=$(printf '%s' "$input" | jq -r '
    [ .tool_input.command // empty,
      .tool_input.query // empty,
      .tool_input.sql // empty,
      .tool_input.script // empty,
      .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || return 0
  [ -n "$cmd" ] || return 0

  # SQL by declaration, a query or sql field or an execute_sql_query tool, the one SQL name the dispatcher sends here: a bare DROP DATABASE x names no client to sniff.
  export GUARD_SQL_CTX=0
  case "$tool" in *execute_sql_query|*run_sql|*query) GUARD_SQL_CTX=1 ;; esac
  printf '%s' "$input" | jq -e '(.tool_input.query // "") != "" or (.tool_input.sql // "") != ""' \
    >/dev/null 2>&1 && GUARD_SQL_CTX=1

  classify "$cmd"
  case "$VERDICT" in
    deny)
      # The mode is read from the hook's own env, which no command string reaches: CLAUDE_DESTRUCTIVE_GUARD=off rm -rf / is denied.
      if [ "$mode" = "ask" ]; then emit ask "$(deny_reason)"; else emit deny "$(deny_reason)"; fi ;;
    ask)
      # deny-only leaves the ask tier to the host: a hook ask overrides the host's auto-mode classifier with a human click.
      if [ "$mode" = "deny-only" ]; then emit "" ""; else emit ask "$(ask_reason)"; fi ;;
    *) emit "" "" ;;
  esac
}

if [ "${1:-}" = "--check" ]; then check_cli "${2:-}"; fi
if [ "${1:-}" = "--version" ]; then printf 'command-guard %s\n' "$GUARD_VERSION"; exit 0; fi

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  mode=$(printf '%s' "$(cc_option CLAUDE_DESTRUCTIVE_GUARD deny)" | tr '[:upper:]' '[:lower:]')
  case "$mode" in denyonly|deny_only) mode=deny-only ;; esac
  [ "$mode" = "off" ] && exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit|*apply_patch|*create_new_file)
      judge_in_time guard_file_write "$tool" "$input" "$mode"
      exit 0 ;;
  esac

  # Named, not wildcarded, so an unrelated MCP tool whose arguments mention "drop table" is not gated.
  case "$tool" in
    Bash) ;;
    *execute_terminal_command|*execute_sql_query|*run_command|*shell_command|*run_in_terminal) ;;
    *) exit 0 ;;
  esac

  judge_in_time guard_command "$tool" "$input" "$mode"
  exit 0
} 2>/dev/null
exit 0
