# vercel-skills-scout

Scout [skills.sh](https://www.skills.sh) — Vercel Labs' open agent-skills
directory — for third-party skills that match the current project's stack.

The companion to [plugin-scout](../plugin-scout/README.md), pointed
outward: plugin-scout suggests this marketplace's curated,
baseline-tested plugins; vercel-skills-scout searches the open ecosystem
for what this marketplace does not cover. Same detection discipline
(manifest signals with cited evidence), deliberately stricter install
discipline — see the trust model below.

## Usage

```
/vercel-skills-scout:suggest              # detect stack, search per signal
/vercel-skills-scout:suggest <query>      # skip detection, search this instead
```

Output: one provenance table — skill, source repo, install count,
detection evidence, overlap with installed marketplace plugins, installed
status — each row linking its skills.sh page. Then a picker; each pick is
previewed (its SKILL.md fetched and summarized) before

```bash
npx -y skills add <owner>/<repo> --skill <skillId> -y
```

installs it project-level. Never `--global`.

## Trust model

skills.sh ranks by install count. Popularity is not review: a skill is
arbitrary instruction text injected into future sessions, and this plugin
vouches for none of it. Consequences, all deliberate:

- **No auto-install flag.** plugin-scout's `--yes` exists because its
  tier-1 picks are curated in-marketplace; there is no equivalent here and
  none will be added. Headless runs print commands, never execute them.
- **Provenance on every row** — source repo, installs, URL — so the user
  judges the source, not the rank.
- **Preview before install** — the picked skill's SKILL.md is fetched and
  shown before the install runs.

Standing, per this marketplace's has-teeth convention: all of the above is
recorded/agent-graded — no script gates it.

## Boundaries

- Suggests and installs skills.sh skills only; auditing, updating
  (`npx skills update`), and removal (`npx skills remove`) are out of
  scope.
- Never touches `.claude/settings.json`; skills.sh tracks its installs in
  `skills-lock.json`.
- The search API (`skills.sh/api/search`) is unofficial; on failure the
  plugin stops and points at browsing the site rather than scraping it.
