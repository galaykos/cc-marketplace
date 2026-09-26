---
name: chassis-workflow
description: How this repo's chassis generator works — .chassis.json manifests, scripts/generate.sh --check/--write, templates/, gates. Use when creating or editing any chassis-generated file (worker agents, reminder hooks, boost hooks), when a file carries a "generated from templates/..." header, when adding a .chassis.json, or when validate.sh complains about chassis headers or drift.
---

# Chassis workflow (cc-marketplace)

Generated files are never hand-edited. The header line
`<!-- generated from templates/<name>.tmpl ... -->` means: edit the template or
the plugin's `.chassis.json`, then regenerate.

## The pieces

- `plugins/<name>/.chassis.json` — ONE chassis object or an ARRAY of them.
  Three renderers survive: `worker-agent` (stamps the agent file declared in
  `agentFile`), `reminder-hook` (stamps `hooks/remind.sh`, or the `file` it names),
  `boost-hook` (stamps the `hooks/<name>.sh` named in `file` — the ultra-*
  injectors; `regex2`/`message2` add an elif branch). Plus `optout`, which
  renders nothing and declares a chassis-shaped file intentionally
  hand-written. A fifth kind, `stack-review` (with
  `templates/review-command.md.tmpl` and the build-time worker routing), was
  **retired 2026-09-22** — panel finding 64: one rendered file behind a
  template, four partials and nine justifications. `commands/review.md` is
  still a chassis-shaped NAME, so the files that kept it are `optout` entries
  now; `generate.sh` dies on `"chassis":"stack-review"`. `suite-uninstall` (with
  `templates/suite-uninstall.md.tmpl`) was **retired 2026-09-26** with the four
  suites it rendered for — no plugin may declare `dependencies`
  (`pc_plugin_dependencies`), so no bundle is left to uninstall; `generate.sh` dies on
  that kind too.
- Every artifact-rendering object also carries **`lane`** —
  `{"owns", "trigger", "yieldsTo"[, "phase"]}` — and generate.sh renders the
  plugin's lane.tsv row for that artifact into a `# generated:start` …
  `# generated:end` block. A missing `lane` key is a hard error. No surviving
  kind has a default phase: **hooks and agents must declare `phase` explicitly** (a hook's phase is what `pc_phase_guard` reads;
  `any` exempts it). Never hand-write a lane row for a generated artifact — the
  generator dies on the duplicate.
- `templates/*.tmpl` + `templates/blocks/` — the sources. Engine:
  `scripts/lib/template-engine.sh` (override with `TEMPLATE_ENGINE`).
- `scripts/generate.sh` — the stamper. Its header comment is the authoritative
  contract; read it before changing schema or vars.

## Commands

```bash
bash scripts/generate.sh --check   # render + byte-diff vs tree; NEVER writes; non-zero on drift
bash scripts/generate.sh --write   # stamp deltas; chmod +x for .sh; patch-bumps each touched plugin.json ONCE per run
```

Fixture roots for experiments: `CHASSIS_ROOT=<dir>` and `CHASSIS_TEMPLATES=<dir>`
— use a scratch copy instead of dirtying the tree.

## Procedure for a new/changed chassis file

1. Edit template and/or `.chassis.json` (single object → convert to array when
   adding a second object to the same plugin); a new artifact object needs its
   `lane` key (see The pieces).
2. `bash scripts/generate.sh --write`, then review the diff — for agent
   migrations, confirm no domain-checklist content was lost.
3. Gates before push:
   `bash scripts/generate.sh --check && bash scripts/validate.sh && bash scripts/check-version-bumps.sh master`.

## Preserve blocks — the per-region escape

When a generated file needs ONE local difference, do **not** reach for `optout`
(which forfeits every later template improvement) or add a template slot (which
re-renders EVERY sharer of that template and patch-bumps each of their
`plugin.json` in a single commit — count them first:
`grep -l '"chassis": *"worker-agent"' plugins/*/.chassis.json | wc -l`). Put a
preserve block in the template:

```
<!-- preserve:notes -->
default body, shipped by the template
<!-- /preserve:notes -->
```

`emit()` transplants the tree's version of each same-named block into the render
before ANY comparison, so both modes agree: an edit inside the block is not drift
in `--check` and is not clobbered by `--write`, while everything outside still
refreshes from the template. The template stays authoritative about WHICH blocks
exist; the tree is authoritative about what is INSIDE them.

Round trip: `bash scripts/smoke/preserve-block-tests.sh` (CI step).

## Gotchas

- Hand-editing a generated file OUTSIDE a preserve block gets reverted by the
  next `--write` and flagged by `--check`; a whole hand-shaped file needs an
  `optout` entry instead.
- An `optout` entry MUST name the file it exempts:
  `{"chassis":"optout","file":"commands/review.md","reason":"…"}`. Without
  `file` it is an error — one unscoped exemption used to cover all four
  chassis-shaped kinds at once.
- `--write` already bumps plugin.json for stamped plugins — don't double-bump.
- Chassis-shaped filenames (`commands/review.md`, `uninstall.md`,
  `hooks/remind.sh`) MUST be either generated (header) or opted out —
  `scripts/validate.sh` enforces this.
