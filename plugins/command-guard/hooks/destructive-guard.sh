#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee has to hold even
# under a stripped or broken PATH, where `env bash` itself exits 127.
#
# PreToolUse guard on COMMAND EXECUTION — the Bash tool plus any MCP tool that
# shells out or runs SQL. It classifies the command about to run:
#
#   deny  — irreversible data loss whose blast radius cannot be read off the
#           command line (`php artisan migrate:fresh`, `DROP DATABASE`,
#           `docker compose down -v`, `aws s3 rb`, `terraform destroy`). The
#           model is stopped; only a human can run these.
#   ask   — destructive but commonly intended and scoped (`git reset --hard`,
#           `rm -rf ./some-dir`, `kubectl delete pod`). The user answers.
#   allow — everything else. The hook stays silent and normal permissions apply.
#
# The failure it exists for: an agent runs a schema-reset command mid-task
# because a migration looked stuck, and the data is gone before anyone reads the
# transcript. Nothing asks, because `php artisan migrate:fresh` is an ordinary
# command that happens to be terminal.
#
# Fail-open by construction: any error, missing jq, or unparseable input allows
# the call. A guard that breaks the session gets uninstalled, and then it guards
# nothing.
#
# CLI mode for testing and for /command-guard:check —
#   destructive-guard.sh --check '<command>'   exit 0 allow | 1 ask | 2 deny

GUARD_VERSION=0.1.0

# ---------------------------------------------------------------------------
# Normalisation. Every rule matches against a canonical form, because the raw
# string has too many ways to say the same thing: extra whitespace, quotes
# around a subcommand (`artisan "migrate:fresh"`), backslash escapes, a leading
# `sudo`. Quote stripping is what makes the quoted-evasion forms match the same
# rule as the plain one.
# ---------------------------------------------------------------------------
norm_cmd() {
  printf '%s' "$1" \
    | tr '\n\t' '  ' \
    | sed -e "s/[\"'\\\\]//g" -e 's/>/ > /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//'
}

# Segment a command on shell separators (; && || | newline) so a rule fires on
# the segment that would EXECUTE the match, not on a segment that merely quotes
# it. Splitting is quote-aware on the RAW string — dequoting first would split
# `grep -E "a|rm -rf /"` into a fake `rm -rf /` segment.
split_segments() {
  printf '%s' "$1" | awk '
    BEGIN { RS = "\0"; seg = "" }
    {
      n = length($0); sq = 0; dq = 0
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1); nx = substr($0, i + 1, 1)
        if (c == "\\" ) { seg = seg c nx; i++; continue }
        if (c == "'"'"'" && !dq) { sq = !sq; seg = seg c; continue }
        if (c == "\"" && !sq) { dq = !dq; seg = seg c; continue }
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

# First real word of a segment, with the wrappers that carry no semantics of
# their own stripped: sudo, env assignments, time, nohup, xargs -I{} …
lead_word() {
  printf '%s' "$1" | awk '
    { for (i = 1; i <= NF; i++) {
        w = $i
        if (w ~ /^(sudo|nohup|time|command|builtin|exec|nice|ionice)$/) continue
        if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
        if (w ~ /^-/) continue
        sub(/^.*\//, "", w)
        print w; exit
      } }'
}

# Segments whose lead word only READS are skipped: `grep -r "migrate:fresh" .`
# is a search, not a migration. The exemption is dropped for the whole command
# when its output is piped into a shell — there the reader's output IS the
# program.
READERS=' echo printf cat grep egrep fgrep rg ag ack less more head tail wc sort uniq jq yq column ls tree stat file diff comm man which type printenv env true false date basename dirname pwd '

is_reader() {
  local w="$1"
  case "$w" in
    git) return 1 ;;  # `git` is decided by its subcommand, not by being git
    "") return 0 ;;
  esac
  case "$READERS" in *" $w "*) return 0 ;; esac
  return 1
}

# git subcommands that cannot lose committed or working-tree data. `commit` is
# on the list for a reason beyond safety: a commit MESSAGE is prose, and prose
# about a migration ("remove the drop table step") would otherwise trip the SQL
# rules. The destructive subcommands — reset, clean, push --force, branch -D,
# checkout/restore, stash, gc, reflog, filter-branch, update-ref — are absent by
# design and stay subject to the table.
git_safe_subcmd() {
  case "$1" in
    log|show|diff|status|blame|ls-files|ls-remote|rev-parse|describe|config|remote|fetch|shortlog|grep|cat-file|whatchanged) return 0 ;;
    commit|add|tag|merge|revert|cherry-pick|rebase|pull|clone|init|apply|am|worktree|submodule|bisect|switch|notes|mv) return 0 ;;
  esac
  return 1
}

