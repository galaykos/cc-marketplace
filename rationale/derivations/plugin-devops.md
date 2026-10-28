# devops hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-devops.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/devops/hooks/workflow-guard.sh

### Moved 2026-10-28

The comments below left the file on 2026-10-28, verbatim with only the `# ` leader and its indentation removed; each is introduced by the code line it sat above, as that line read on the day it moved.

Header:

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
under a stripped/broken PATH, where `env bash` itself exits 127.

PreToolUse guard on writes to .github/workflows/. DENIES exactly two shapes —
the ones with no legitimate form, where the workflow hands repository secrets or
a write token to code the repository does not control:

  1. pull_request_target (or workflow_run) checking out the untrusted head.
  2. An attacker-controlled ${{ github.event.* }} field interpolated into a
     `run:` block, which is shell substitution, not argument passing.

Everything else workflow-audit.sh reports — unpinned actions, a missing
permissions: block, self-hosted runners on fork triggers — is a WARN there and
is NOT denied here. A deny that fires on the ambiguous cases is a deny that gets
turned off, and then the two unambiguous ones stop being blocked too.

Why a hook at all, given both shapes are well-documented: nobody asks. Workflow
files get edited during unrelated work and reviewed for step ordering. The hook
is the thing that asks, at the only moment the answer is cheap.

BASH WRITES (0.8.2). A heredoc body or echo/printf arguments whose pipeline writes an
in-scope file are judged exactly like a Write of that text to that file
(cc_bash_write_chunks for the text, cc_bash_write_targets for the file it lands in; a
relative target matches the relative patterns as spelled). Text fed to a command that
writes no file (`yq eval - <<EOF`, `gh api --input - <<EOF`) is not read. An append
(`>>`) is judged on the appended text alone, as an Edit is on its new_string, so a
rule-1 trigger already in the file whose `ref:` arrives by append is NOT caught.
echo/printf arguments are read as written with ONE leading quote stripped, so
`echo '  - run: …' >> .github/workflows/ci.yml` is judged as its line. An echo chunk is
one line, so it can only ever meet rule 2. NOT caught on an echo: a flag or extra space
before the quote (`echo -n '…'`, `echo  '…'`), `printf '%s\n' '…'` (the format comes
first), a run line that itself holds `<<`, an escaped multi-line echo (`echo -e '…\n…'`,
`$'…'`, not unescaped), and a quoted string spanning lines. Also NOT caught: interpreter
writes (python open(), php file_put_contents), cp/mv/install of a prepared file into
.github/workflows/, `sed -i`/`perl -i` edits (the target resolves, no text is judged),
`{ …; } > f` groups, a path held in a variable, a path relative to an earlier `cd` in
the command or to a session cwd already under .github/ (targets match as spelled), a
here-string, a second heredoc on one line, printf format substitution, and any target
after the first on one writer (`tee a b` checks `a`).

Fail-open: any error, missing jq, or unparseable input allows the write.
CC_WORKFLOW_GUARD unset: the /config option cc_workflow_guard decides.
```

Above `in_scope() {`:

```text
A COMPOSITE ACTION IS THE SAME SINK. `.github/actions/<name>/action.yml` carries
`runs.steps[].run:` and is called from a workflow with that workflow's token, so the
identical `${{ github.event.pull_request.title }}` interpolation is the identical
command execution — and until 2026-09-22 it was allowed here while the same body in
`workflows/ci.yml` was denied. Rule 1 cannot fire on a composite (it has no `on:`
triggers); rule 2 is the whole point. NOT covered: an action.yml anywhere else in the
tree, and a composite that shells out to a script file the guard never sees.
```

Above `if [ -z "$reason" ]; then`:

```text
2. Attacker-controlled expression in a shell step. Matched by LEAF: base.sha
   and number are GitHub-generated and safe, and denying them would make this
   fire on ordinary CI.
```

Above `[ "$(cc_option CC_WORKFLOW_GUARD on)" = "off" ] && exit 0`:

```text
OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
uninstalling the plugin. Every other guard in the marketplace ships one,
and a global install makes "turn it off here" a real need.
```

Above `auditroot="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"`:

```text
The path in the message has to be one the READER can type. `plugins/devops/scripts/…`
is this marketplace's own layout and does not exist on an installer's disk; resolve
the real root the host hands the hook, and fall back to this script's own directory.
```

Above `reason="$reason CC_WORKFLOW_GUARD=off turns this check off."`:

```text
Name the escape in the message that blocks you.
```
