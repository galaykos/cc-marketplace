# Outside tools — offered, never installed

> Last verified: 2026-10-29 — https://github.com/rtk-ai/rtk — https://github.com/NVIDIA/SkillSpector — https://github.com/Manavarya09/design-extract

Three tools from outside both marketplaces, each carrying something no plugin here ships.
Install lines are copied from each tool's own README and licences read from its `LICENSE`
on the date above; re-read both before trusting a row after that date.

## How the scout uses this file

- Print a row in the `Beyond this marketplace` block, after the `official-complements.md`
  rows, when its **Offered when** column fires. A manifest part follows the tier-1 evidence
  rule (the file plus the key); a part that is a request fires only when the person made it.
- Print the row's licence cell with it, the rtk BUSL-1.1 sentence word for word.
- Every command is **printed, never run** — not under `--yes`, not under `--full`. The
  person installs a tool, or does not; the scout never runs one without their yes.
- `✓` when the binary is already on PATH: `command -v rtk`, `command -v skillspector`,
  `command -v designlang`.

## Rows

| Tool | What it does | Offered when | Install, from its README | Licence, read 2026-10-29 | Overlap here |
|---|---|---|---|---|---|
| [rtk](https://github.com/rtk-ai/rtk) | Rewrites the agent's shell commands (`git status`, test runners, `ls`, `grep`) so their output is filtered and compressed before the model reads it, through a Claude Code `PreToolUse` hook on Bash. The built-in Read, Grep and Glob tools do not pass through it | Shell-heavy work, asked for: the person raises token cost or long command output. A manifest alone never offers it | `brew install rtk` (macOS, Linux), `winget install rtk-ai.rtk` (Windows) or `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \| sh`; then `rtk init -g` for Claude Code. `rtk gain` must show the savings dashboard: another project named rtk exists on crates.io | The CLI is Apache-2.0. **Its engine, `rtk-engine`, is under BUSL-1.1: source-available, not open source — check the terms before commercial use.** Its grant: "You may use the Licensed Work in production, without charge, including as a component of the `rtk` command-line binary and the `rtk-proxy` daemon distributed by RTK AI Labs. This grant does not permit offering the Licensed Work, or a derivative of it, to third parties as a paid or hosted product or service". Each version becomes Apache-2.0 four years after its release or on 2030-09-09, whichever comes first (`engine/LICENSE`). An Apache-2.0-only edition without the engine: `brew install rtk-ai/tap/rtk-oss`. `rtk init -g` also offers to send Claude Code's API traffic through the separate `rtk-proxy` daemon, BUSL-1.1 as well: a second yes | None filters command output. `rtk init -g` asks, then patches `~/.claude/settings.json` (keeping a `.bak`), so the hook runs in every project; it is untested beside this marketplace's own Bash hooks |
| [SkillSpector](https://github.com/NVIDIA/SkillSpector) | NVIDIA's scanner for agent skills: prompt injection, data exfiltration, privilege escalation, supply-chain and malicious-code patterns, a 0-100 risk score and a `SAFE` / `CAUTION` / `DO_NOT_INSTALL` verdict. Its LLM stage is on by default and sends the skill's file contents to the provider you configure; `--no-llm` keeps the scan static (dependency names still go to OSV.dev) | A third-party skill is about to be installed: `vercel-skills-scout` runs it before each install when it is on PATH and offers it in one line when it is not. Or `skills-lock.json` or `.agents/skills/` exists — third-party skills already installed, scanned with `skillspector scan .agents/skills/ --recursive --no-llm` | `uv tool install git+https://github.com/NVIDIA/skillspector.git` (Python 3.12+); the README also builds a Docker image for use without Python | Apache-2.0 (`LICENSE`, `pyproject.toml`). Its README warns that installing it downloads other open-source projects whose terms to review | None scans a skill. `vercel-skills-scout` shows a skill's text for a person to read; `secret-scanning` and `security` read this project's code, not a skill about to be installed |
| [design-extract](https://github.com/Manavarya09/design-extract) (`designlang`) | Opens a live URL in a headless browser and reads the design system from computed styles: DTCG tokens, a Tailwind config, shadcn theme variables, Figma variables, motion tokens and WCAG contrast pairs, written to `./design-extract-output/` | A UI project must match a live site or brand: the person names the URL, in a repo with `tailwind.config.*`, `components.json`, or a React, Vue or Next.js dependency in `package.json` | `npm i -g designlang`, then `designlang install-browser`; one run without installing: `npx designlang <url>`. As a Claude Code plugin: `/plugin marketplace add Manavarya09/design-extract`, then `/plugin install designlang@designlang` | MIT (`LICENSE`; npm `designlang` 13.3.2 says the same) | `design-kit:system`'s url mode reads the page and its stylesheets without running JavaScript, so styles a script injects are missing; designlang runs the page. `craft-layer:design-research` turns either result into direction |

## Standing

**Recorded, curated by hand.** No script re-reads a licence, an install line or a signal.
`pc_scout_names` does not read this file: every name in it is foreign to this marketplace.
GitHub's licence field reports the root `LICENSE` only, so it shows rtk as Apache-2.0 and
never the engine's BUSL-1.1; read `engine/LICENSE` by hand. Recheck:

```bash
for r in rtk-ai/rtk NVIDIA/SkillSpector Manavarya09/design-extract; do
  gh api "repos/$r" --jq '.full_name + " " + .license.spdx_id'
done
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/develop/engine/LICENSE | sed -n '1p;10,25p'
```
