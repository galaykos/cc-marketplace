---
description: Inventory installed runtimes, frameworks, and packages from manifests, lockfiles, and container images
argument-hint: [path]
---

Invoke the installed-versions skill from this plugin against $ARGUMENTS (or the
repository root if no argument). Steps:

0. Run the mechanical pass FIRST: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh
   <path>` — it emits the node/php/python/docker table rows and the mechanical
   red flags deterministically. Do not re-derive by hand what it already
   printed; your job starts where it stops (ecosystems it names as not
   covered, and interpretation).
1. Scan whatever scan.sh did not cover — remaining manifests, runtime pins, CI
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
