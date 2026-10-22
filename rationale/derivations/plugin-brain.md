# brain: the comment text moved out of the code (2026-10-22)

The text below was moved verbatim on 2026-10-22 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-brain.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved. One statement below is no longer true and is kept as written: "Still a pure read — no state written" — since brain 0.4.6 the no-map nudge writes one marker per project.

## plugins/brain/hooks/inject.sh

### Header

```text
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
