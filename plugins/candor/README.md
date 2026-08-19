# candor

Candour as a mechanism, not a pep talk.

A plugin that only said *don't hallucinate, don't flatter, don't fold under
pressure* would be the shape this marketplace has already measured at zero
(`rationale/measured-zero-shapes.md`, shape 2: canonical-doctrine checklists —
the treatment's findings were a strict subset of a blind control's). So this one
ships the two clauses that a script can actually prove, and is explicit that the
rest is measured and not enforced.

## What blocks

`hooks/gate.sh`, a `Stop` hook. Two clauses, both decidable:

| Clause | Fires when | Escape |
| --- | --- | --- |
| **Fabricated citation** | the final assistant message cites `path/file.ext:NNN` that resolves to no file under `cwd`, or to a line past the file's end | re-read and cite what is there, or drop the number and say you are inferring |
| **Unevidenced reversal** | the last user message is challenge-shaped pushback carrying no correction of its own, the final message retracts, and no tool ran in between | re-check and report what it showed, or hold the position and say why |

Both judge the **final assistant message only**. The sibling gate in
`code-architecture` documents a measured window-bleed defect from matching a
claim and its escape over a rolling 30-line window in both directions; a
single-message window cannot bleed, at the cost of missing a retraction split
across two messages.

Modes: `CC_CANDOR_GATE=block` (default) `| warn` (print, never block) `| off`.
Fails open on missing `jq`, an unreadable transcript, or empty text. One block per
distinct final message, so a disagreement cannot loop.

## What is measured and not blocked

`/candor:check` runs `scripts/candor-scan.sh` over the session transcript and
prints six counts — the two gated axes plus flattery openers, apologies,
defensive phrasing and emotional intensifiers. It always exits 0.

The four extra axes are deliberately ungated. No regex separates "you're right"
said because it is true from the same words said to please, once the evidence
question is already answered — and a gate that cannot tell them apart trains the
model to drop the phrase rather than the behaviour. Standing: **recorded**.

## The skill

`straight-talk` fires when a claim is challenged or about to be reversed, or when
an honest read of the user's own work is asked for. Its body is six **orderings**,
not sentiments: evidence before claim; the disagreement before the concession; a
reversal treated as a finding that needs its own evidence; "I don't know" shipped
with the command that would settle it; scope honesty stated when decided rather
than in a footnote; correction without performance. It carries its own standing
table naming which of the six have teeth (two) and which do not (four).

## What this does not carry

Stated because a gate reads stronger than it is:

- **Only `file:line` is checked, never a bare path.** A bare path is routinely a
  file the turn proposes to create. An invented API name, package, flag or
  function is not caught by anything here — only an invented *location* is.
- **Any tool call counts as re-checking.** A `git status` satisfies clause 2. The
  gate proves something ran, not that the right thing ran.
- **Pushback detection is a regex over one message.** Phrasing outside the list
  is invisible, and a user message carrying its own evidence — a path, a quoted
  snippet, a long argument — disarms clause 2 on purpose. Agreeing with a
  correction that arrived with evidence is reading, not sycophancy.
- **Completion claims belong to `code-architecture`.** Its evidence-gate blocks a
  completion claim when files were edited and nothing ran afterward. This plugin
  yields that territory in `lane.tsv` rather than duplicating it.
- **Only an invented FILENAME is caught, not a wrong directory.** Measured over
  47 real transcripts, an abbreviated path (`craft-layer/asset-sourcing/SKILL.md`
  for a file at `plugins/craft-layer/skills/asset-sourcing/SKILL.md`) is far more
  common than an invented one, so the resolver falls back to the basename and
  only a basename that exists nowhere blocks. A real filename under the wrong
  path now passes silently.
- **`/candor:check`'s citation count is backward-looking.** It resolves a whole
  session's historical citations against today's tree, so a file since edited or
  deleted reports as unresolved though the citation was true when written. The
  gate does not share this: it judges one message against the tree at that
  moment. Use `--last N` for a reading about the current session.
- **Tone is never blocked.** See above.

## Install

```
/plugin install candor@cc-plugins-marketplace
```

Also arrives with `quality-suite` and `everything`.

## Author-time checks

```bash
bash plugins/candor/scripts/__tests__/gate.test.sh        # 37 cases — the two clauses
bash plugins/candor/scripts/__tests__/candor-scan.test.sh # 16 cases — the six axes
bash plugins/candor/scripts/__tests__/install.test.sh     # 11 cases — install shape
```

All three run in CI through the shared `plugins/*/scripts/__tests__/*.test.sh`
step. `install.test.sh` is the one that carries the install shape: it copies the
plugin to a temp dir, resolves the hook by expanding `${CLAUDE_PLUGIN_ROOT}` in
`hooks/hooks.json` the way the host does, refuses a hook that resolves back into
this repository, drives it against a consumer project that is **not** a git
repository, and uses transcript entries with the full real field set. Nothing in
the other two harnesses would catch a plugin that only works in-tree.
