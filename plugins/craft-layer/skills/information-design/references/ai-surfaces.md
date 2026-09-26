# AI surfaces — agents and assistants inside the product

This file covers the in-app half. The marketing-side clichés are listed in
`../../creative-direction/references/sameness-fingerprint.md`. Streaming transport is the stack
skills' job. Tables here follow `dense-ui-patterns.md`.

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The "without it" failures are an inference from reviewing shipped products, not a
measurement.

## Prompt composer

- **Field and placeholder.** A real `<textarea>` with an accessible name. The placeholder is a
  real task in the product's own domain ("Find deals closing this month with no next step"),
  never "Ask me anything". `agent-graded` (SC 4.1.2)
- **Domain chips.** Three to five real tasks, as buttons. A chip FILLS the box so the user can
  edit it. It never sends straight away. `recorded`
- **Keys.**
  - Enter submits and Shift+Enter adds a newline.
  - Nothing submits during IME composition: check `isComposing`.
  - On touch devices, Enter adds a newline and the send button submits.
  - `recorded`
- **Streaming state.**
  - Send becomes a named Stop button ("Stop generating").
  - The reply streams on screen and is announced once, when it completes, through one polite
    status ("Answer ready"). Never announce it token by token.
  - `agent-graded` (SC 4.1.3)
- **Attach.** A real button over a file input. The drop-zone rules are in the Upload row of
  `product-packages.md`. `agent-graded` (SC 2.1.1)
- *Without it:* an empty box with a generic placeholder, chips that auto-send, a reply read out
  in fragments, and Enter that submits halfway through an IME word.

## Agent status chip

- **Content.** A verb phrase, the object, a live indicator and the elapsed time: "Researching 14
  accounts · 0:42".
- **Indicator.** An indeterminate cue that becomes static text under reduced motion.
- **Announcements.**
  - Phrase changes are announced politely, at step boundaries only.
  - The elapsed timer is never inside a live region.
- **End states.** "Done · 1:12", or "Failed: rate limit · Retry", with Retry as a real button.
- *Without it:* a spinner and "Thinking…" with no end, so stuck and slow look the same.

`agent-graded` (SC 4.1.3); content `recorded`

## Run log

- **The list.** Steps form an ordered list. Each shows an outcome mark (glyph plus word when it
  failed), the step name, the tool or model it used, and its duration in tabular figures.
- **Current step.** The running step carries `aria-current="step"`.
- **Detail.** Failed steps expand by default, and each step's input and output expand in mono.
  Long output is truncated behind "Show full output".
- **Evidence, not narrative.** The log shows what the agent did. It is not a paragraph about
  what it did.

`recorded`

## Agent ledger

A table of runs. The columns are:
- task;
- run by: the human's or the agent's avatar and name;
- model: the provider mark and model name;
- status;
- eval: a number plus a band word;
- cost: right-aligned tabular currency, at one consistent precision;
- duration;
- started.

*Without it:* a chat transcript stands in for the table a team actually audits. `recorded`

## Ask panel and citations

- **Where the assistant opens.** An "Ask ⟨product⟩" entry in the page header opens a side-panel
  thread, not a modal, so the record stays in view. `recorded`
- **Citations.**
  - Inline numbered citations are real links or buttons, each named by its source.
  - One opens a non-modal citation panel showing the source title, a snippet and a link to the
    record or document.
  - Focus moves into the panel and returns to the citation when it closes.
  - An answer with no sources says so.
  - `agent-graded` (SC 2.4.4, 4.1.2)
- **Feedback.** Helpful and not-helpful are labelled buttons with `aria-pressed`.
  `agent-graded` (SC 4.1.2)
- **Recommendation banner.** One line with one action ("12 deals have no next step · Review"),
  dismissible. It is never a toast that times out (SC 2.2.1). `agent-graded`

## Anti-pattern: AI shown only as a sparkle, an orb or a glow

Showing AI only as a sparkle icon, a pulsing orb or a glow around an empty prompt box says
nothing about what the AI does. Show the work instead:
- a real domain task in the composer;
- a run log with outcomes;
- a ledger row with a cost;
- a cited answer.

A sparkle may mark an AI action beside a text label. It is never the whole story. `recorded`
