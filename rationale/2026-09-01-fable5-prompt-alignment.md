# Fable 5 system-prompt alignment review, 2026-09-01

**Standing: `recorded`.** Nothing reads this file back. It is a review, not a gate.
Every finding names the file and line it rests on, on both sides.

## Provenance — read this before acting on anything below

Three documents from `github.com/asgeirtj/system_prompts_leaks`, fetched
2026-09-01, all third-party transcriptions Anthropic has not published or
confirmed:

| file | lines | surface |
|---|---|---|
| `Anthropic/claude-fable-5.md` | 7,706 | claude.ai consumer chat |
| `Anthropic/claude-code/claude-code-desktop-fable-5.md` | 7,192 | Claude Code **desktop app** |
| `Anthropic/claude-code/claude-code-fable-5.md` | 6,329 | Claude Code **CLI** |

They are **evidence, not spec**. A leak can be stale, partial, or wrong, and one
of these demonstrably is: the consumer prompt's `product_information` names the
current models as "Claude Fable 5, Claude Opus 4.8, Claude Sonnet 4.6, Claude
Haiku 4.5", while the live CLI environment block in this very session names
"Opus 5: `claude-opus-5`, Sonnet 5: `claude-sonnet-5`". **Do not sync repo model
facts to the leak** — `llm-app` already routes model facts to the `claude-api`
skill (`plugins/llm-app/skills/llm-app/SKILL.md`, Defer rule), which is the
correct handling and needs no change.

The three surfaces also differ from each other, which is the single most useful
thing in the whole exercise: **a plugin ships to all three, so a rule that reads
as universal may only hold on one.** Findings below name the surface.

## What the review covered

62 plugins, 116 skills, 32 agents, 86 commands. Cross-read against the three
prompts for three question kinds: does a plugin now contradict the host; does a
plugin now duplicate something the host ships (the admission law); and does a
plugin describe harness behaviour that has since changed.

---

## Finding 1 — `terse` at `ultra` prescribes exactly what the desktop prompt bans

**Severity: high. Surface: desktop only.**

`plugins/terse/skills/terse-output/SKILL.md:71-74` instructs:

> drop articles and filler at **full**; add abbreviation of common prose nouns
> (DB, auth, config, req/res, fn, impl) and causal arrows (X → Y) at **ultra**.

`claude-code-desktop-fable-5.md:27`, "Communicating with the user":

