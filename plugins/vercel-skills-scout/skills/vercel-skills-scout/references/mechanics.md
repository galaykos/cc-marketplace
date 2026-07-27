# Mechanics: skills.sh API, URLs, CLI

Ground-truth details the SKILL.md flow relies on. All of it was verified
against the live site and CLI in July 2026; every item here is
unofficial-surface and may drift — when reality disagrees with this file,
trust reality and update this file.

## Search API

```
GET https://www.skills.sh/api/search?q=<url-encoded query>
```

Response (200, JSON):

```json
{
  "query": "react",
  "searchType": "fuzzy",
  "skills": [
    {
      "id": "vercel-labs/agent-skills/vercel-react-best-practices",
      "skillId": "vercel-react-best-practices",
      "name": "vercel-react-best-practices",
      "installs": 582792,
      "source": "vercel-labs/agent-skills"
    }
  ]
}
```

- Up to 100 results, sorted by installs descending.
- No descriptions in the payload — the report's provenance URL and the
  install-time preview cover that gap.
- Unofficial and undocumented: no auth, no versioning, no stability
  promise. Non-200 or unparseable body → stop searching, point the user at
  browsing <https://www.skills.sh>; do not fall back to scraping HTML.

## URL formats

- Skill page: `https://www.skills.sh/<owner>/<repo>/<skillId>` (verified
  200).
- Raw SKILL.md preview, tried in order until one returns 200:
  1. `https://raw.githubusercontent.com/<owner>/<repo>/main/skills/<skillId>/SKILL.md`
  2. `https://raw.githubusercontent.com/<owner>/<repo>/master/skills/<skillId>/SKILL.md`
  3. `https://raw.githubusercontent.com/<owner>/<repo>/main/<skillId>/SKILL.md`
  4. `https://raw.githubusercontent.com/<owner>/<repo>/master/<skillId>/SKILL.md`

  Repos lay skills out differently; if all four miss, the preview is
  unavailable — name the skill page URL and ask before installing that
  pick.

## CLI (npx skills)

Published by Vercel Labs; `npx -y skills <command>`.

- `add <owner>/<repo> --skill <skillId> -y` — install one skill from a
  repo. Project-level is the default inside a project; `-g`/`--global` is
  user-level and this plugin never passes it. `--skill '*'` installs a
  repo's whole set — never use it here; one pick, one skill.
- `ls` — list installed skills (the report's installed column).
- `remove`, `update` — lifecycle commands out of this plugin's scope;
  mention them, do not run them.
- `use <owner>/<repo>@<skill>` — generates a use-without-install prompt;
  an alternative the user can run manually to trial a skill.
- Installs symlink into agent directories by default (`--copy` to copy)
  and are tracked in `skills-lock.json` at the project root.

## Why no --yes / auto-install exists

plugin-scout auto-installs its tier-1 picks under `--yes` because those
plugins are curated in this marketplace and baseline-tested. skills.sh
content is arbitrary third-party instruction text that will be injected
into future sessions — popularity rank is not review, and a scouting tool
must not become an unattended installer of unvetted prompts. The
explicit-pick floor is therefore absolute: no flag bypasses the picker,
headless mode prints commands instead of running them. Standing: recorded
here and agent-graded at run time — no script gates it.
