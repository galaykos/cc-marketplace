# design-kit hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader removed; the lines the file kept are not repeated here (the `set -e` rule stays in the file as one line above the first switch read). A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-design-kit.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/design-kit/hooks/unread-pick.sh

### Header

```text
unread-pick.sh — UserPromptSubmit: one line, only when a board pick is waiting.

WHAT IT CATCHES. The user picked an artboard on a design-kit board (the board
posted it to the server's loopback /_decision route → .design-kit/decisions.jsonl)
and then typed a prompt without telling the session. Prints ONE line naming the
board and artboard so the session reads the pick instead of asking for it — the
"session watching the board" half of the decision channel, without polling.

WHAT IT DOES NOT DO. It never blocks, never reads the prompt, and says nothing
when every row is consumed or no board exists. Turn-taking is not hand-rolled here:
it runs the marketplace's shared phase guard (templates/blocks/phase-guard.md,
inlined below) against its OWN lane.tsv row, so the phase list cannot drift from
the declaration the way a hardcoded one did — that copy read build|verify|review|ship
and spoke through `plan`, and had no TTL and no session check, so a sentinel left by
a run that died muted this channel in every later session. Off with CC_REMIND=off or
CC_DESIGN_KIT_PICK=off.
CC_REMIND / CC_DESIGN_KIT_PICK unset: the /config options cc_remind / cc_design_kit_pick decide.

WHERE IT LOOKS. The phase sentinel and .design-kit/decisions.jsonl are read at the
project root, not the payload cwd, which follows the model's `cd` (finding 2,
rationale/2026-09-25-session-plugin-usage-review.md) — so both shared blocks are
inlined below: state-root (held byte-identical to templates/blocks/state-root.md by
pc_shared_blocks) and phase-guard. dk.sh resolves its .design-kit/ with the same
state-root block, so writer and reader agree from any directory. An explicit
DESIGN_KIT_DIR elsewhere is not seen here. NO gate holds the phase-guard copy to its
block — keeping the two identical is by hand, **recorded**.

FAIL-OPEN, like every hook here: no python3, no jq, no readable sentinel, a foreign
session or a stale one all mean "proceed" or "say nothing", never an error on the
user's prompt. `set -e` is deliberately absent — an unset variable or a non-zero
probe must not take the prompt down with it.

Standing: scripts/__tests__/unread-pick.test.sh drives silent, one-line, consumed,
phase-gated, stale-sentinel, subdirectory-cwd and no-python3 cases — **gate** (CI globs every
plugins/*/scripts/__tests__/*.test.sh). Nothing proves the model ACTS on the line
(agent-graded), and nothing here proves the guard is honoured on a branch the
harness does not drive.
```

### The root's board only

```text
The root's board only. dk.sh anchors .design-kit/ at this same root (the same
cc_state_root), and `dk decision --consume` clears rows there — so a stray
<subdir>/.design-kit/ left by a dk.sh before 0.5.1 is not announced: the consume this
line tells the model to run could never clear it, and it would repeat on every prompt.
```
