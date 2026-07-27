---
description: Search skills.sh for stack-matched third-party skills — provenance table, preview on pick, install via npx skills add; query argument overrides detection.
argument-hint: [query]
---

Invoke the vercel-skills-scout skill from this plugin. $ARGUMENTS, when
present, is a free-text search query that replaces stack detection.
Steps:

1. Preflight per the skill: check `npx` availability, list installed
   skills.sh skills via `npx -y skills ls` (fail-open), and record
   installed marketplace plugins via `claude plugin list` for the overlap
   column.
2. Detect per the skill: with a query argument, use it as the only query;
   otherwise self-scan the project's manifests and derive queries from the
   signal table. Zero signals and no argument: ask for a query
   (headless: report "no stack signals" with a rerun hint and stop).
3. Query `https://www.skills.sh/api/search?q=<query>` per query and print
   the numbered provenance table (# | skill | source repo | installs |
   evidence | overlap | installed) as defined by the skill, top 5 per
   query, deduplicated. On API failure, stop and point at browsing
   https://www.skills.sh.
4. Run the picker per the skill's Install section: max density — each
   AskUserQuestion call fills 4 multiSelect questions x 4 options (16
   slots), one "Stop — skip remaining" slot per call, paging until every
   row was offered; Other takes numbers and/or `source/skillId` (ranges
   OK). No recommended-set option: nothing on skills.sh is vetted. Headless:
   print the exact `npx -y skills add <owner>/<repo> --skill <skillId> -y`
   commands and stop. There is no auto-install flag — see the skill's
   Boundaries.
5. For each pick: preview its SKILL.md per the skill's Install section,
   then run the install command, reporting per-skill success or failure
   and the final installed/failed/skipped summary line.
