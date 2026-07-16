# Scenario schema

A **scenario** is the unit a check runs against: a page, an ordered list of steps
that drive it, the assertions and visual checkpoints taken along the way, and the
settings that tune the comparison. One scenario answers the three questions (works ·
UI not broken · matches example) for one flow at one or more viewports.

The validator that enforces this document lives in the plugin's
`template/scenario/schema.ts`; its fixtures are in `template/scenario/__fixtures__/`.
See `engines.md` for the frozen `verdict.json` a scenario produces.

## Top-level fields

| Field            | Required | Default          | Notes                                                        |
| ---------------- | -------- | ---------------- | ------------------------------------------------------------ |
| `id`             | yes      | —                | Stable scenario id. Doubles as the `<route>` in capture keys.|
| `url`            | yes      | —                | Entry URL (a dev server or a design-preview entry).          |
| `engine`         | no       | `auto`           | `deterministic \| agent \| auto` (see `engines.md`).          |
| `threshold`      | no       | `0.01`           | Max fraction of differing pixels for a `match` to pass.      |
| `viewports`      | no       | desktop + mobile | List of `{ name, width, height }`.                           |
| `mask`           | no       | `[]`             | Selectors blanked before every capture (clocks, avatars).    |
| `allowMutations` | no       | `false`          | Opt-in to run state-changing steps — see the gate below.     |
| `steps`          | yes      | —                | Non-empty ordered list. Each step is one map (below).        |

Default viewports are `{ name: desktop, width: 1280, height: 800 }` and
`{ name: mobile, width: 390, height: 844 }`. A viewport with no `name` is named
`<width>x<height>`.

## Frozen step vocabulary

A step is a single YAML map. The step verbs are **frozen** — this is a declarative
list, not a scripting DSL, so the set never grows:

```
goto · click · type · hover · wait · expect · match
```

- **Action verbs** — `goto`, `click`, `type`, `hover`, `wait` — carry a target
  (a URL/path for `goto`, a selector for `click`/`type`/`hover`, a duration or
  selector for `wait`). A step has **at most one** action verb.
- **Checkpoint verbs** — `expect`, `match` — a step may additionally carry either or
  both. `expect` holds the "UI not broken" assertions; its four keys mirror the
  `asserts` object in `verdict.json`: `dom`, `console`, `layout`, `network`. `match`
  holds a visual checkpoint (`source` + `ref`, compared at `threshold`).
- Every step needs **at least one** verb (an action, or a standalone `expect`/`match`
  checkpoint). Two allowed non-verb keys may appear on a step: `label` (a human note)
  and `mutates` (the gate flag, below). **Any other key is rejected** as an unknown
  verb — this is how a typo or an invented action (e.g. `scroll`) fails fast.

## Per-step keying

Each step is assigned a stable, sequential 0-based `stepIndex` at parse time. Captures
are keyed:

```
<route>__<stepIndex>__<viewport>
```

where `<route>` is the scenario `id` and `<viewport>` is the viewport name — e.g.
`sidebar-toggle__1__desktop`. The `id`/`stepIndex` pair is exactly the step `id`
(`<route>__<stepIndex>`) written into `verdict.json`; appending the viewport gives
one collision-free key per artifact. Because `stepIndex` is positional and stable,
inserting a step renumbers everything after it — baselines are keyed to positions,
not to labels.

## Read-only default + the `allowMutations` gate

Driving a real browser against a real app is **read-only by default** (spec D14, a
non-negotiable safety posture). A step that changes server state — a destructive
`click` (delete, purchase, logout) or a form-submitting `type` — must be **author-
marked** with `mutates: true`. The validator does not guess intent: it trusts the
author's mark.

If any step is marked `mutates: true`, the scenario **must** set `allowMutations:
true` at the top level. A state-changing step in a scenario without that flag is
**refused** (`ScenarioError`) — it never reaches the browser. When the flag is
present, the parsed scenario carries an `announcement`
(`"this scenario performs state-changing actions"`) that the runner prints before it
starts driving, so a mutating run is always announced.

Read-only interactions — opening a menu, hovering, navigating, waiting — need no
flag and run freely.

## Setting precedence

`threshold`, `viewports`, and `mask` can be set in more than one place. The
resolution order is (spec D18):

```
CLI flag  >  scenario file  >  config.json  >  built-in default
```

A scenario may thus override the project `config.json`, but a CLI flag always wins
over the scenario. `schema.ts` exposes `resolveSettings(scenario, config, cli)` that
applies this precedence.

## Annotated example — the sidebar open → close flow

This is the canonical read-only flow (mirrored by
`template/scenario/__fixtures__/sidebar.valid.yaml`): land on the page, open the
sidebar, hover a link, close it again — checkpointing the visual state at each stop.

```yaml
id: sidebar-toggle              # stable id; also the <route> in capture keys
url: http://localhost:3000/     # entry URL
engine: deterministic           # deterministic | agent | auto
threshold: 0.01                 # max differing-pixel ratio for a match (overrides config)
viewports:                      # captured at each; name feeds the capture key
  - { name: desktop, width: 1280, height: 800 }
  - { name: mobile,  width: 390,  height: 844 }
mask:                           # blanked before every capture
  - "[data-testid=clock]"
steps:
  # stepIndex 0 — land and checkpoint the closed state
  - goto: /
    match: { source: baseline, ref: baselines/sidebar-closed.png }

  # stepIndex 1 — open the drawer; assert + checkpoint the open state
  - click: "[data-testid=sidebar-toggle]"
    expect:
      dom:
        - { selector: "nav.sidebar", state: visible }
      console: clean            # no console errors
      layout: no-overflow       # no layout overflow introduced
    match: { source: baseline, ref: baselines/sidebar-open.png }

  # stepIndex 2 — hover a link (read-only, no checkpoint required)
  - hover: "nav.sidebar a.settings"

  # stepIndex 3 — close the drawer and checkpoint the closed state again
  - click: "[data-testid=sidebar-toggle]"
    label: close the drawer
    expect:
      dom:
        - { selector: "nav.sidebar", state: hidden }
    match: { source: baseline, ref: baselines/sidebar-closed.png }
```

Every step here is read-only, so no `allowMutations` is needed. Capture keys for the
`desktop` viewport are `sidebar-toggle__0__desktop` … `sidebar-toggle__3__desktop`.

To make step 1 a destructive click instead (say it submitted a form), the author
would mark that step `mutates: true` **and** add `allowMutations: true` at the top
level; omitting the top-level flag would make the whole scenario refuse to run.
