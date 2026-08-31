#!/usr/bin/env bash
# card-lint-record.sh — the run record the three card linters leave behind, and the
# ONE place its location, name and format are decided. Sourced by the writers
# (verify-teeth-lint.sh, skills-stamp-lint.sh, spec-ledger-lint.sh) and by the reader
# (hooks/card-lint-observe.sh). Writer and reader sharing one file is the point: a
# drift between them would disable the observation silently, with every gate still
# green — which is the failure this whole path exists to make visible.
#
# WHY A RECORD AT ALL. The three linters are gates WHEN THEY RUN, and nothing
# observed that they ran: a card set could reach execution having had none of them
# invoked, with every check in the repo green. The record is what an after-the-fact
# reader can count.
#
# WHY THE RECORD IS KEYED ON THE CARD, NOT ON THE CALLING CONTEXT. Cards are linted
# in the AUTHORING session and executed later — often another session, and always
# another transcript once subagents carry the work. A record namespaced by the
# writer's context could never be found by the reader, so the identity has to be the
# card itself. The state that IS context-scoped — "have I already warned about this
# set in this transcript" — belongs to the hook, and is keyed there on a hash of
# transcript_path, never on session_id (a subagent shares its parent's) and never
# raw in a path (transcript_path is absolute).
#
# WHERE. A `.lint-records/` directory beside the target, so records travel with the
# card set and neither side has to agree on a cwd or a git root. Override with
# CC_CARDLINT_DIR (the harness does, to stay out of a real card set).
#
# FORMAT. One tab-separated line appended per invocation:
#   <iso8601-utc>  <linter>  <verdict>  <target-basename>
# Appended, never truncated: a card linted, fixed and re-linted keeps both rows, and
# the last row for a linter is its current verdict.
#
# Standing: `recorded`. Writing a record proves the linter was invoked against that
# file and nothing else. It does not re-read the card, and a record can be created by
# hand — what it closes is the honest-but-forgetful skip, not deliberate evasion.
# Every function here fails silently and returns 0: a linter must never fail because
# its bookkeeping could not be written.

cardlint_dir() { # $1 = target file -> ledger dir (not created)
  if [ -n "${CC_CARDLINT_DIR:-}" ]; then
    printf '%s' "$CC_CARDLINT_DIR"
  else
    printf '%s/.lint-records' "$(dirname "$1")"
  fi
}

cardlint_file() { # $1 = target file -> that file's record path
  # The name is the target's basename, which is already a legal filename by
  # construction — no hash needed here, and a readable ledger is worth more than
  # one nobody can grep. (The hook's transcript key is a different thing entirely
  # and IS hashed; see the header.)
  printf '%s/%s.log' "$(cardlint_dir "$1")" "$(basename "$1")"
}

cardlint_write() { # $1 = linter name, $2 = target file, $3 = verdict. Always 0.
  local d f
  [ -n "${2:-}" ] || return 0
  d=$(cardlint_dir "$2") 2>/dev/null || return 0
  f=$(cardlint_file "$2") 2>/dev/null || return 0
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s\t%s\t%s\t%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" "$1" "${3:-run}" "$(basename "$2")" \
    >> "$f" 2>/dev/null || return 0
  return 0
}

cardlint_has() { # $1 = linter name, $2 = target file -> 0 when a record exists
  local f
  f=$(cardlint_file "$2") 2>/dev/null || return 1
  [ -r "$f" ] || return 1
  grep -q "$(printf '\t%s\t' "$1")" "$f" 2>/dev/null
}