# Anything that speaks SQL, including the wrappers people reach it through
# (`docker compose exec db psql …`, `ssh host mysql …`, `php artisan tinker`).
# Tested against the WHOLE command, not the segment, because a heredoc body
# (`mysql <<SQL` / `DROP TABLE x;` / `SQL`) splits into segments that no longer
# name the client.
SQL_CLIENT_RE=' (mysql|mysqldump|mariadb|psql|pgcli|sqlite3|sqlcmd|mongosh|mongo|redis-cli|clickhouse-client|cockroach|snowsql|usql|sqlplus|dbmate|tinker|artisan|rails|sequelize|knex|prisma|wrangler|supabase|pscale|planetscale|bq|duckdb|influx|cqlsh|turso|libsql|flyway|liquibase|doctrine|alembic|typeorm) '

# ---------------------------------------------------------------------------
# Rule table. TAB-separated: TIER \t REGEX \t WHAT \t ALTERNATIVE
#
# Regexes are POSIX ERE matched against the normalised segment, which is padded
# with a leading and trailing space — so ` rm ` matches a bare `rm` at either
# end. A regex containing an uppercase letter is matched CASE-SENSITIVELY
# against the case-preserving form (that is the only way `git branch -D` can be
# told from `git branch -d`); every other rule matches the lowercased form.
#
# deny rules are listed first and win: the loop takes the first hit.
# ---------------------------------------------------------------------------
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
denysql	 truncate (table )?[a-z_`\[]	TRUNCATE empties the table and is not transactional on every engine	a DELETE with a WHERE clause inside a transaction
deny	[ /]dropdb( |$)	drops a PostgreSQL database	dump it first
deny	mysqladmin .*drop	drops a MySQL database	dump it first
denysql	(flushall|flushdb)( |$)	empties the Redis keyspace, including anything persisted	delete the specific keys or use a scoped pattern
denysql	dropdatabase\(	drops the MongoDB database	drop the specific collection, after a dump
denysql	deletemany\( *\{ *\}	an empty filter matches every document in the collection	pass a filter
deny	 git (filter-branch|filter-repo)	rewrites every commit; old objects become unreachable	work on a copy of the repo, or a scratch clone
deny	 git reflog expire	discards the reflog, which is the recovery path for a bad reset	leave the reflog alone; it expires on its own
deny	 git gc .*--prune=now	prunes unreachable objects immediately, destroying the recovery path	plain `git gc`
deny	 git push .*(--force( |$)| -f( |$))	overwrites remote history for everyone who has pulled it	`--force-with-lease`, and only on a branch you own
deny	 git push .*(--delete|--mirror)	deletes remote refs	delete the branch in the host UI where it is reviewable
deny	 git update-ref -d	deletes a ref directly, bypassing the reflog protections	`git branch -d`
deny	 git clean [^ ]*x	-x also removes IGNORED files: .env, local configs, credentials	`git clean -fd` (leaves ignored files), or `git stash -u`
deny	 rm ([^ ]+ )*\.env( |$|\.)	.env holds the only copy of local credentials; it is not in git	copy it aside first
deny	 > \.env( |$)	truncates .env to empty; the credentials are gone	write to a temp file and move it into place
deny	docker(-| )compose .*down .*(-v( |$)|--volumes)	removes named volumes, which is where the database lives	`docker compose down` keeps volumes
deny	 docker volume (rm|prune)	deletes container volumes and everything stored in them	inspect first; remove one volume by name after a dump
deny	 docker system prune .*(-a|--all|--volumes)	removes volumes and all unused images across the machine	prune images only, or scope to one project
deny	 kubectl delete (ns|namespace|pvc|persistentvolumeclaim|statefulset|sts)( |$)	deletes persistent storage or the whole namespace	scale to zero, or delete a single pod
deny	 terraform destroy	tears down every managed resource, including databases	`terraform plan -destroy` and read it
deny	 pulumi destroy	tears down every resource in the stack	`pulumi preview --diff`
deny	 aws s3 (rb |rm .*--recursive|sync .*--delete)	deletes bucket contents; versioning may not be on	list the keys first, delete a prefix explicitly
deny	 aws [a-z0-9-]+ (delete|terminate|purge)[a-z-]*	an AWS delete/terminate call is not undoable from the CLI	do it in the console where the confirmation names the resource
deny	 (gcloud|az|doctl|pscale|wrangler|flyctl|fly|heroku) .*(delete|destroy)( |$)	a cloud delete removes a live resource for everyone	do it in the provider console
deny	 heroku pg:reset	drops every table in the Heroku Postgres database	`heroku pg:backups:capture` first
deny	 gh (repo|release|secret|cache) delete	deletes a GitHub resource for the whole repository	delete it in the web UI
deny	 npm unpublish	removes a published package version other projects may depend on	deprecate it instead
deny	 mkfs(\.[a-z0-9]+)?( |$)	formats a filesystem	nothing about this belongs in an agent session
deny	 dd .*of= */dev/	writes directly over a block device	nothing about this belongs in an agent session
deny	 > /dev/(sd|nvme|disk|hd)	writes over a raw disk	nothing about this belongs in an agent session
ask	 git reset --hard	discards every uncommitted change in the working tree	`git stash` keeps them recoverable
ask	 git clean 	deletes untracked files, which are not recoverable from git	`git stash -u` stashes untracked files instead
ask	 git checkout -- \.( |$)	discards all unstaged changes	`git stash`
ask	 git restore \.( |$)	discards all unstaged changes	`git stash`
ask	 git branch -D 	force-deletes a branch even if it is unmerged	`git branch -d` refuses when work would be lost
ask	 git stash (clear|drop)	discards stashed work with no reflog to recover it	`git stash list` and drop one entry by index
ask	 git push .*--force-with-lease	rewrites remote history, but only if nobody else pushed	confirm the branch is yours
ask	[ /]artisan migrate .*--force	runs pending migrations in production, including destructive ones	read the pending migrations first
asksql	 delete from 	a DELETE with no WHERE on this line rewrites every row	add a WHERE clause, inside a transaction
ask	 docker (rm|container rm) .*-f	force-removes running containers	stop them first
ask	 docker system prune	removes unused containers, networks and images	scope it to one project
ask	 kubectl delete 	removes a live cluster object	`--dry-run=client` first
ask	 helm (uninstall|delete) 	removes a release and possibly its storage	`helm get manifest` first
ask	 terraform apply .*-auto-approve	applies without showing the plan, which may include destroys	apply without -auto-approve and read the plan
ask	 vagrant destroy	deletes the VM and its disk	`vagrant halt`
ask	 (vercel|railway|netlify) (remove|rm|down)( |$)	removes a deployment or project	do it in the dashboard
ask	 npm publish	publishes to a public registry; the version can never be reused	`npm publish --dry-run`
ask	 find [^ ]* .*-delete( |$)	deletes every path the find matched	drop -delete and read the list first
ask	 (shred|srm) 	overwrites files so they cannot be recovered	plain rm leaves the file recoverable by backup
ask	 truncate -s ?0	empties the file in place	move it aside instead
ask	 history -c	clears the shell history for the user	nothing in the task needs this
ask	 chmod -[a-z]*r[a-z]* (777|666) 	recursively makes a tree world-writable	set the narrowest mode on the specific path
RULES
}

# ---------------------------------------------------------------------------
# Verdict state, set by classify()
# ---------------------------------------------------------------------------
VERDICT=allow   # allow | ask | deny
V_WHAT=""       # what the command does
V_ALT=""        # the non-destructive alternative
V_MATCH=""      # the segment that matched

set_verdict() { # tier what alt match
  # deny wins over ask; the first deny wins over later denies.
  [ "$VERDICT" = "deny" ] && return 0
  [ "$VERDICT" = "ask" ] && [ "$1" = "ask" ] && return 0
  VERDICT="$1"; V_WHAT="$2"; V_ALT="$3"; V_MATCH="$4"
}

# Build artifacts: regenerated by a build, so `rm -rf` on them is ordinary work
# and prompting on it would train the user to click through the prompt.
ARTIFACT_RE='^(\./)?(node_modules|vendor|dist|build|out|target|coverage|\.next|\.nuxt|\.turbo|\.cache|\.parcel-cache|__pycache__|\.pytest_cache|\.venv|venv|tmp|temp|\.tmp|storage/framework/(cache|views|sessions)|bootstrap/cache)/?\*?$'

# `rm -rf` is the one rule that cannot be a regex: whether it is catastrophic
# depends on the TARGET, and the targets live in the same string as the flags.
check_rm() { # normalised segment (lowercased, padded)
  local seg="$1" flags="" targets="" tok recursive=0 t
  case "$seg" in *" rm "*) ;; *) return 0 ;; esac

  # tokens after the rm word
  targets=$(printf '%s' "$seg" | awk '{ seen=0; for (i=1;i<=NF;i++) { if (!seen) { if ($i=="rm") seen=1; continue } ; print $i } }')
  flags=$(printf '%s\n' "$targets" | grep '^-' | tr -d '\n')
  case "$flags" in *r*|*R*) recursive=1 ;; esac
  [ "$recursive" -eq 1 ] || return 0

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case "$tok" in -*) continue ;; esac
    case "$tok" in
      /|/\*|\~|\~/|\~/\*|.|./|./\*|..|../\*|\*|\$home|\$home/|\$home/\*)
        set_verdict deny \
          "recursively deletes ${tok} — the whole filesystem, home directory, or the entire working tree" \
          "name the specific directory to delete" "$seg"
        return 0 ;;
    esac
    # A single-component absolute path (/etc, /var, /usr) is a system directory.
    # This has to be a regex: a shell `case` glob cannot say "no slash after the
    # first one" — `/[a-z]*` matches /opt/app/releases/12 too, which silently
    # made every absolute path a deny.
    if printf '%s' "$tok" | grep -qE '^/[a-z0-9_.-]+/?\*?$'; then
      set_verdict deny "recursively deletes the system directory ${tok}" \
        "work inside the project directory" "$seg"
      return 0
    fi
    # unexpanded variable: if it is unset or empty, the path collapses to / or to cwd
    case "$tok" in
      *'$'*)
        set_verdict ask "recursively deletes ${tok}; if that variable is unset the path collapses (rm -rf \$X/ becomes rm -rf /)" \
          "expand the variable first and check it is non-empty, or use \${X:?} so the shell refuses when unset" "$seg"
        continue ;;
    esac
    t="$tok"
    printf '%s' "$t" | grep -qE "$ARTIFACT_RE" && continue   # build artifact: fine
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

# The allow-file is the human's opt-out. It is only an opt-out if the model
# cannot write it — so writing it is itself blocked, in both directions (this
# check for Bash, the tool_name branch below for Write/Edit).
ALLOW_BASENAME=destructive-guard-allow

# Runs on EVERY segment, reader or not: `echo … >> allow-file` is an echo by
# lead word and a write by effect, and exempting it would have left the opt-out
# self-editable — the one hole that turns the whole gate into a formality.
# Reading the file stays fine.
check_self_protection() { # normalised segment, lead word
  local seg="$1" lead="$2"
  case "$seg" in *"$ALLOW_BASENAME"*) ;; *) return 0 ;; esac
  case "$seg" in
    *' > '*) ;;                       # a redirect at any position is a write
    *) is_reader "$lead" && return 0 ;;  # cat/grep/less on the file: allowed
  esac
  set_verdict deny \
    "writes to the guard's own allow-file, which would let the next command through unchecked" \
    "ask the user to add the exemption themselves; the file is theirs by design" "$seg"
}

# Whole-command rules: shapes the segment splitter would cut in half, because
# the separator IS the hazard.
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

# ---------------------------------------------------------------------------
# classify: raw command string -> VERDICT / V_WHAT / V_ALT / V_MATCH
# ---------------------------------------------------------------------------
classify() {
  local raw="$1" full full_lc seg segn segn_lc lead sub tier re what alt pipe_to_shell=0 sql_ctx=0

  full=$(norm_cmd "$raw")
  full_lc=$(printf '%s' "$full" | tr '[:upper:]' '[:lower:]')
  check_whole " $full_lc "

  # SQL rules only fire when something in the command speaks SQL. Without this
  # gate, `git commit -m "remove the drop table step"` and
  # `npm test -- --grep "delete from users"` both read as executed SQL.
  printf '%s' " $full_lc " | grep -qE "$SQL_CLIENT_RE" && sql_ctx=1

  # Output piped into a shell: the reader exemption is off for this command,
  # because `echo "rm -rf /" | sh` is not an echo.
  printf '%s' " $full_lc " | grep -qE ' \| *(sudo )?[a-z]*sh( |$)| \| *xargs ' && pipe_to_shell=1

  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    segn=$(norm_cmd "$seg")
    [ -n "$segn" ] || continue
    segn_lc=" $(printf '%s' "$segn" | tr '[:upper:]' '[:lower:]') "
    segn=" $segn "

    lead=$(lead_word "$segn")
    check_self_protection "$segn_lc" "$lead"
    [ "$VERDICT" = "deny" ] && break

    if [ "$pipe_to_shell" -eq 0 ]; then
      # SELF-EXEMPTION — this guard's own `--check` CLI is a classifier, not a
      # runner. Without this, the plugin denied the exact command its own
      # /command-guard:check tells the model to type, for exactly the deny-tier
      # targets that command exists to explain — and the deny text then says "Do
      # NOT retry", so the model abandoned the check. Reproduced live before the
      # fix; the harness never caught it because it exercises CLI mode and hook
      # mode separately and never sends the hook a Bash payload whose command IS
      # the check invocation (the grade-the-branch-the-host-never-takes shape
      # `pc_harness_payload` closes for harnesses).
      #
      # NARROW BY CONSTRUCTION, and every clause is load-bearing:
      #   - lead word must be bash/sh (not `eval`, not a pipe-to-shell: this whole
      #     branch is already gated on pipe_to_shell=0 above),
      #   - the script path must END in hooks/destructive-guard.sh,
      #   - `--check` must be present — the ONE flag that classifies and exits
      #     without executing its argument (see the CLI-mode block: it calls
      #     classify(), prints, and exits; it never runs "$2").
      # A segment naming this script WITHOUT --check still falls through and is
      # classified normally, so `bash destructive-guard.sh --allow-everything` is
      # not exempt.
      #
      # POSITIONAL, NOT SUBSTRING — and that distinction is a fixed vulnerability,
      # not a style note. The first version of this exemption matched the three
      # tokens ANYWHERE in the segment:
      #     *" bash "*destructive-guard.sh*" --check "*
      # `bash -c PAYLOAD name arg…` runs PAYLOAD and makes everything after it
      # $0/$1/…, so appending the literal words `destructive-guard.sh --check y`
      # to a `bash -c "<destructive>"` call satisfied all three substrings while
      # the shell still executed the payload. That re-opened the exact `bash -c`
      # wrapper hole this guard's own deny text warns models not to try. Matching
      # by POSITION closes it: `-c` lands in word 2, where only the guard's own
      # path is accepted.
      gw1=$(printf '%s' "$segn_lc" | awk '{print $1}')
      gw2=$(printf '%s' "$segn_lc" | awk '{print $2}')
      gw3=$(printf '%s' "$segn_lc" | awk '{print $3}')
      case "$gw1" in
        bash|sh)
          if [ "$gw3" = "--check" ]; then
            case "$gw2" in
              */hooks/destructive-guard.sh|hooks/destructive-guard.sh|destructive-guard.sh)
                continue ;;
            esac
          fi ;;
      esac
      if is_reader "$lead"; then continue; fi
      if [ "$lead" = "git" ]; then
        sub=$(printf '%s' "$segn_lc" | awk '{ for (i=1;i<=NF;i++) if ($i=="git") { print $(i+1); exit } }')
        git_safe_subcmd "$sub" && continue
      fi
    fi

    check_rm "$segn_lc"

    while IFS=$'\t' read -r tier re what alt; do
      [ -n "$tier" ] || continue
      case "$tier" in
        *sql) [ "$sql_ctx" -eq 1 ] || continue
              tier="${tier%sql}" ;;
      esac
      # A rule carrying an uppercase letter is case-sensitive by convention —
      # `git branch -D` must not match `git branch -d`.
      if printf '%s' "$re" | grep -q '[A-Z]'; then
        [[ $segn =~ $re ]] && set_verdict "$tier" "$what" "$alt" "$segn"
      else
        [[ $segn_lc =~ $re ]] && set_verdict "$tier" "$what" "$alt" "$segn_lc"
      fi
      [ "$VERDICT" = "deny" ] && break
    done < <(rules)

    [ "$VERDICT" = "deny" ] && break
  done < <(split_segments "$raw")

  # Human opt-out, checked last so it can release a deny. Regex per line,
  # matched against the whole normalised command.
  if [ "$VERDICT" != "allow" ] && allow_listed "$full_lc"; then
    VERDICT=allow
  fi
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

# ---------------------------------------------------------------------------
# Reason text. It has one job beyond explaining: stop the retry loop. A model
# that reads "blocked" without reading "do not rephrase" will try the same
# command with different quoting, and each attempt costs a turn.
# ---------------------------------------------------------------------------
deny_reason() {
  printf '%s' "BLOCKED by command-guard — this command ${V_WHAT}. The guard cannot tell a local database from production from the command line, so it does not ask; this is a hard stop. Do NOT retry it with different quoting, a wrapper (bash -c, eval), a script file, or a split-up form — the guard reads those too, and working around a safety gate is not the task. Non-destructive path: ${V_ALT}. If the destructive command is genuinely what the task needs, stop and tell the user exactly which command you want run and why, and let them run it. Standing opt-out (the user's call, not yours): a regex line in .claude/${ALLOW_BASENAME}."
}

ask_reason() {
  printf '%s' "command-guard: this command ${V_WHAT}. Confirm that is intended and that anything it removes is either recoverable or not needed. Less destructive path: ${V_ALT}."
}

emit() {
  local decision="$1" reason="$2"
  jq -cn --arg d "$decision" --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}' 2>/dev/null
}

# ---------------------------------------------------------------------------
# CLI mode
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  classify "${2:-}"
  case "$VERDICT" in
    deny) printf 'DENY  %s\n      %s\n' "$V_MATCH" "$(deny_reason)"; exit 2 ;;
    ask)  printf 'ASK   %s\n      %s\n' "$V_MATCH" "$(ask_reason)"; exit 1 ;;
    *)    printf 'ALLOW %s\n' "${2:-}"; exit 0 ;;
  esac
fi
if [ "${1:-}" = "--version" ]; then printf 'command-guard %s\n' "$GUARD_VERSION"; exit 0; fi

# ---------------------------------------------------------------------------
# Hook mode. Everything below fails open.
# ---------------------------------------------------------------------------
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  mode=$(printf '%s' "${CLAUDE_DESTRUCTIVE_GUARD:-deny}" | tr '[:upper:]' '[:lower:]')
  [ "$mode" = "off" ] && exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

  # Write/Edit branch: the allow-file is a human artefact. Denying the model's
  # edit is what makes it an opt-out rather than a formality.
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit)
      f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$f" in
        *"$ALLOW_BASENAME") emit deny "BLOCKED by command-guard — ${ALLOW_BASENAME} is the user's standing exemption list for destructive commands. An agent that can edit it can exempt itself. Ask the user to add the line; tell them the exact regex you want." ;;
      esac
      exit 0 ;;
  esac

  # Command-execution tools: the Bash tool, plus MCP tools that shell out or run
  # SQL. Named explicitly rather than by wildcard so an unrelated MCP tool whose
  # arguments happen to contain "drop table" is not gated.
  case "$tool" in
    Bash) ;;
    *execute_terminal_command|*execute_sql_query|*run_command|*shell_command|*run_in_terminal) ;;
    *) exit 0 ;;
  esac

  cmd=$(printf '%s' "$input" | jq -r '
    [ .tool_input.command // empty,
      .tool_input.query // empty,
      .tool_input.sql // empty,
      .tool_input.script // empty,
      .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
  [ -n "$cmd" ] || exit 0

  classify "$cmd"
  case "$VERDICT" in
    deny)
      # CLAUDE_DESTRUCTIVE_GUARD=ask downgrades every deny to a prompt. It is
      # read from the hook's own environment, which a command string cannot
      # reach — `CLAUDE_DESTRUCTIVE_GUARD=off rm -rf /` does not disable it.
      if [ "$mode" = "ask" ]; then emit ask "$(deny_reason)"; else emit deny "$(deny_reason)"; fi ;;
    ask)
      emit ask "$(ask_reason)" ;;
  esac
  exit 0
} 2>/dev/null
exit 0
