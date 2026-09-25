# task-runner prose derivations moved out of skills (2026-09-25)

task-runner's on-invoke prose corpus went over `pc_plugin_corpus`'s 160,000 B cap
(167,709 B) when the UI walk landed. The rules stayed in the skills; the derivations
below (why a rule exists, what was measured) moved here verbatim so the skills could
shrink without losing the record. Each heading names the file the text came from.

## plugins/task-runner/skills/task-execution/references/ui-walk.md

> Card verify lines are shell, and reviewers read code, so no per-card check sees a rendered
> page. Measured 2026-09-25: in one session, 34 UI workers made 0 browser calls, and eight UI
> defects surfaced after the build (two of them found only by a 2-minute browser check).
> Another session, with the same tools, walked in the orchestrator and caught a 375 px
> overflow and a reduced-motion bug that seven reviews had missed.

Why only the orchestrator walks:

> Parallel workers would share one browser, the worker agents hold no MCP tools, and a
> plugin subagent ignores `mcpServers`.

The overflow probe was checked on a fixture: it caught a fixed-width column and skipped
a table inside its own scroller.

> Cost measured: about 30 calls and 5 minutes for a first walk, and 3 calls for a re-walk.

Shot handling: saving under `/tmp` lost a shot once, hence "save where the tool may write
(`.playwright-mcp/`), then `mv`". A walk set (1280/375) is never paired with a
`dk snapshot` set (1440/390) because every pixel would differ. The design-kit `review`
command was checked: `DESIGN_KIT_DIR` makes the walk dir the preview docroot, so the page
and its images load over the URL.

## plugins/task-runner/skills/task-execution/references/routing.md

Step 5, what an unbound `Workflow` `agent()` loses:

> Everything the resolved agent carries in its frontmatter body is then silently absent —
> including `task-executor`'s *"match the surrounding file's naming and idiom, not its
> comment density"* and its *"new behavior no test exercises is named as untested"* rule.
> Without them the output drifts from the repo's comment density and test ratio while every
> gate passes green.

Step 6, why `--target` is the card's declared file: it is an authoring property the worker
cannot arrange around. The step exists so a delegated/parallel-group card gets the teeth
check the inline path already had.

Batch dispatch item 3, why the cheap tier does not apply to batches:

> Three S-sized `security` cards satisfy every batching condition and none of that rule's;
> a card's implementation is still judgment. This keeps `dispatch-tiers.md`'s "never
> downgrades an agent below its frontmatter" invariant exception-free.

## plugins/task-runner/skills/task-execution/references/reviewer-routing.md

§ Tracks, why every leaf card gets an exemption record:

> The record costs one command and keeps the count honest; without it the gate would refuse
> a run that did nothing wrong, which is a worse failure than the silence it replaced.

## plugins/task-runner/skills/code-redteam/SKILL.md and verification-panels/references/ultra-assess.md

Why the inline fallback keys on "no dispatch mechanism at all", not on a missing `Workflow`
tool (the same sentence appeared in both files):

> Keying the fallback on `Workflow` alone downgrades the ordinary interactive session,
> which is the case a boosted run is most often invoked from.

## plugins/task-runner/skills/verification-panels/references/dispatch-tier.md

Why the boost hooks enumerate their own banner family instead of refusing
`ultra-<anything> ACTIVE`:

> The enumeration is the fix for a live false-negative: the loose form also matched the
> harness's own vocabulary, so "ultracode active — now ultra-task X" and "ultrathink
> active, ultra-task X" silently suppressed the boost the user had just typed. Narrowing
> converts "any mention anywhere fires the boost" into "a mention that reads like an
> invocation fires it".

## plugins/task-runner/skills/delegation-contracts/references/tree-wide-gates.md

> Observed shape: one agent ran a banned-register grep over its own files, reported green,
> and then flagged in PROSE that it had no idea about the rest of the tree because siblings
> had written most of it. That prose flag is the only reason the tree was ever checked. The
> warning was prudent; the mechanism was not — the next agent will not write the paragraph.

## plugins/task-runner/skills/track-orchestration/SKILL.md and references/algorithm.md

Why live track worktrees are named in the halt/handoff report:

> `.claude/worktrees/` is also where the harness's own `EnterWorktree` puts trees, and
> `ExitWorktree` prompts the user to keep or remove at session exit — so name the run's live
> track worktrees in the halt/handoff report, or a keep-or-remove prompt lands on the user
> with no way to tell which trees a mid-flight run still needs.

Why the leaf's nc records go to the MAIN repo by absolute path:

> The completion gate counts nc records under the session's own cwd, and `.claude/` is
> gitignored, so a record written inside a worktree merges nowhere and is invisible to the
> gate. Omit these two flags and a tracks run reaches completion with N done cards and zero
> controls recorded, and the gate refuses the stop — the same
> blocks-having-done-nothing-wrong failure § Coverage records exists to prevent, arriving
> through the other record channel.
