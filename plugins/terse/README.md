# terse

Brevity modes usually compress **words**. That is the layer that already works.
Measured across three long real sessions running a word-compression mode at its
strongest setting, mid-turn progress lines held at 17–265 characters while every
turn-final message ran 1,194–4,447. Scored against a 12-line ceiling those
sessions land at mean 27.1 / 25.6 / 25.7 prose lines, with 100% / 81% / 100% of
turn-final messages over. Short sentences, hundreds of them.

What grows is **shape**: the last message of a turn narrates its own process,
re-summarizes the files it just wrote, re-prints an unchanged inventory, and frames
every fact before stating it. So this plugin budgets and shapes the message instead
of shortening its sentences.

**The one law: fewer words in the message, never less work in the turn.** Code,
commits, files written to disk, prompts handed to subagents, tool calls, tests and
verification depth are all out of scope at every level. Compression deletes
restatement, never findings — a finding that does not fit goes into a file and gets
cited by path.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install terse@cc-plugins-marketplace
```

Installed, it does nothing until switched on. There is no ambient mode.

**Running another brevity mode?** Remove it first. A second always-on compression
plugin (caveman and its `/caveman-*` skills are the common case) injects competing
word rules on the same prompts, and its skill descriptions collide with all four of
this plugin's — the dispatcher can fire either. They are not designed to coexist.

## Usage

Turn it on. The level persists across every session on this machine until you
change it — set it once, not once per session:

```bash
/terse:level full      # the default working level
/terse:level ultra     # answers in 3 prose lines, reports in 6
/terse:level off       # normal length resumes
/terse:level status    # what is active, and where it came from
```

From the next message on, replies follow the budgets below. Nothing else changes:
the same tool calls run, the same tests run, files are written at full length.

Check whether it is actually working — the plugin measures itself rather than
asking you to trust it:

```bash
/terse:check                 # this session, last 10 turn-final messages vs budget
/terse:check --tokens        # plus real token usage from the transcript
/terse:check --all --since 7d   # every session in this project, last 7 days
```

A typical read: `mean 27.1, max 36, over ceiling 7 (100%)` — that is a session
with the mode off, every closing message over budget. Under `full` the mean should
sit below 12; the max tells you whether one report ran long or the whole session
drifted, and `--last` shows which messages.

The rest is on demand, and none of it needs the mode to be on:

```bash
/terse:commit                # message from the staged diff, full English
/terse:compress CLAUDE.md    # shrink one prose file, with backup + verification
/terse:help                  # the reference card
```

Delegating work? Ask for a crew agent by name when you want the finding rather
than the reasoning: "use terse-investigator to find every caller of `resolveUser`".

Two things worth knowing early:

- **It never trades work for brevity.** If a reply cannot hold every finding, the
  findings go into a file and the message cites the path. Report a gap and it
  must say so under `Skipped:`, which prints `none` when there is nothing.
- **Turning it off is one command** — `/terse:level off`, or in plain words "stop
  being terse", "be more verbose", "back to normal length". `CC_TERSE=off` overrides
  everything for a single headless run. Uninstalling leaves one file behind:
  `~/.claude/terse-mode` — `/terse:level off` removes it.

## Commands

| Command | What it does |
|---------|--------------|
| `/terse:level [lite\|full\|ultra\|wenyan-*\|off\|status]` | Set or report the level; the hook writes it, machine-local, persists across sessions |
| `/terse:check [--last N] [--tokens] [--all] [--since Nd] [--session-file PATH]` | Measure turn-final messages against the active budget — one session or every session in the project. Report-only |
| `/terse:commit [--amend | extra context]` | Conventional Commits message from the staged diff — full English, no noise |
| `/terse:compress <file>` | Compress one named prose markdown file in place, with a backup and five mechanical checks |
| `/terse:help` | The reference card |

## Budgets

Prose lines only; code blocks, tables and trees are free. A prose line is ~100
rendered characters, so one long paragraph spends several — counting source lines
instead is how a 2,700-character message scores as "11 lines, fine".

| Turn kind | lite | full | ultra |
|---|---|---|---|
| progress, mid-turn | 1 | 1 | 1 |
| answer or explanation | 10 | 6 | 3 |
| work-done report | 18 | 12 | 6 |

Work-done reports take one skeleton every time: verdict → artifact table → at most
5 findings as `path:line — problem → impact` → **skipped** (printed as `none` when
nothing was) → blocker → next. A gap hides better than a finding: an unseen finding
looks like no finding, but an unrun check looks like a passed one.

The 5-finding cap does **not** apply when findings are the deliverable: a review,
audit or scan you invoked returns all of them, in that command's own format.
Truncating a report-only command's output into a file is data loss with a budget
for an excuse.

`wenyan-lite` / `wenyan-full` / `wenyan-ultra` keep those budgets and swap the word
layer for classical Chinese — `skills/terse-output/references/wenyan.md`. Verdicts
and gate acknowledgements stay in English there, because two Stop hooks in this
marketplace grep the assistant's own words for `fail` / `blocked` / `done`.

## Crew — compressed-return subagents

| Agent | Returns |
|---|---|
| `terse-investigator` | `path:line — \`symbol\` — note` rows, or `No match.` |
| `terse-builder` | A receipt for an edit of ≤2 already-decided files, with what it ran and what it left |
| `terse-reviewer` | `path:line: severity: problem. fix.`, sorted bug → risk → nit → q |

