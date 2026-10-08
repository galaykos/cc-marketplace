#!/bin/bash
# stack-evidence.sh <prime.sh> <project-root> — prints prime.sh's stack rows for the listing mod (hooks/listing.ts), run rather
#   than copied: one "D <plugin>:<skill>" line per row sr_repo_skills can add, one "E <plugin>:<skill>" line per row whose
#   evidence holds at <project-root>. Exit 3 when prime.sh defines no sr_repo_skills; otherwise 0 whatever the last row tested.
# Gate: scripts/__tests__/stack-evidence.test.sh runs it on real directories.
. "$1" && declare -F sr_repo_skills >/dev/null || exit 3
declare -f sr_repo_skills | grep -oE "add [a-z0-9-]+ [a-z0-9-]+" | awk '{ print "D " $3 ":" $2 }'
add() { printf 'E %s:%s\n' "$2" "$1"; }
sr_repo_skills "$2"
exit 0