> The way to keep output short is to be selective about what you include (drop
> details that don't change what the reader would do next), **not to compress the
> writing into fragments, abbreviations, arrow chains like `A → B → fails`, or
> jargon**. What you do include, write in complete sentences with the technical
> terms spelled out.

These are opposite instructions about the same three devices — fragments,
abbreviations, arrow chains. The paragraph is **absent from the CLI prompt**
(grep for "arrow chain" hits `cc-desktop` only), so terse is uncontradicted in
the terminal and contradicted in the desktop app.

Note what is *not* in conflict: terse's shape layer — line budgets, the work-done
skeleton, the cut list, the "quiet loss" anti-pattern — is the same argument the
host makes ("be selective about what you include"). Only the **word layer** at
`full`/`ultra` collides.

**Recommended fix.** Keep the shape contract; make the word layer surface-aware.
`ultra`'s arrows-and-abbreviations paragraph should carry a one-line exception:
on the desktop surface, hold `lite` word rules (full sentences) and take the
compression out of the shape budget instead. This is cheaper than dropping
`ultra` and it is the honest reading — the host is not banning brevity, it is
banning telegraphese.

## Finding 2 — `git-workflow:worktree-isolation` places worktrees where the native tool does not, and never mentions the native tool

**Severity: high. Surface: all three.**

`plugins/git-workflow/skills/worktree-isolation/SKILL.md:22-27` ranks three
placements: an existing project convention, `../<repo>-worktrees/<branch>`, then
`.worktrees/<branch>` if proven gitignored. It describes creating them with
`git worktree add`.

The harness now ships `EnterWorktree` / `ExitWorktree`
(`cc-cli-fable-5.md:1253-1300`), which "creates a new git worktree **inside
`.claude/worktrees/`**", switches the session into it, and prompts the user to
keep or remove it at session exit. The `Agent` tool additionally takes
`isolation: "worktree"` to give a subagent its own worktree, auto-cleaned if
unchanged.

Three consequences:

1. **The skill's placement advice is now a fourth convention** competing with the
   host's. A user who says "use a worktree" gets `.claude/worktrees/` from the
   tool and `../repo-worktrees/` from the skill.
2. **This repo already disagrees with itself.**
   `plugins/task-runner/skills/track-orchestration/SKILL.md:131` states
   "Worktrees live under `.claude/worktrees/`" — matching the host, contradicting
   the sibling skill.
3. **A real collision risk.** `ExitWorktree`'s session-exit keep/remove prompt and
   track-orchestration's "preserve every track branch and worktree until the final
   gate is green" (`:117-119`) both claim `.claude/worktrees/`. track-orchestration
   guards its own namespace (`:131-133` — foreign worktrees and other runs' worktrees are untouched), but the
   guard is one-directional — it stops the plugin touching the host's, not the
   host prompting a user to remove a live track worktree mid-run.

**Recommended fix.** worktree-isolation adopts `.claude/worktrees/` as rung 1 and
names `EnterWorktree` as the mechanism, keeping the sibling-directory rung only
for the outside-a-repo and multi-repo cases. track-orchestration adds one line on
the exit-prompt interaction. Both are documentation-only.

## Finding 3 — `design-preview` runs dev servers via Bash; the desktop harness says never to

**Severity: medium. Surface: desktop only.**

`plugins/design-preview/README.md:63-73` centres a shared static server on
`${PREVIEW_PORT:-8123}`, preferring taskmaster's `assets/serve.py` and falling
back to `python3 -m http.server --bind 127.0.0.1`, `php -S`, or `npx serve`.

`cc-desktop-fable-5.md:3421` (`mcp__Claude_Browser__preview_start`):

> Start a dev server by name from `.claude/launch.json`. … Reuses the server if
> already running. **ALWAYS use this instead of Bash for running servers.**

The desktop tool also reads `.claude/launch.json`, which the plugin does not
write, and opens the Browser pane — so on desktop the plugin's localhost URL is
reachable but the user has to find it themselves, and the "always" rule is broken
by every rung of the ladder.

**Recommended fix.** Add a surface rung above the current ones: when
`mcp__Claude_Browser__preview_*` is available, register the port in
`.claude/launch.json` and start through `preview_start`; the Bash ladder stays as
the CLI path. This is additive — no existing rung is removed.

## Finding 4 — the marketplace has no awareness of `ReportFindings`

**Severity: medium. Surface: all three.**

`grep -rl ReportFindings plugins/` returns **zero files**. Every review surface in
this marketplace emits prose: `plugins/code-review/commands/review.md:59` fixes
the format as `path:line — severity — problem — fix`, and the marketplace-wide
severity scale is built on it.

The harness ships a `ReportFindings` tool that takes a typed findings array
(`file`, `line`, `summary`, `failure_scenario`, `category`, `verdict`,
`short_summary`, `outcome`) and renders it in the host UI. Its own description
says to use it only when the active code-review instructions say to — so this is
not a defect, it is an unclaimed surface: a marketplace review command **can** be
the instructions that ask for it.

**Recommended fix, small and testable.** One reviewer (start with
`/code-review:review`) gains an opt-in clause: when `ReportFindings` is available,
emit findings through it *in addition to* the prose line, mapping the existing
four severities onto `category` + `verdict`. Do not convert the fan-in wholesale
until one command has run both ways — the prose format is what the stack fan-in
merges on, and breaking it breaks eight plugins at once.

## Finding 5 — `claude-authoring` teaches a model ladder that is missing its top rung

**Severity: medium. Surface: all three.**

`plugins/claude-authoring/skills/authoring-agents/SKILL.md:43-56` enumerates the
model tiers an agent may pin: `opus`, `sonnet`, `haiku`, and `inherit`. **`fable`
is absent.**

It is a valid value everywhere else:

- the `Agent` tool's `model` enum is `["sonnet","opus","haiku","fable"]`
  (`cc-cli-fable-5.md`, Agent schema);
- `scripts/validate.sh:839,885` accepts `haiku|sonnet|opus|fable`;
- `plugins/orchestration/.../role-floors.md` builds its whole formula on the
  ladder `haiku < sonnet < opus < fable`, and its first worked row is
  "unboosted, fable session, `code-reviewer` → fable — **fixed**".

So the repo's floor arithmetic knows about Fable and the authoring skill that
teaches people to write agents does not. Zero of 32 plugin agents pin `fable`
(`grep -h '^model:' plugins/*/agents/*.md`: 20 inherit, 6 opus, 5 sonnet, 1
haiku) — which is defensible as a default, but no author reading the skill would
know the rung exists.

**Recommended fix.** Add the `fable` row to the tier list with its actual
criterion (adversarial and wrong-answer-expensive judgment where an opus pin
would cap a stronger session), and cross-reference role-floors so the ceiling-vs-
floor trap is stated once. `plugins/claude-authoring/skills/authoring-skills/references/model-tier-scoping.md`
already reasons in Fable terms — the two files should agree.

## Finding 6 — `hindsight` files its output only to CLAUDE.md; the harness now has a typed home for it

**Severity: low-medium. Surface: all three.**

`hindsight:harvest` mines past transcripts for friction and "proposes CLAUDE.md
rules and skill ideas on explicit approval".

Both Claude Code prompts describe a per-project file memory at
`~/.claude/projects/<slug>/memory/`, one fact per file, with a `metadata.type` of
`user | feedback | project | reference`, where **`feedback`** is defined as
"guidance the user has given on how you should work, both corrections and
confirmed approaches; include the why" — which is precisely what a harvest
produces. The prompt also constrains it usefully: "Don't save what the repo
already records (code structure, past fixes, git history, CLAUDE.md)".

**Recommended fix.** harvest's approval step offers two destinations rather than
one: a CLAUDE.md rule when it binds the *repo* and should be reviewed in a PR, or
a `feedback` memory when it binds *how the user wants to be worked with* and
should not. The distinction is real and the plugin currently collapses it.

## Finding 7 — `brain` earns its existence, and should say so

**Severity: low (documentation). Surface: all three.**

Worth recording because the opposite conclusion looks plausible. `brain` builds a
committed `brain/INDEX.md` + `brain/<area>.md` codebase map; the harness now has
its own per-project memory. They do not overlap, and the host prompt says why in
its own words: memory is for facts about the user and the work, and "**Don't save
what the repo already records (code structure, …)**". Code structure is exactly
and only what `brain` stores, in the repo, committed, reviewable.

That is a clean admission-law answer and `plugins/brain/README.md` does not
currently make it. One sentence would inoculate the plugin against the next
reader who asks whether native memory replaced it.

## Finding 8 — `llm-app`'s description promises a section its body does not carry

**Severity: low. Surface: n/a (internal).**

`plugins/llm-app/skills/llm-app/SKILL.md:3` advertises "context-window
management". The body has no such section; the nearest is "Cost and latency",
which covers capping `max_tokens` and trimming context for cost, not window
management (chunk-vs-window budgeting, conversation compaction, what to evict).
Found while checking the plugin for stale model IDs — it has none, and its defer
rule to `claude-api` is exactly right.

**Recommended fix.** Either add the section or drop the phrase from the
description. Description drift is the failure mode the router is most sensitive
to.

---

## What was checked and found clean

Recorded so the next reviewer does not re-derive it:

- **No stale model IDs in any plugin.** The only `claude-*` strings in `plugins/`
  are two fixture literals in `plugins/candor/scripts/__tests__/install.test.sh`;
  the priced table in `scripts/turn-cost.sh:120-124` already carries
  `claude-fable-5` and `claude-mythos-5`.
- **`candor:straight-talk` and the host's `responding_to_mistakes_and_criticism`
  agree** (own the mistake, no self-abasement, no apology spiral, don't become
  submissive under pressure). candor is strictly the more specific artifact — it
  adds evidence-before-claim ordering and two Stop-hook gates the host has no
  equivalent for.
- **`comment-discipline` and the desktop prompt's comment rule agree**
  ("Only write a code comment to state a constraint the code itself can't show").
  The plugin's routing table is the finer instrument; it is not made redundant.
- **`task-runner:track-orchestration` already uses `.claude/worktrees/`**, ahead
  of its sibling skill (see Finding 2).
- **`plugin-scout` is not displaced** by the consumer prompt's
  `search_plugins`/`suggest_plugin_install` catalog flow — those tools exist on
  the claude.ai surface only and address an org catalog, not this marketplace.
  Its "at most one suggestion card per conversation" discipline is nonetheless a
  good pattern to borrow for `--yes`-less runs.
- **`code-review`'s boundary against the built-in `simplify`** is already stated
  (`plugins/code-review/skills/code-smells/SKILL.md:6`). No equivalent boundary is
  stated against the built-in `/code-review` skill, which is the larger overlap
  and shares a name; worth a sentence, but the deliverables genuinely differ (ours
  fans in eight stack reviews, the built-in has ultra/`--comment`/`--fix`).

## Outcome — every finding applied, same day

All eight were fixed on branch `fable5-prompt-alignment`. Nothing was deferred.
What changed, by finding:

| # | Plugin | Change | Version |
|---|---|---|---|
| 1 | `terse` | `terse-output` gains a surface exception: where the host bans telegraphese, every level holds `lite` word rules. Shape budgets untouched. | 0.3.9 → 0.4.0 |
| 2 | `git-workflow` | `worktree-isolation` leads with `EnterWorktree` / `ExitWorktree` and makes `.claude/worktrees/` rung 1; new anti-pattern for hand-rolling beside the harness. | 0.3.2 → 0.4.0 |
| 2 | `task-runner` | `track-orchestration` names the harness as a second owner of that root and requires live track worktrees in the halt report. | 0.30.1 → 0.31.0 |
| 3 | `design-preview` | A `preview_start` / `.claude/launch.json` rung above the Bash ladder, on both README and `real-preview`. | 0.4.2 → 0.5.0 |
| 4 | `code-review` | `/code-review:review` emits through `ReportFindings` when present, prose unchanged; plus a stated boundary against the built-in `/code-review`. | 0.12.6 → 0.13.0 |
| 5 | `claude-authoring` | `authoring-agents` documents the `fable` rung and why `inherit` stays the default. | 0.12.5 → 0.13.0 |
| 6 | `hindsight` | Harvest rules now route to two homes — CLAUDE.md for repo-binding rules, a `feedback` memory for user-binding ones. | 0.5.6 → 0.6.0 |
| 7 | `brain` | A boundary section against native memory, with the split as a table. | 0.3.4 → 0.3.5 |
| 8 | `llm-app` | A real "Context-window management" section, so the description stops promising what the body lacked. | 0.1.6 → 0.2.0 |

Three baseline numbers moved, each hand-verified rather than accepted from the
tool: `terse` activated 1891 → 1970 (measured), `always-on-suite` activated
2715 → 2802, and `process-suite` activated 2013 → 2020 (hand-applied: the +7 is
hindsight's description growth, and the activated surface is a superset of
always-on, so the delta must track). Plus `hindsight` 121 → 128,
`always-on-suite` 1641 → 1648, `process-suite` 1981 → 1988 on the always-on
channel.

**The suite number took two attempts, and the miss is the instructive part.** The
first value committed for `always-on-suite` activated was 2770 — measured on this
machine, and wrong. CI measured 2802 and failed the gate. The arithmetic settles
which is right without appealing to either environment: the prior baseline was
2715, hindsight's description grew 7 tokens and terse's hook-read contract grew
80, and 2715 + 7 + 80 = 2802 exactly. The local run under-measured a BUNDLE by 32
while measuring each of its member plugins correctly — so "the members all read
delta 0" is not evidence the suite total is right. Cross-check a bundle's
activated number against the sum of what changed inside it, not against the
tool's own output.

One further fix rode along, found by a question this review prompted rather than by
the review itself: `plugin-scout`'s Preflight built its installed set from
`claude plugin list` unioned with the two PROJECT settings files, so an
`enabledPlugins` entry hand-written into `~/.claude/settings.json` was seen by
neither half and the plugin was offered as though missing. The union now reads that
file too (`plugin-scout` 0.13.0 → 0.13.1). Kept line-neutral deliberately: that
SKILL body is at 196 lines and `skill-crowding-baseline.json` holds
`within_3_of_line_cap` at 0, so 198 lines fails the build.

**A blanket `--update-baseline` was run and its output rejected.** It deleted six
entries from the activated baseline and zeroed twelve in the dynamic one, because
this machine cannot create the state those hooks wait for — the exact failure
`CLAUDE.md` records against commit `5192047a`. Both files were restored from git
and the three real deltas applied by hand. Anyone re-running that command in a
sandbox will reproduce the damage; the warning in `CLAUDE.md` is not theoretical.

## What this review did NOT check

Honest limitation, per the house convention:

- No plugin was **run**. Every finding is a read of two texts against each other.
- The three leaked prompts were compared for the sections this marketplace
  touches. The tool-schema bulk (Gmail, Calendar, Drive, computer-use, ~4,000
  lines of the desktop file) was skimmed for tool names only.
- **Surface attribution is inferred from three files.** "Desktop only" means the
  paragraph appears in the desktop file and not the CLI file as transcribed. A
  fourth surface (web, IDE extension) was not available and is not accounted for.
- No gate enforces anything here. Every fix above is a documentation edit; none
  has been made.
