# Every enforcement surface, by tier

The four scripts in `CLAUDE.md` are the ones you invoke. They are **not** all the enforcement.
Named by filename and standing, per `CLAUDE.md`'s has-teeth convention:

**Blocking — fails CI.** The CI step count and its recount command live in `CLAUDE.md`, the one
count it carries. Beyond the four scripts: each harness under `scripts/smoke/` is its own named CI
step. The plugin harnesses (author-time lints) run in one shared CI step globbing
`plugins/*/scripts/__tests__/*.test.sh`, so ANY plugin shipping a harness is enforced the moment it
lands. `scripts/eval-cases.sh` (`CLAUDE.md` § Evals) and `scripts/mod-tests.sh` are steps of
their own. The host's own validator, `claude plugin validate --strict` over
every plugin and the marketplace manifest, runs through `scripts/official-validate.sh` with its
pinned CLI version asserted. It catches manifest SCHEMA errors and hooks.json, `.mcp.json`,
install-name and component-path faults `validate.sh` never models, and fails a mod gating hook
with no `.catch`. It checks nothing about SKILL.md frontmatter; its header lists each and says
why. **Do not record the count here**; recount:

```bash
grep -c 'run: bash scripts/smoke/' .github/workflows/validate.yml   # smoke steps
ls plugins/*/scripts/__tests__/*.test.sh | wc -l                    # plugin harnesses
bash scripts/gate-coverage.sh   # which author-time checks a harness exercises
```

`scripts/smoke/canary.sh` is deliberately NOT a CI step: its own header says it needs a live
model; it stays a local authoring harness. `CLAUDE.md` states the opt-in rule every live-model
script under `scripts/smoke/` follows. CI can still be red after a green local four-script pass:
several of those harnesses assert **exact gate message strings**, so rewording a gate's error
breaks CI even when the gate itself still works.

**Warn-only in CI.** `scripts/check-doc-staleness.sh` — its step carries `continue-on-error: true`
and the script `exit 0`s on every path by contract. It reports; it never fails anything. Age is
its only default signal. `--live` compares the stamp's `npm:<pkg>@<major>[.<minor>]` tail against
npm and HEADs the URL; `--inventory` prints one row per stamp. The re-read no script can do is the
`digest-refresh` project skill, `.claude/skills/digest-refresh/SKILL.md` — invoke it when a row
warns or a user asks whether something is stale. `scripts/host-constants.sh --check` (step "host
listing constants (warn-only)") re-reads the four skill-listing constants from the pinned CLI binary; without that build, the CI norm, it WARN-skips.

**Blocking — fails the turn.** `scripts/done-gate.sh`, a `Stop` hook wired in
`.claude/settings.json`. A Stop hook can reach the model two ways — stdout
`{"decision":"block","reason":…}` with exit 0, or exit 2 with a reason on stderr. This one uses
exit 2, printing that JSON blob to stderr, so the model receives it as raw prose.

**Advisory — never blocks.** `scripts/authoring-guard.sh`, a `PostToolUse` hook on every
`Edit`/`Write`, fail-open by its own declaration (`:2-3`). It warns; it cannot stop anything.
Counting it as enforcement is the tier over-claim `CLAUDE.md`'s has-teeth convention forbids.

**Maintainer path, not a gate.** `scripts/turn-cost.sh` — the only instrument here that meters
something other than bytes: **turn blocks**, one human instruction and the model requests it took.
Always exits 0; withholds any per-plugin ratio below `--min-blocks`; prints its own attribution
coverage and its blind spots (subagent turns are invisible and are billed). **`--skills` is the
retirement queue** — it absorbed `scripts/retirement-queue.sh`. The mode joins shipped skills
against the router ledger, the hindsight ledger AND transcript `attributionSkill` records, and
names which sources had data. It keeps the original doctrine: zero proves nobody used it HERE, and
non-zero proves it fired and not that it helped. It says where a with/without (control-arm) comparison is worth spending
— nothing more. Why this channel and not the byte ones, and what it measured:
`rationale/2026-08-31-token-cost-review.md`. Cite it; do not restate its numbers here.
**`--workflow`** counts, per turn block of one project's transcripts (default: this repo's), the
questions, subagents, Stop-check blocks, suite runs and browser calls it set off. It joins subagent
transcripts the cost report cannot see. Its siblings `scripts/comment-stats.sh` and
`scripts/readability.sh` count comment share and sentence length. All three exit 0; their before
values are in `rationale/improvement-plan-2026-10-26.md`. The unrouted count is not recorded here —
recount:

```bash
python3 -c "import glob,os;s={os.path.basename(os.path.dirname(p)) for p in glob.glob('plugins/*/skills/*/SKILL.md')};r=open('plugins/skill-router/rules.tsv').read();print(sum(1 for x in s if f'\t{x}\t' not in r),'of',len(s),'unrouted')"
```

**Maintainer path, not a gate.** `scripts/remove-plugin.sh` — the sanctioned plugin-removal
script; dry-run by default, edits with `--apply`. It deletes the plugin's dir, marketplace entry
and README table row, rewrites the README leaf counts `validate.sh` checks, strips the plugin's key
from all three context-budget baselines and regenerates the scout catalog. It also appends a
`scripts/removed-plugins.tsv` row (prose_match `no`) and a `renames` entry. The entry names a
successor only under `--merge-into` when the host adds no blocking hook, else `null`;
`pc_renames_ledger` fails the build when the two disagree. It has no bundle branches: no plugin
may declare `dependencies`. Prose that names the removed plugin is its residual report, not an
edit — a person rewrites it.
