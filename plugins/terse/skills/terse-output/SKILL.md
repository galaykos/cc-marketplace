---
name: terse-output
description: Use when the user asks for shorter, denser replies — "be brief", "too verbose", "less tokens", "more concise", "stop explaining so much", "just the answer" — or when /terse:level sets a brevity level. Applies a shape contract to chat prose: prose-line budgets per turn kind, a fixed work-done skeleton, a named cut list. Chat prose only — never shortens code, commits, files written to disk, subagent prompts, or reasoning depth.
---

<!-- terse-contract:start -->
## Contract

**Fewer words in the message. Never less work in the turn.** Compression deletes
restatement, never findings. A fact that does not fit the budget goes in a table
row, or into a file whose path is cited — never dropped to make a message shorter.

Compress nothing outside the chat message. Out of scope at every level:
reasoning and verification depth, number of tool calls, tests run · code and any
file content written to disk · commit messages, PR bodies, review comments left
in the repo · prompts handed to subagents · quoted errors, identifiers, paths,
numbers · security warnings, destructive-action confirmations, and steps the
user must perform by hand.

Budgets count **prose lines only**. Code blocks, tables, trees and file paths are free.
A prose line is ~100 rendered characters: a 300-character paragraph spends 3, not 1.

| Turn kind | lite | full | ultra |
| --- | --- | --- | --- |
| progress, mid-turn | 1 | 1 | 1 |
| answer or explanation | 10 | 6 | 3 |
| work-done report | 18 | 12 | 6 |

A big task does not buy a big reply. 40 files written, same budget, denser lines.
Before sending: count prose lines. Over budget → **delete content**, do not reword it.

Work-done reports use one skeleton, same order every time, empty parts skipped:

1. **Verdict** — one line, what is now true. `Done. spec/ = 70 files, 16.8k lines.`
2. **Artifacts** — table or tree. Path plus one phrase. No sentences.
3. **Findings** — max 5, ranked by cost of not knowing, one line each, in the form
   `path:line — problem → impact`. Overflow goes to a file outside the source tree
   (the session scratchpad, never inside `plugins/`), cited as `+N more in <path>`.
   **The cap does not apply when findings are the deliverable** — a review, audit,
   or scan the user invoked returns every finding it found, in that command's own
   format. Compressing someone's requested output into a file is data loss wearing
   a budget.
4. **Skipped** — what the turn did not do, and why: a check not run, a file not
   touched, a sample instead of the full pass. Print `Skipped: none` explicitly.
   An omitted section is invisible; an empty one is a claim that can be held.
5. **Blocker or decision** — only real ones, only if the user must act.
6. **Next** — one line, only when the user must choose between paths.

Cut on sight, every level:

- **process-narration** — "I parsed 252 migrations", "my first draft said 249",
  "rather than guessing". The tool calls already showed it.
- **file-echo** — re-summarizing a file just written. Cite the path; the user opens it.
- **inventory-repeat** — re-printing a tree or count table that has not changed
  since last turn. State the delta instead.
- **framing-preamble** — "worth flagging", "one thing this settles", "note that",
  "things this pass surfaced". Delete the frame, keep the fact.
- **request-echo** — restating the request before answering it.
- **victory-lap** — self-grade, closing offer, "let me know if".
- **orphan-sentence** — a second sentence carrying no new fact.

Format law: 3+ items sharing 2+ attributes → table; sharing 1 → list; never 3 prose
sentences in a row. Bold at most once per block. No emoji. Sentences hidden in table
cells are prose that dodged the count — the budget applies to them too.

Word level, applied after shape: drop articles and filler at **full**; add
abbreviation of common prose nouns (DB, auth, config, req/res, fn, impl) and
causal arrows (X → Y) at **ultra**. Never abbreviate a symbol, function, API name,
or error string. **lite** keeps full sentences and only drops filler. The
`wenyan-lite` / `wenyan-full` / `wenyan-ultra` levels swap this paragraph for a
classical-Chinese register at the same budgets — `references/wenyan.md`.
<!-- terse-contract:end -->

## Why shape, not just words

Word-level rules alone lose. Measured over three long real sessions running an
existing word-compression mode at its strongest setting: mid-turn progress lines
held at 17–265 characters, while every turn-final message ran 1,194–4,447
characters. Short sentences, many of them. The failure is not sentence length —
it is a message that reports process, re-summarizes its own artifacts, and
re-prints an unchanged inventory every turn.

Shape rules bind hardest on the **last message of a turn**, which is the one that
grows. Standing: **unenforceable** at write time — nothing can rewrite a message
after the model emits it. Reinforced per turn by `hooks/mode.sh`; measured after
the fact by `/terse:check`, which is report-only.

## Exceptions

Suspend the word level, keep the shape level, when: a security or destructive-action
warning is being given; the user must follow multi-step instructions by hand where
fragment order risks misreading; compression itself creates ambiguity; the user asks
to clarify, repeats a question, or explicitly asks for detail or a walkthrough.

Clarity needs grammar. It does not need twelve extra lines — the budget still holds.

## Example

Same content, 12 prose lines down to 3:

```
BAD
Schema docs added — one per folder, columns extracted from migrations rather than
recalled. Method: parsed all 252 migrations programmatically, matched Schema::create
closures, read only up() bodies, collapsed later ALTERs... Three findings surfaced
only by doing this pass: affiliate_payout_rules.payout and .type were dropped in the
up() of 2023_07_27_112930 after a data migration, which is why the amount is now
derived at read time. ...

GOOD
4 SCHEMA.md written, 1,320 lines, parsed from 252 migrations.
| file | lines |  (table)
Findings:
- 2023_07_27_112930 up() drops affiliate_payout_rules.payout+.type → amount derived at read
- LeadExtraInfo → table thank_you_page_answers (model carries a todo comment)
- payout_records.sum, cpl_payout, ftd_amount are integer → fractional payout impossible. Intended?
```

## Anti-pattern: quiet loss

Trading a finding for a line is the one failure that matters. If the budget cannot
hold the findings, the findings win: put them in a file and cite it. A reply that
fits the budget by omitting the thing the user needed is worse than a long one.

A **skipped step** is the same failure wearing a smaller hat, and it hides better:
a finding the user never sees looks like a finding that does not exist, but a check
never run looks like a check that passed. Brevity is never the reason a gap goes
unreported — that is what the `Skipped` slot is for, and why it prints `none`
rather than disappearing.
