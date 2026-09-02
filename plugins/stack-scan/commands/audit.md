---
description: Audit composer/npm dependencies — vulnerabilities, outdated packages, and dependency licences against the project's distribution mode; severity-sorted with a fix lane per finding; report-only
---

Audit the project's dependencies for vulnerabilities and outdated packages against
the `package-hygiene` skill from this plugin. Invoke the skill first.

Detect: check for `composer.json` and `package.json` at the project root. Determine
the JS package manager from the lockfile present: package-lock.json → npm,
yarn.lock → yarn, pnpm-lock.yaml → pnpm. If an ecosystem's manifest is absent, skip
it and say so in the report. If neither manifest exists, say so and stop.

Run read-only commands only — no fixes (`/security:review` runs the same audit
commands when reviewing a diff; with both installed, this command is the depth
pass and security's review should cite it rather than re-run):
- composer present: `composer audit` and `composer outdated --direct`
- JS present: `npm audit` / `yarn npm audit` / `pnpm audit` per detected PM, and
  `npm outdated` or the PM's equivalent

Report findings severity-sorted (critical → high → medium → low; advisory
"moderate" maps to medium), one line per
finding: `package — severity — direct|transitive — fix lane`, where fix lane is one
of: patch bump / minor bump / major bump / no fix available. After findings, give an
upgrade-lane summary: counts per lane, plus the outdated-but-not-vulnerable packages
grouped patch/minor/major.

This command is report-only — apply nothing unasked. End by offering as a selectable
choice (AskUserQuestion when available): "Apply the patch-lane fixes now
(Recommended)" / "Skip — report only". When headless, print the exact commands the
user would run instead.

## Licence lane

Dependency licences are the third axis of this audit and the only one with a
script, because it is the only one a read cannot do. Run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/licence-scan.sh --dir . --distribution <mode>
```

`<mode>` is `saas`, `distributed-binary`, `internal`, `oss-permissive` or
`oss-copyleft`. **Ask the user which one if it is not already in
`.licence-policy.json`, and do not guess** — the mode IS the decision, and the
axes run opposite ways: MPL-2.0 and LGPL are routine in a SaaS backend and a
hazard in a shipped binary; AGPL is the exact inverse, biting hardest on SaaS,
where "we don't distribute, so copyleft doesn't apply" is precisely wrong.

Report the script's output, and say three things it makes visible that a
`package.json` read cannot:

- **Which findings are transitive.** Almost all of them will be. A denied licence
  usually arrives through a dependency of a dependency, so "we didn't install
  that" is not a defence and the fix is upstream, not in the manifest.
- **Exit 3 is not a pass.** It means unresolvable: an npm `lockfileVersion` 1
  carries no licence data at all, so a scan of it finds nothing for the wrong
  reason. Say that plainly rather than reporting "no licence issues".
- **This is declared metadata, not legal truth.** It cannot see a dual-licensed
  package that declares one side, vendored code with no manifest entry, or a
  LICENSE file contradicting the declared SPDX id. Never present it as advice a
  lawyer would give.
