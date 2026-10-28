# toolchain-experts scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader (and the indentation before it) removed; the lines the file kept are not repeated here. Three of the lines under "The script_body array shapes" were awk comments inside the awk program, not shell comments. A pointer by name was left in the file's header, `# Why, limits, history: rationale/derivations/plugin-toolchain-experts.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/toolchain-experts/scripts/detect-analyzers.sh

### Header

```text
detect-analyzers.sh — report which static analyzers a project ACTUALLY has,
how to invoke them, what they suppress, and how strictly they are configured.
Usage: detect-analyzers.sh [project-root]   (default: .)

WHY THIS EXISTS. rationale/stack-skill-baselines.md measured four
best-practice checklists for these same stacks at zero-to-negative delta
against a blind control: restating public documentation is what a model
already does. What a blind model has no route to is the project's OWN
configuration — which analyzer is authoritative, what its baseline already
forgives, and which rules are switched off. This script emits that, so an
expert agent grades against the project instead of against memory.

Output lines, one record per line, stable and greppable:
  analyzer  <lang> <tool> <config|-> <baseline|-> <invocation>
  formatter <lang> <tool> <config>            # reported, never graded
  strictness <tool> <key> <value>             # the config-gap evidence
  ci <workflow> <tool>                        # tool named in a CI workflow
  none      <reason>

Exit 0: at least one analyzer detected. Exit 1: none — the caller must say so
and stop, NOT fall back to a remembered checklist. Exit 2: bad usage.

HONEST LIMITATION. Detection is by config-file presence and manifest
grep — it does not resolve monorepo workspaces, per-package configs below the
root, or a tool invoked only through a wrapper script it cannot read. A tool
reported here may still fail to run (missing vendor/, node_modules/); the
caller runs it and reports the real exit code. Absence of a `ci` line means
"not found by grep in .github/workflows", never "not enforced".
```

### vue-tsc, astro check and svelte-check

```text
vue-tsc supersedes tsc when the project has .vue single-file components:
plain tsc cannot parse them, so reporting tsc here would send the caller
at a command that fails for a reason unrelated to the code under review.
svelte-check and `astro check` are the same case for .svelte and .astro:
measured 2026-09-22, a SvelteKit project carrying svelte-check in
devDependencies was reported as `npx tsc --noEmit`, which parses none of
its components. Does NOT catch a project mixing two of these frameworks
(Astro with a Svelte integration reports astro only, the first branch
that matches), a framework with no branch here (it still falls through to
plain tsc), or a JS-only project whose config is jsconfig.json.
```

### tsconfig is JSONC

```text
tsconfig.json is JSONC, and the file tsc scaffolds is ~100 lines of
COMMENTED-OUT flags with explanatory text. Grepping it raw reports those
as enabled — measured 2026-09-15 against a real project, where this
claimed noUncheckedIndexedAccess and exactOptionalPropertyTypes were on
when `tsc --showConfig` resolves both as absent. For a detector whose
entire job is naming what the checker CANNOT see, a false "covered" is
worse than no record at all, so strip comments before matching.
```

### Flags implied by strict

```text
Flags `strict: true` turns on implicitly. Reporting these as `absent`
when strict is on would send a reader hunting null-safety gaps that are
already covered; reporting the NON-implied ones as covered would hide
the real ones. The split is the content.
```

### Flags not implied by strict

```text
NOT implied by strict — these stay off unless named explicitly, which is
what makes them the highest-value gap in an otherwise-strict project.
```

### react-hooks/exhaustive-deps

```text
The single highest-value config gap in a React codebase: the rule that
catches stale-closure and missing-dependency bugs is frequently present
but demoted to a warning, so CI stays green while the defect ships.
```

### react/button-has-type

```text
A typeless <button> inside a <form> submits it. Measured 2026-09-25: a "Try with …"
button in a composer also saved the post, found only by a reviewer reading code.
Reported only where eslint-plugin-react is configured — `absent` there is the gap.
```

### The CI cross-check

```text
Which of the above CI actually runs. A repo can carry three configs and
enforce one; the enforced one is the authoritative rubric, and nothing but
the workflow file says which it is.

Workflows rarely name the tool directly. `run: composer ci:check` hides
phpstan two levels down a composer script chain, and `npm run types:check`
hides tsc one level down package.json. Grepping the workflow alone reports
"not enforced" for a repo that enforces everything — measured against a real
Laravel + Inertia project on 2026-09-15, where the first version of this
script missed phpstan, tsc, eslint and prettier, all four of them enforced.
So resolve script references transitively, bounded at depth 4, and say which
reading produced each record.
```

### script_body

```text
script_body <manifest> <script-name> — print a script's definition text,
handling both the scalar ("lint": "eslint .") and array (composer) shapes.
```

### The script_body array shapes

```text
A bare "[" opens a multi-line array; anything else is the value itself,
which may be a scalar OR a single-line array. Both shapes ship in the
wild — the single-line one was missed until a fixture caught it.
```

### astro check and astro-check

```text
`astro check` is two words wherever a script invokes it, while the
analyzer record above names it astro-check; match both spellings rather
than rename the record. Bare `astro` is deliberately not a token: it
would label `astro build` as an analyzer step.
```

