# prompt-coach judge — labelled-set measurement and Haiku 5.5 first-pass probe (2026-10-25)

Purpose: the owner's rework decision for prompt-coach asked for one measurement of the
judge. Its README said "Judge quality is unmeasured", and that "nothing here was measured on"
Haiku 5.5, the model the `haiku` alias resolves to since CLI 2.1.293. This record covers both.

**Standing: `recorded`** — a one-time measurement; nothing re-runs it. The harness and raw
rows are in `rationale/2026-10-25-prompt-coach-judge/`.

## 1. The judge on a labelled set

Method:
- **Harness.** `measure.mjs`, run under Node 24, imports `plugins/prompt-coach/hooks/coach-core.ts`
  (prompt-coach 0.6.0) itself, so it uses the shipped `systemPrompt`, `judgeInput`, `parseLabel`,
  `parseVerdict`, `shouldHold` and `isEligible`. It reimplements none of them.
- **The chain the coach runs.** A first pass on `haiku`; when it answers anything but clear, a
  standby on `sonnet`; a prompt counts as dropped when `shouldHold` holds the standby's verdict.
  Sensitivity `unactionable` (the default), no task-runner run.
- **Transport: `claude -p`, not `$.model.complete`.** Flags: `--setting-sources project`,
  `--strict-mcp-config`, `--disable-slash-commands`, `--tools ""`, `--system-prompt <the coach's>`,
  `--output-format json`. It ran from an empty temp dir. With project settings only, no plugin
  hooks load: the hindsight ledger wrote no row. The CLI adds about 550 tokens of its own
  scaffolding, and it sets no `maxTokens`. §2 covers the coach's own call shape.
- **Models.** `modelUsage` named `claude-haiku-5-5` and `claude-sonnet-5-5`. CLI 2.1.310.
- **Set.** 24 prompts in three labels, all eligible by `isEligible`:
  - 12 clear: actionable as written, or through a `<turns>` context that names the referent;
  - 9 unclear: a referent nothing identifies, or no action;
  - 3 conflict: the prompt reverses an instruction stated in `<turns>`.
- **Who labelled them.** The reviewer wrote the cases and the labels, following the coach's own
  rubric. The labels are a judgement, not ground truth (one turned out wrong, below).
- **Runs.** Each prompt 3 times: 72 first passes and 33 standby calls, $0.094 in total by
  `total_cost_usd`.

| Label | Cases × runs | First pass flagged | Dropped (`shouldHold`) | Spread across the 3 runs |
|---|---|---|---|---|
| clear | 12 × 3 | 0 / 36 | **0 / 36** | unanimous in every case |
| unclear | 9 × 3 | 24 / 27 | **24 / 27** | unanimous: 8 cases dropped 3/3, `u03` passed 3/3 |
| conflict | 3 × 3 | 9 / 9 | 6 / 9 | unanimous: `x01`, `x02` dropped 3/3 as `contradicts`; `x03` passed 3/3 |

Reading it:
- **No false drop** in 36 runs of clear prompts, including four short follow-ups ("yes, update
  the README too", "go with option 2 then", "do the same for the other two", "that looks
  right, commit it…") whose referent only `<turns>` supplies.
- **One miss.** `u03` "do the same for the rest of them please", sent with no turns, read as
  clear in all 3 first passes. The standby never saw it.
- **`x03` was mislabelled, not missed.** The prompt was "Push the branch to origin and open the
  PR now", after the turn "Never push anything without asking me first". The person asking is
  the permission, so the standby's `clear` is right. Without it, conflict reads 6/6.
- **Every standby reply parsed** as the strict JSON the coach expects: 33 of 33.

Not measured:
- `off-card` and `reopens` (they need a run's cards and spec), and sensitivity `ambiguous`;
- the standby on `opus`;
- prompts as a person really types them, and conversations longer than two turns;
- the rewrite's quality.

n = 24 cases × 3 runs from one author is a smoke test of the judge, not its false-positive
rate; the `coach.send / coach.flagged` counts prompt-coach 0.6.0 keeps are the instrument for that.

## 2. The coach's own first-pass call on Haiku 5.5

The README's concern: the coach calls `$.model.complete` with `maxTokens: 8` and
`effort: 'low'`, and a Haiku 5.5 that thinks first could spend those 8 tokens, answer no text,
and turn the coach silently off.

Method:
- A throwaway mod, `first-pass-probe.ts`, built under `mktemp -d` and loaded with `--plugin-dir`.
  Its `prompt.submit` hook made the coach's exact request: `model: 'haiku'`, the coach's first-pass
  system prompt and `judgeInput`, `maxTokens: 8`, `effort: 'low'`, `timeoutMs: 5000`.
- 5 prompts (2 clear, 3 unclear), each twice. The rows went to a file.
- One `claude -p "reply ok"` run on CLI 2.1.310. The probe's hindsight ledger entry was deleted
  afterwards.

| Result | Value |
|---|---|
| answered | 10 / 10 (`isAnswered: true`), none empty |
| output tokens | 4 (clear) or 5 (unclear); the reply is the bare word |
| labels | 10 / 10 as labelled |
| hook-measured time | 1084–1976 ms, median 1160 ms |

Reading it:
- **The silent-first-pass risk did not occur.** On this CLI Haiku 5.5 answers inside the 8 tokens.
- **The first pass got slower.** It now holds an eligible prompt about twice as long as the
  0.6 s median the README cites from Haiku 4.5: 1.16 s median, n = 10, one host, one network.
  The 5 s deadline is far off, but every eligible prompt pays it.

## What this changes

- prompt-coach's README now cites this record:
  - in "Judge quality is unmeasured": partly measured;
  - in the Haiku 5.5 residual: measured on 2.1.310;
  - in "The hold": the ~0.6 s became ~1.2 s on Haiku 5.5.
- Nothing in the code changes. The `u03` miss is one case at n = 3; it is the shape (a "the
  rest of them" referent with no turns) to watch in the `coach.*` counts.
