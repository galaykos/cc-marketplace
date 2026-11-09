---
name: pixijs-best-practices
description: Use when writing, reviewing or porting PixiJS code — `pixi.js` in package.json, `new Application`, `app.init`, `Assets.load`, `ParticleContainer`, a custom `Filter`, a v7→v8 migration — links the official v8 docs, the migration guide and the PixiJS team's agent skills.
---

> Last verified: 2026-11-09 — https://pixijs.com/8.x/guides/migrations/v8 — npm:pixi.js@8.22

## Why this is a pointer

Measured 2026-11-09 on `opus` only: 4 cases, 3 runs per arm, base 3/3 = with 3/3 on every case. The cases cover
the old v7→v8 table's rows judged most likely missed, and opus already wrote their v8 forms, so the table was
retired. No case covers `Graphics`, `cacheAsTexture()`, children only on Containers, scale modes, `preference` or
`releaseGlobalResources`. On any other model, or for those rows, read the v7 → v8 migration guide below before
writing v8 code. Cases and run: the plugin README, "Evals".

## Read these instead

- v8 guides: https://pixijs.com/8.x/guides/getting-started/intro
- v7 → v8 migration guide: https://pixijs.com/8.x/guides/migrations/v8
- API reference, latest release: https://pixijs.download/release/docs/index.html
- Release notes, for anything newer than your training data: https://github.com/pixijs/pixijs/releases
- Docs index for agents (llmstxt.org format): https://pixijs.com/llms.txt

## Third party: the PixiJS team's agent skills

`pixijs/pixijs-skills` (https://github.com/pixijs/pixijs-skills) is MIT-licensed. Its 26 skills were synced to
pixi.js 8.22.0 at commit `83760c6` (2026-10-01). It is not part of this marketplace and has not been measured
here. Installing it adds 26 entries to the skill listing. The install lines come from its README and
`.claude-plugin/marketplace.json`:

```bash
claude plugin marketplace add pixijs/pixijs-skills
claude plugin install pixijs-skills@pixijs-skills
# or, for any agent: npx skills add https://github.com/pixijs/pixijs-skills
```

Standing: recorded. `check-doc-staleness.sh --live` flags a newer `pixi.js` minor on npm. Nothing re-runs the
eval when the base model changes.
