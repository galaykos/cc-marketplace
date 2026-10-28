# overseer hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-overseer.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/overseer/hooks/announce.sh

### Header

```text
Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
SessionStart announcer for the `overseer` plugin. Prints ONE line when the project
has an open program (a milestone that is neither done nor parked) so a fresh session
knows to /overseer:resume instead of starting cold. Resolves the project the same way
program.sh does — the git toplevel of the session cwd, else the cwd itself — so a
session opened in a subdirectory is still announced. Silent when no program exists,
when every milestone is done or parked (that program is closed; `program.sh close`
archives it), or on any error. Pure read — writes nothing.
Killed (timeout 10s): prints nothing; the resume command still works, so a missed
announcement costs one manual /overseer:status, never state.
```

## plugins/overseer/hooks/track-read.sh

### Header

The `# context-key-ok:` marker and its reason stay in the file unchanged.

```text
Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
PostToolUse on Read for the `overseer` plugin — the read ledger behind the read-before-record
gate. While a program is open in the session's project, every Read of a regular file appends
one row, "<epoch>\t<session_id>\t<physical path>", to <project>/.claude/overseer/.reads.
`program.sh evidence add --file X` then refuses a file no Read in THIS session touched since
X last changed: a screenshot nobody opened proves nothing, and before this ledger "the file
exists, not what it shows" was the plugin's own unenforceable row. Lifted from the
verify-gate in anthropics/cwc-long-running-agents (a PreToolUse deny unless the evidence
file was Read first); here the deny sits in program.sh, which is where accept already lives.
Prints NOTHING on stdout — zero context cost per Read. Silent when no program is open in
the project (every non-overseer project pays nothing), on a relative path that does not
resolve, on a missing file, and on any error. Killed (timeout 5s): the row is lost and
program.sh says the gate is inactive for the session, never that the file was read.
LIMITATION: a Read proves the bytes reached a context, not that a judgment was made on
them; that half stays agent-graded. A subagent shares the parent's session_id, so a
browser-tester's Read counts for the session that dispatched it — intended: the walk may
be delegated, the look must happen somewhere in this session.
```

### IDE reads

```text
`.*read_file` covers an IDE-MCP read, which uses the same `file_path` key (JetBrains
MCP schema, read 2026-09-14). A session reading every artifact through the IDE would
otherwise satisfy no evidence kind that requires the artifact to have been opened.
```
