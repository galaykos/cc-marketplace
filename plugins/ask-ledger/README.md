# ask-ledger

Catches the silent avert: work that quietly does less than the ask named, with no
reason written anywhere.

`candor`'s avert guard fires when the model writes its reason down ("to be safe",
"original mascots instead"). On 2026-09-19 six headless runs asked for "Digimon themed …
2D pixel-art sprites" drew invented creatures and wrote nothing at all — no hedge, no
reason (`rationale/fable-distillation-2026-09-18.md` §4). No script can judge whether
the sprites are Digimon. It can insist the model say so, per named thing, in the place
the reader looks, and refuse the turn until it does. That is this plugin, and it is its
own plugin so it can be disabled on its own.

## What it does

| event | script | does |
|---|---|---|
| `UserPromptSubmit` | `hooks/ledger.sh` | on a work-shaped prompt (a making verb in an imperative clause), destructures the ask into the things it **names** — proper nouns not at a clause start (`Laravel`, `Digimon`), quoted terms (`"digimon"`), digit-letter tokens with their word (`2D Sprites`) — into a session ledger (deduped, later prompts append, 12 max) and tells the model the gate shape once per prompt that added entries |
| `Stop` | `hooks/gate.sh` | refuses the final message (exit 2, reason on stderr) unless it carries one line per ledgered name: `<name>: as named` \| `<name>: substituted → what, why` \| `<name>: omitted → why`. At most two blocks per session; then it warns and lets the turn end |

Your original prompt of 2026-09-18 ("create a Laravel + React project … landing page
with 2D Sprites and motion animation, Digimon themed … a "digimon" library") ledgers
`digimon, 2D Sprites, Laravel, React`; the follow-up "redo them as Agumon, Gabumon,
Patamon and Gomamon" appends four more. The final message then owes eight lines.

## Standing, said plainly

- **Gate on the shape.** The line must exist; the script proves that and nothing more.
- **Agent-graded on the truth.** Whether `Digimon: as named` is true is the model's word
  and the reader's eye. The design bet: a silent substitution has to become either a lie
  in a line the reader will check, or a confession. Neither is silence, and the lie is
  the rarer failure.
- **What it does not see:** lowercase features (`login`, `register`, `a library`) — the
  ledger sees names, not nouns; a name mentioned in passing ("like Stripe does") is
  ledgered and costs one line; anything inside code spans. A name the extractor misses is
  a name the gate never asks about.
- **Off switch:** `CC_ASK_LEDGER=off`. No ledger (no work-shaped prompt this session): silent.
- **Subagents:** not wired. A worker's final message is the orchestrator's data, not the
  user's reading; the orchestrator's own final message is where the accounting belongs.

## Measuring it

`evals/named-things-accounted/case.yaml` — the Digimon prompt whose control arm is
recorded inventing creatures 6/6 with no accounting. Run it with the operator grant the
runner needs: `claude plugin eval ./plugins/ask-ledger --ablation with-without --runs 3
--allow-tools Write Edit`. Not run yet; the number it would produce is the one this
README does not have. Harnesses: `scripts/__tests__/ledger-hook.test.sh` (10 cases) and
`gate-hook.test.sh` (9 cases), picked up by CI's glob.
