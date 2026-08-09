---
description: Inventory installed runtimes, frameworks, and packages from manifests, lockfiles, and container images
argument-hint: [path]
---

Invoke the installed-versions skill from this plugin against $ARGUMENTS (or the
repository root if no argument).

**Steps 1-4 belong in a subagent.** This command reads every manifest, every
lockfile, the Dockerfiles and the CI configs, and returns one table plus a
one-line summary — and it is most often called as a *precursor* to other work,
so the raw lockfile content it reads competes for context with the task that
asked for it. Dispatch with the Agent tool, resolving `installed-versions`'
installed `SKILL.md` to an absolute path as a `Read <abs-path>` line, since a
subagent cannot invoke a skill and the skill's source-precedence order is the
whole method. Require back exactly the four outputs below — the table with its
per-cell citations, the red-flag list (or the explicit "none found"), and the
one-line stack summary — and no lockfile excerpts. Step 5's question stays in
this thread; a subagent cannot ask it.

Steps:

1. Scan manifests, lockfiles, runtime pins, Dockerfiles/compose files, and CI
   configs per the skill's source order; run version binaries (`php -v`,
   `node -v`, `bun -v`) only if available — never install anything.
2. Output the required-vs-installed table with a source citation per cell.
3. List the red flags found (multiple lockfiles, missing locks, constraint/lock
   drift, runtime mismatches, EOL majors, docker/local divergence) — or state
   explicitly that none were found.
4. End with the one-line stack summary other commands can reuse (e.g. "PHP 8.5 /
   Laravel 13 / MariaDB 11.4 / Node 24 + pnpm / Vue 3.5").

5. If red flags were found, ask via AskUserQuestion: "Fix the addressable
   flags now (Recommended)" (e.g. remove the duplicate lockfile, align the
   runtime pin) / "Skip — inventory only". Headless: inventory only.