They exist because a subagent's return lands in the caller's context verbatim. They
are format twins, not better analysts: `Explore`, `task-runner:task-executor` and
`code-review:code-reviewer` are the right calls when you want the reasoning rather
than the finding. Routing lives in the `terse-crew` skill; the doctrine behind it is
`orchestration:delegation-contracts`.

## Hooks

**`SessionStart` — `activate.sh`.** Silent unless a level is set. Extracts the
contract from the marked block in `skills/terse-output/SKILL.md` at runtime, via
`${CLAUDE_PLUGIN_ROOT}`, so the injected card and the skill body cannot drift and no
path guessing is involved. ~775 tokens, once, only when a level is on. Needs no `jq`.

**`UserPromptSubmit` — `mode.sh`.** Owns the level switch, and while a level is
active re-injects one compact line carrying the *budgets and the report skeleton* —
not the word rules, which were never the part that drifted. ~120 input tokens per
prompt while on, nothing when off. Fails open and silent without `jq`.

`CC_TERSE=off|lite|full|ultra|wenyan-*` overrides the state file, for headless runs
— including over `/terse:level off`, which says so when both are set.

This is **not** a `CC_REMIND` reminder hook. That variable silences the marketplace's
advisory nudges and the one-nudge-per-prompt marker they share; a user-selected mode
is not a nudge, so it neither claims that marker nor answers to that switch. Its off
switches are the level itself and `CC_TERSE=off`.

Always-on cost of the plugin itself: **886 tokens** of command, skill and agent
descriptions, paid every session whether the mode is on or off — the price of the
full command set, and `everything` bundle users pay it by default.

## Optional, wire them yourself

**Statusline badge** — `scripts/statusline.sh` (or `statusline.ps1` on Windows)
renders `[TERSE:ULTRA]`. Add it to `statusLine` in your settings if you want it;
no hook will offer to edit settings for you.

```jsonc
"statusLine": { "type": "command",
                "command": "bash <plugin-root>/scripts/statusline.sh" }
```

**MCP catalog shrinker** — `scripts/shrink.mjs` is a stdio proxy that trims prose
out of an MCP server's tool descriptions before they reach the model, leaving names,
schemas and every request untouched. Point a server's command at it:

```jsonc
{ "command": "node",
  "args": ["<plugin-root>/scripts/shrink.mjs", "npx", "-y", "@some/mcp-server"] }
```

On a typical verbose description it cuts ~36% conservatively; `TERSE_SHRINK_AGGRESSIVE=1`
also drops articles, which saves a few points more and is likelier to affect which
tool the model picks. Forwards any line it cannot parse untouched.

## What has teeth

| Rule | Standing |
|---|---|
| Level switching | mechanical — `hooks/mode.sh` writes the state file; the model is not asked to remember |
| The shape contract | **unenforceable** at write time; nothing can rewrite a message after it is emitted. Reinforced per turn, measured after the fact |
| Scope guard (no less work) | **unenforceable** — no script can measure thinking that did not happen. Stated in every injection because that is the only lever available |
| Budget compliance | **recorded** — `/terse:check` reports it on demand; nothing reads it back automatically |
| `/terse:compress` safety | **agent-graded**, plus five mechanical checks (identifiers/URLs, heading count, fenced blocks, numbers, size) the skill requires before reporting |
| Commit format | **unenforceable** here — a project's own `commitlint` or hook outranks it |

## Deliberately not here

This plugin was built to replace a word-compression mode wholesale, so the gaps
are choices, not oversights:

| Not ported | Why |
|---|---|
| Cross-IDE bootstrap (`init` writing rule files for Cursor, Windsurf, Cline, Copilot, AGENTS.md) | How terse you want your own terminal is a user preference, not repo policy. This plugin never writes into your project |
| Codex / Gemini / opencode / Roo / Junie / Kiro packaging | This is a Claude Code marketplace; `/plugin install` is the distribution |
| Standalone `install.sh` / `uninstall.sh` | Same reason. Removal is `/terse:level off` then `/plugin uninstall` |
| "Tokens saved" and USD estimates | Savings need the same session run without the mode, which does not exist, and a hardcoded price table is stale the week a tier changes. `/terse:check` reports measured tokens and measured line counts only |
| Default-on after install | An installed plugin that silently reshapes every reply is a plugin nobody consented to. Default is off |
| A Python eval/benchmark harness for compression quality | `/terse:check` measures real sessions instead of fixed prompts |

## Not the verbosity hook

`comment-discipline` ships a warn-only hook measuring characters of assistant text
per tool call, cumulatively, once per session, while work happens. This measures
prose lines per turn-final message against a user-selected budget, on demand. Its
header argues that a rule saying "be concise" more loudly is rule N+1 and loses —
correct, and the reason this plugin is a requested mode with numbers and a skeleton
rather than another ambient instruction to be brief.
