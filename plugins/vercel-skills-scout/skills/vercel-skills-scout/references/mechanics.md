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

- `add <owner>/<repo> --skill <name> -y` — install one skill from a
  repo. Verified gotcha: `--skill` matches the skill's DISPLAY name from
  the CLI's own listing (e.g. `"Plugin Structure"`), not the skills.sh
  `skillId` (`plugin-structure`) — passing the skillId prints the repo's
  skill list and exits 0 without installing. Run
  `add <owner>/<repo> -l` first, then pass the exact listed name, and
  verify the install with `skills ls` — exit code 0 proves nothing.
  Project-level is the default inside a project; `-g`/`--global` is
  user-level and this plugin never passes it. `--skill '*'` installs a
  repo's whole set — never use it here; one pick, one skill.
- Install side effects to expect: skill content lands in
  `.agents/skills/<name>/` with symlinks into each agent dir
  (`.claude/skills/<name>`), and `skills-lock.json` appears at the
  project root — surface both to the user, who decides whether to commit
  or gitignore them.
- `ls` — list installed skills (the report's installed column).
- `remove`, `update` — lifecycle commands out of this plugin's scope;
  mention them, do not run them.
- `use <owner>/<repo>@<skill>` — generates a use-without-install prompt;
  an alternative the user can run manually to trial a skill.
- Installs symlink into agent directories by default (`--copy` to copy)
  and are tracked in `skills-lock.json` at the project root.

## TTY picker escape hatch

For very long tables an unbounded interactive multi-select ships at
`scripts/pick.sh` (fzf with TAB-toggle when available, else a numbered
prompt with ranges). It needs a real TTY, which model-run Bash lacks, so
the flow is: write the eligible rows to a scratch file as
`<number><TAB><label>` lines, print the exact
`! bash <absolute path to pick.sh> <rows file>` command for the user to
run themselves (the `!` prefix runs it user-side and its output lands in
the conversation), then read the returned `PICKED: <numbers>` line and
treat those numbers as row picks. Offer it when rows exceed two pages
(>32); never require it.

## Why no --yes / auto-install exists

plugin-scout auto-installs its tier-1 picks under `--yes` because those
plugins are curated in this marketplace and baseline-tested. skills.sh
content is arbitrary third-party instruction text that will be injected
into future sessions — popularity rank is not review, and a scouting tool
must not become an unattended installer of unvetted prompts. The
explicit-pick floor is therefore absolute: no flag bypasses the picker,
headless mode prints commands instead of running them. Standing: recorded
here and agent-graded at run time — no script gates it.
