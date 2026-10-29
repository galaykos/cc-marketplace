# brain hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader (and the indentation before it) removed; the lines the file kept are not repeated here. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-brain.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/brain/hooks/inject.sh

### Header

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
even under a stripped/broken PATH.
SessionStart primer for the `brain` plugin. Injects the committed codebase map
(brain/INDEX.md), delimited and labeled as project data and bounded to ~30 lines /
~2 KB, with a one-line staleness hint when the map predates the current commit.
Fail-open: any error exits silently and emits nothing.
Reads at the project root (state-root block below), not the payload cwd: the cwd
follows the model's `cd` (finding 2, rationale/2026-09-25-session-plugin-usage-
review.md), so a compaction's SessionStart after `cd app/Models` would look for
app/Models/brain/INDEX.md, find none, and size-gate the nudge on that directory's
files alone (`git ls-files` is cwd-relative).
```

### The no-map nudge

```text
Discoverability nudge: plugin enabled but no map yet → emit one short hint so it is
not silently forgettable. This is the plugin talking (not project data), so it is NOT
inside the fenced block. The nudge stops for good the moment a map exists. Still a pure
read — no state written.
Only on a `startup` SessionStart: the hook has no matcher, so every resume, clear and
compaction reprinted the nudge, up to ten times in one real session (measured 2026-10-13). A
payload with no `source` counts as startup. Residual: each new session still prints it.
```

```text
Size-gate the nudge: a map only pays in repos with real surface area. Small
repos (<200 tracked source-ish files) never see the hint. Fast index read,
fail-open like everything else here.
```

### The staleness hint

```text
Staleness hint: the header records `built: <short-hash>`. Prefix-match it against
the FULL current HEAD hash — robust to git's abbreviation length changing over time
(a bare `--short` can widen after a fetch and cause a spurious mismatch).
Small drift (≤5 changed files) self-heals: the hint instructs the MODEL to run the
incremental index right away — auto from the user's seat. Larger drift stays an
explicit offer (a big reindex spends real tokens; the user decides). The hook itself
still writes nothing — the model performs the refresh, visibly, in the session.
```

### Counting the drift

```text
The count must come from git's OWN exit status, not the pipeline's: piping to
`wc -l` made the status wc's, so a `built:` hash no longer reachable in the
repo (rebased, squashed, shallow clone, hand-edited stamp) fell through as
drift=0 and the hint read "behind HEAD (built <hash>, 0 files changed)" —
a number that contradicts the warning beside it. Unknown drift now prints no
count.
brain/ itself is excluded: committing the map advances HEAD past its own
`built:` stamp, so counting it ordered an unasked refresh every session after,
which the indexer answered "already current" and restamped
(rationale/marketplace-taskforce-review-2026-10-11.md). Zero files changed
outside brain/ — the map's own commit, an empty or a reverted one — means the
map is current: no hint at all.
```

### During a task-runner run

```text
An active task-runner run advances HEAD per card; its scope-lock hook would
flag a brain/*.md write as out-of-scope and order it reverted. During a run,
demote the "refresh now" imperative to the passive offer so the two hooks
never issue opposite instructions on the same edit.
```
