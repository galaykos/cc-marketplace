---
description: Audit composer/npm dependencies — vulnerabilities and outdated packages, severity-sorted with a fix lane per finding; report-only
---

Audit the project's dependencies for vulnerabilities and outdated packages against
the package-hygiene skill from this plugin. Invoke the skill first.

Detect: check for `composer.json` and `package.json` at the project root. Determine
the JS package manager from the lockfile present: package-lock.json → npm,
yarn.lock → yarn, pnpm-lock.yaml → pnpm. If an ecosystem's manifest is absent, skip
it and say so in the report. If neither manifest exists, say so and stop.

Run read-only commands only — no fixes:
- composer present: `composer audit` and `composer outdated --direct`
- JS present: `npm audit` / `yarn npm audit` / `pnpm audit` per detected PM, and
  `npm outdated` or the PM's equivalent

Report findings severity-sorted (critical → high → moderate → low), one line per
finding: `package — severity — direct|transitive — fix lane`, where fix lane is one
of: patch bump / minor bump / major bump / no fix available. After findings, give an
upgrade-lane summary: counts per lane, plus the outdated-but-not-vulnerable packages
grouped patch/minor/major.

This command is report-only — apply nothing unasked. End by offering as a selectable
choice (AskUserQuestion when available): "Apply the patch-lane fixes now
(Recommended)" / "Skip — report only". When headless, print the exact commands the
user would run instead.
