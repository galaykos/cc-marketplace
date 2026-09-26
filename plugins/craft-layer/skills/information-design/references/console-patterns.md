# Console patterns — hosting, deploy and observability surfaces

This file covers the anatomy of a console's instruments. Related rules live elsewhere:
- table discipline (column order, alignment, the four states, one tab stop per grid):
  `dense-ui-patterns.md`;
- what happens when data arrives mid-read (buffers, announcements, tickers):
  `live-surfaces.md`.

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The "without it" failures are inferred from reviewing shipped consoles. They are not measured.

## Shell and resource header

- **Environment-path breadcrumb.** The breadcrumb reads org › project › service › environment,
  and every segment is a menu button that lists its siblings with their status.
  - Label production in words, not only with a tint or a dot.
  - *Without it:* the environment switcher sits somewhere else, and the user cannot tell which
    environment the next click changes.
  - `recorded`; the status text is SC 1.4.1, `agent-graded`.
- **Resource header.**
  - Name first.
  - Then a meta line: region, size, branch, and the short commit hash as a link.
  - Then one status pill: dot plus word ("Running"), never a bare dot (SC 1.4.1).
  - Use the mono face for machine strings only (IDs, hashes, commands, metric keys). Everything
    else takes the text face.
  - `agent-graded`

## Log stream

- **Columns.**
  - Timestamp: tabular figures, fixed width, one zone named in the header (UTC or local,
    toggleable).
  - Level: a fixed-width column, word plus colour, never colour alone.
  - Then source or instance, then message.
  - Wrap is a toggle, and a long line never widens the page. `agent-graded` (SC 1.4.1)
- **Tail and follow.**
  - Follow is on while the user is at the bottom. Scrolling up pauses it and shows "Resume · N
    new lines". Returning to the bottom resumes.
  - Never yank the scroll position of someone reading a stack trace.
  - `recorded`
- **Bounded buffer.**
  - The DOM holds a capped ring of lines, and past that cap it virtualizes.
  - History comes from search or paging, not from an array that grows for as long as the tab
    is open.
  - `recorded`
- **Live-region budget.**
  - The stream itself is NOT a live region. A log in `aria-live`, or in `role="log"`, reads
    every line aloud.
  - Announce state changes only ("Deploy failed at Build", "Stream paused") through one polite
    status region, at most one message every few seconds.
  - `agent-graded` (SC 4.1.3)
- **Filtering.**
  - Level toggles and a text or regex filter apply to the buffer and to history. Filter state
    lives in the URL.
  - Map ANSI colours to theme roles and strip every other escape sequence. Never render log
    content as HTML: that is an injection path (`security:security-review`).
  - `recorded`

## Deploy history and pipeline

- **History table.** Newest first. Columns:
  - started: relative, with the absolute time in `<time datetime>`;
  - actor or trigger;
  - commit: the short hash in mono, linked, plus the first line of the message;
  - branch;
  - duration, in tabular figures;
  - status.

  The rollback action names its target: "Roll back production to a1b2c3d". `recorded`
- **Lifecycle is not severity.** The states are queued, building, deploying, live, idle,
  cancelled and failed.
  - In-progress states take a neutral role plus an indeterminate cue. Under reduced motion that
    cue becomes text.
  - Only a terminal failure takes the critical role. A cancelled deploy is not a failure.
  - Roles are `ui-ux:theming-system`'s.
  - *Without it:* "building" is shown in the warning role and "cancelled" in red. `recorded`
- **Pipeline.**
  - Steps form an ordered list (`<ol>`), left to right (top to bottom on narrow widths). Each
    step shows its name, a state word and a duration.
  - The running step carries `aria-current="step"`. A failed step expands to its log excerpt.
  - The whole pipeline has a text summary: "Failed at Build · step 2 of 5 · 1m 42s".
  - *Without it:* a row of coloured dots. `agent-graded` (SC 1.1.1, 1.4.1)

## Resource meters

- **The number is the primary read.** CPU, memory and disk show as a percentage number plus a
  bar, and the bar is secondary.
- **Meter semantics.** A bounded gauge is `<meter>`, or `role="meter"` with an `aria-valuetext`
  like "72% of 2 GB". Never use `progressbar`: a gauge is not a task.
- **Thresholds.** Mark a threshold with a tick or a word, not only a colour change. A
  per-service sparkline states its window ("last 1 h").

`agent-graded` (SC 1.4.1, 4.1.2)

## Uptime and heartbeat strip

- **Text summary.** The strip of N day-bars comes with a text summary: "99.95% over 90 days ·
  2 incidents". An incident list or table carries the per-day detail.
- **Keyboard.** If individual bars are inspectable, the strip is one tab stop with arrow keys,
  and each bar's tooltip also shows on focus and stays while it is hovered (SC 1.4.13).
- **Banner.** The status banner is text, not an icon.
- *Without it:* 90 unlabelled coloured divs.

`agent-graded` (SC 1.1.1, 1.4.1, 1.4.13)

## Topology canvas

- **Node content.** Each service node shows its name and a status word.
- **Keyboard route.** The canvas is one tab stop: arrows move between nodes and Enter opens one.
- **List twin.** The same services also appear as a table: name, status, depends-on. Selection
  syncs both ways.
- The full contract is in `spatial-surfaces.md`.
- *Without it:* nodes a mouse can reach and a keyboard cannot.

`agent-graded` (SC 2.1.1)

## Environment and time-range controls

- **Global time range.**
  - One segmented control (1H · 24H · 7D · 30D · custom) governs every chart and table on the
    page.
  - Its state lives in the URL, and the active range and zone are stated in text.
  - A custom range accepts typed dates.
  - No tile keeps a silent range of its own. `dense-ui-patterns.md` calls this cross-tile
    consistency.
  - `recorded`
- **Segmented-control semantics.** Use a radio group with arrow keys, or toggle buttons with
  `aria-pressed`. Use tabs only when the control swaps panels. `agent-graded` (SC 4.1.2)

## Command-copy chip

- **The prompt is not copied.** `$ <command>` renders in mono, and the prompt glyph sits outside
  the copied text.
- **A named button.** The copy control is a real button with a name ("Copy install command").
- **Spoken confirmation.** It confirms through a polite status message ("Copied"), not only by
  swapping its icon.
- **A real command.** The command is real and runs against the current version.
- *Without it:* the `$` lands in the clipboard, and the confirmation is visual only.

`agent-graded` (SC 4.1.2, 4.1.3)

## The console on the front door

- **Build the specimen from the app itself.** Use the app's own components and tokens: the same
  type scale, table and status pills. That keeps it true as the product changes; a redrawn
  picture drifts.
- **Real nouns.** Seed service names, regions and commit messages, with plausible numbers.
- **Mono for machine strings only.**
- **Fixed polarity**, and a deliberate crop.
- **Operable or `inert`.** Either the query really runs, or the whole specimen is `inert` with
  a text equivalent.

Frame, crop, layers, data and LCP: `product-mock.md`. `recorded`
