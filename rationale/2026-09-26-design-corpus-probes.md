# Design-corpus probes: which new artifacts the control arm justified (2026-09-26)

The capability plan built from `rationale/2026-09-25-design-capability-corpus/` proposed five new artifacts. The Admission law (`CLAUDE.md`; `.claude/skills/authoring-skills/SKILL.md` "The four laws") says an artifact earns its place only by carrying a rule the base model gets wrong. So each one was probed first, as a shipped eval case, with `claude plugin eval --ablation with-without --runs 5 -j 4 --allow-tools Write Edit --keep-temp` on CLI 2.1.283, using the default haiku judge (3 votes per grader).

- **"without"** is the no-plugin arm. It is the control, and it decides admission.
- **"with"** loaded the plugin's working tree after that day's changes, so for the artifacts built here it is the after-arm.
- Per-run strings read left to right: `P` = pass, `F` = fail.

## The verdicts come from a deterministic re-grade, not the LLM judge

The judge was wrong often enough to reverse three decisions.

- **Pass 1 (`focus` unset, i.e. `last_message`).** The judge saw only the final chat message, never the files written. Runs that wrote correct code and then said "I couldn't verify this against the installed package" were failed.
- **Pass 3 (`focus: trace`).** The judge read the whole trace and still failed runs whose files were correct. For example, a marquee with a labelled Pause button and an `aria-hidden` duplicate track was failed on both graders, while a near-identical control run passed.
- **What decides.** `rationale/2026-09-25-design-capability-corpus/tools/regrade.py` rebuilds each run's **final** file contents from the kept trace (Write replaces, Edit applies old→new) and applies the criteria as regular expressions over those files.

The table below is that re-grade. The LLM-judge numbers are recorded beside it only to show how far off they were.

| case (plugin) | criterion | control | with | LLM judge said (control / with) | decision |
|---|---|---|---|---|---|
| `primereact-v11-screen` (ui-libraries) | v11 imports, `Select`, `@primeuix/themes`, no v10 paths | PFFFF (1/5) | PPPPP (5/5) | 0/5 / 5/5 | **built** `primereact-best-practices` — works |
| | licence key handled | FFFFF (0/5) | PPPPP (5/5) | 0/5 / 5/5 | (same) |
| `marquee-carousel-pause` (ui-ux) | marquee has a visible pause control (SC 2.2.2) | FPFPP (3/5) | PPPPP (5/5) | 3/5 / 1/5 | **no reference file**; the one-line SC 2.2.2 rule in `a11y-audit` closes it |
| | carousel pause control | 5/5 | 5/5 | — | base model already does it |
| | duplicate track `aria-hidden` | 5/5 | 5/5 | 5/5 / 1/5 | base model already does it |
| `spline-hero-arrival` (craft-layer) | runtime deferred | 5/5 | 5/5 | — | base model already does it |
| | reduced-motion path | 5/5 | 5/5 | — | base model already does it |
| | static poster before the scene | FFFFF (0/5) | FFPFF (1/5) | 1/5 / 3/5 (combined) | **built** `hosted-runtimes.md` (control fails the poster rule); the rule is **not landing yet** (1/5) |
| `astro-removed-apis` (web-dev) | no `Astro.glob`, no `ViewTransitions`, `content.config.ts` with loaders | PPPPP (5/5) | 5/5 | 0/5 → 4/5 → 1/5 across passes | **no Astro skill** |
| | Zod 4 `z.email()` | 4/5 | 5/5 | — | informational |
| `tiptap-next-ssr` (web-dev) | `'use client'` + `immediatelyRender:false` or `ssr:false` | 5/5 | 5/5 | 9/10 / 6/10 (passes 1–2) | **no rich-text skill** |
| | saved HTML sanitised or rendered through Tiptap | PPFFP (3/5) | PPPPP (5/5) | 10/10 / 10/10 | web-dev's new `client-widgets.md` XSS rule earns its line |

Cost: about $39 across four passes: 50 runs in the first, then 20, 40 and 10.

## Lessons, for the next probe

1. **Grade the files, not the prose.** For a build-shaped case, a regular expression or deterministic check over the final file content is the grader. An LLM judge reading a trace is a second opinion at most. The shipped `case.yaml` files keep `focus: trace` LLM graders because that is what `claude plugin eval` offers. Their descriptions now carry the deterministic counts, and a run should be spot-checked against `--keep-temp` traces before anyone quotes its score.
2. **A deprecated API is not a removed one.** The first Astro grader failed `z.string().email()`, which still works in Zod 4.
3. **Admission and effectiveness are separate questions.**
   - The Spline control fails the poster rule 5/5, so a rule is justified.
   - The reference carrying it moved the with-arm only to 1/5. Nothing makes the model open `hosted-runtimes.md` in a sandbox with no import to route on.
   - Stated, not hidden: the reference ships as `recorded`, and its effectiveness is unproven.

## What this does not show

- n=5 per arm, one day, one model; no `node_modules` in the sandboxes, so every run worked from memory.
- The regular expressions are this repo's own reading of each criterion. `regrade.py` is the record, and it can be re-run against the kept traces while `/private/tmp/e-*` survives.
