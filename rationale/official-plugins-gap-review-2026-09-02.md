# Official plugins gap review — 2026-09-02

What `anthropics/claude-plugins-official` ships that a development session needs,
which of it is vendor-agnostic, what this marketplace already covers, and what was
done about the rest. Source: a shallow clone of the directory on 2026-09-02 —
291 marketplace entries, 39 first-party under `plugins/`, 15 partner plugins under
`external_plugins/`, the remainder hosted vendor integrations declared inline.

## The prompt this answers, restated

"Scan the official directory, list the must-have vendor-agnostic development
plugins, compare against this marketplace, decide what is needed, and do it." The
restated version that was actually executed:

1. Classify every first-party plugin (and the five open-source partner MCP
   wrappers) by **mechanism**, not by description — hook events, stop gates,
   scoring, loops, LSP registration — because this repo has measured that
   prose-only plugins score zero (`eval-ablation-2026-08-20.md`) and that the
   necessity question is about mechanisms (`marketplace-necessity-review-2026-08-26.md`).
2. **Vendor-agnostic** means usable without an account at one SaaS vendor.
   Language servers, open-source MCP servers and Claude-Code-native mechanisms
   pass; Datadog, Linear, Stripe, cloud providers and the like do not.
3. For each pass, ask: does a plugin here carry the same mechanism? If yes, it is
   an overlap to warn about, not a gap. If no, it is a gap — and the fix is to
   **route to the official plugin, not reimplement it**, per the admission law
   (an artifact earns existence by carrying a rule nothing else carries).

## Must-have, vendor-agnostic, and not carried here

| Official | Mechanism | Nearest here | Verdict |
|---|---|---|---|
| `security-guidance` | ~25 regex rules on Edit/Write; Stop-hook LLM review of the accumulated diff; commit-time cross-file reviewer on `git commit`/`push`, all async with re-wake | `security` PostToolUse warn; `secret-scanning` PreToolUse block; no Stop review, no commit reviewer | gap — route |
| `hookify` | four generic Python hooks reading `.claude/hookify.*.local.md` rule files (regex/conditions, warn/block, live reload); transcript analyzer proposes rules | `claude-authoring:new-hook` scaffolds one script per hook | gap — route |
| `commit-commands` | `/commit` with git state preloaded via `!` substitution and an `allowed-tools` lock; `/clean_gone` | `terse:commit` drafts only; `git-workflow:finish` PRs at branch end | gap — route |
| `claude-code-setup` | read-only scan recommending hooks, MCP, subagents, skills | `plugin-scout` recommends plugins only | gap — route |
| `claude-md-management` | six-criterion CLAUDE.md audit with per-file grade; session-mining revise command | `hindsight` mines transcripts with a recurrence gate; no audit | half gap — route |
| `pr-review-toolkit` | six standalone agents; `silent-failure-hunter` and `type-design-analyzer` are unique | `code-review`, `resilience:error-review` cover the other four | partial — route the two agents, name the overlap |
| `code-simplifier` | opus agent rewriting session-touched code, behaviour fixed | `low-cognitive-load` doctrine | gap — route, JS-shaped caveat |
| `*-lsp` (13) | `lspServers` block in the marketplace entry; zero prose | none | gap — route by manifest |
| `playwright` (Microsoft) | stdio browser MCP | `testing` doctrine only | gap — route by dep |
| `serena` (OSS) | LSP-backed semantic MCP | `brain` grep-built map | complementary — route |
| `context7` (Upstash-hosted) | remote docs MCP | `api-docs-first` asks for a source, ships none | gap — route, flagged hosted |
| `ralph-loop` | Stop hook re-feeds one prompt until `<promise>` literal; session-scoped state file | `task-runner` bounds loops by design | doctrine conflict — opt-in only |
| `claude-security` | inventory → researcher → independent verifiers that must disprove; SARIF; patches in a scratch clone | `security:review` self-refutes `critical` only | heavier pass — opt-in |
| `mcp-server-dev`, `agent-sdk-dev` | build guidance / scaffold + verifier agents | `llm-app` is provider-agnostic app discipline | gap — route by dep |
| `session-report` | transcript analyzer → HTML | `scripts/turn-cost.sh` (maintainer) | opt-in |

## Overlaps — not gaps

- `feature-dev` — same arc as `taskmaster` + `task-runner` + `code-architecture`.
- `frontend-design` — same intent as `craft-layer`; the merge was already killed on
  evidence (`marketplace-necessity-review-2026-08-26.md` §8d). Two design doctrines
  in one session contradict on layout defaults.
- official `code-review` — GitHub-only via `gh`; ours reviews the local diff. Same
  name in the skill listing.
- `plugin-dev` vs `claude-authoring`; `playground` vs `design-lab` /
  `visual-decisions`; `skill-creator` is now a built-in; the two output styles are
  orthogonal to `terse` and cost tokens every turn.
- `code-modernization` — a project shape, not a floor; nothing competes, nothing to route.

## What was done

`plugin-scout` 0.14.0 gains `references/official-complements.md` and a
`Beyond this marketplace` block printed once after tier 3. Rows fire under the
tier-1 evidence rule or as `core`, print their overlap sentence, and print their
install command (`claude plugin install <name>@claude-plugins-official`) without
running it; `--yes` never touches the block; the exclusions list is never suggested.

Why routing and not building: every gap above is a mechanism that Anthropic
maintains and that this marketplace would have to copy as prose or re-implement as
a hook. A prose copy is the shape this repo has measured at zero; a re-implemented
hook duplicates a maintained one. The marketplace already routes uncovered stacks
to `vercel-skills-scout` for the same reason; this extends the pattern to the
official directory.

## Standing

**Recorded.** `pc_scout_names` checks names against this marketplace and does not
read the new file. The reference carries the recount command against the live
`marketplace.json`; names were verified with it on 2026-09-02. Nothing checks that
an official plugin's mechanism is still what the table says.
