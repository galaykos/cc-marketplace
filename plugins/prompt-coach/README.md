# prompt-coach

A prompt coach for the terminal. At Enter it holds an eligible prompt for up to 5 s
while a model judges whether nobody could act on it, whether it contradicts an earlier
instruction, or, during a task-runner run on this branch, whether it strays off the
running card or reopens a decision its spec settled; only a confidently flagged prompt is dropped, and an animated
pixel-art sprite shows your text, the reason and a rewrite, with buttons that fill the
prompt box and never submit it. A haiku first pass judges every eligible prompt, and the
standby model below confirms a flag, at most 10 times a session. Terminal only; it
needs Claude Code 2.1.291 or newer with mods allowed. The coach also stays on screen as a
mascot: a pixel-art pane beside the transcript, or a text face in the status line.

Bulk installs leave it out, because it bills a model call per eligible prompt:
`/all-plugins:install` and `/stack-scan:suggest --full` skip it, though
`/all-plugins:uninstall` removes it like any other plugin. stack-scan's default picker
still lists it, so a picked range, or "print the install commands for the rest", can
include it.

```bash
claude plugin install prompt-coach@cc-plugins-marketplace -s local
```

## At Enter

The plugin is one hooks module, `hooks/coach.ts`, the only entry under `modules` in
`hooks/hooks.json`; it has no classic hooks.

- **Which prompts are judged.** A prompt typed in this terminal's prompt box (origin
  `composer`, queued or not), with no attachments, not starting with `/`, `!` or `#`
  (after any leading spaces), with at least 4 tokens or at least 16 non-space characters.
  So a prompt is skipped only when it has fewer than 4 tokens and fewer than 16 non-space
  characters, spaced or not: `ok thanks` is skipped, a 16-character line with no spaces
  is judged. A text you marked to pass goes through unjudged, and so does every prompt
  while the coach is muted, backing off or judging another prompt.
- **The hold.** The band above the prompt box shows the sprite thinking beside
  `checking your prompt…`. Haiku is asked for one word (`clear`, `unclear` or
  `conflict`); the coach reads its first word, ignoring case and any leading spaces, `*`,
  `_`, backtick or quote, and a reply whose first word is none of the three counts as
  clear. On `clear` the prompt goes on, after about 0.6 s (haiku's median in the probe).
  On a flag the standby model answers a JSON verdict: a kind, a confidence, a one-line
  reason and a rewrite. Calls still running 5 s into the judgment are aborted, and the
  prompt goes on.
- **The drop.** A prompt is dropped only when the verdict is not clear, says
  `confidence: high`, carries a reason and a rewrite, and names a kind its context
  supports, and only once a blit of a 1x1 Raster marker proves the band is on screen. The
  transcript gains one line, `● Prompt dropped by a hook: prompt-coach held this prompt
  (unclear); set CC_PROMPT_COACH=off to stop`; the prompt never enters the conversation,
  and the prompt box is left empty. In the live walks the drop came 2.86-3.57 s after
  Enter.
- **Everything else passes untouched.** A clear or low-confidence verdict, a timeout, an
  API error, a model your organization refuses, malformed output and any error inside the
  hook all let the prompt through, and every later prompt hook (taskmaster's reminder,
  candor) sees it as if the coach were absent; a dropped prompt reaches none of them.
  **Recorded** — from the CLI's types, never observed live; `tests/coach.test.ts`, "a
  passed prompt reaches next unchanged", gates only the hand-off. The coach ignores the
  phase sentinel and judges in every phase.

## The bubble

At 200 columns, with the Raster sprite (the picture loses its colours):

```text
● Prompt dropped by a hook: prompt-coach held this prompt (unclear); set CC_PROMPT_COACH=off to stop

      ▄▄▄▄▄▄      1: Use rewrite  2: Send anyway  3: Mute  (1, 2 fill the box; Enter sends)                                                                                                         [-]
    ▄▀▀▀▀▀▀▀▀▄    Unclear: It's unclear what 'it' refers to or what 'the usual way' means; no earlier turns identify the problem or the fix.
   ▀▄▀▀▀▀▀▀▀▀▄▀   You wrote: please just fix it the usual way again now
    █▀▀▀▀▀▀▀▀█    Suggest:   Please fix the failing test in <file/module> by <the specific fix, e.g. updating the snapshot or re-running the migration>, the same way as last time.
    █▀▀▀▀▀▀▀▀█
    ▀▄▀▀▀▀▀▀▄▀
  ▄▀▀▀▀▀▀▀▀▀▀▀▀▄
  █▀▀▀▀▀▀▀▀▀▀▀▀█
                                                                                                                                                                          Ctrl+Y to paste deleted text
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

This is the final live walk's screen, the shipped code on CLI 2.1.292. The marker is the
blank column 0, the sprite fills columns 1-16, column 17 is the gap and the text starts
at column 18; the marker costs that one column. `Ctrl+Y to paste deleted text` is the
CLI's own hint.

- **Buttons, on the first row.** `1` Use rewrite fills the box with the rewrite and `2`
  Send anyway fills it with your text. Neither sends: Enter does. Either filled text
  passes unjudged whenever it is sent again this session; edit it and it is another text,
  judged again. `3` Mute stops every flag and every model call for the rest of the
  session, with a toast saying a new session turns it back on. While the bubble shows, a
  bare digit typed into the empty box presses its button. A box you have typed in since
  the drop is never overwritten (a toast asks you to clear it), and a fill the CLI
  refuses leaves the bubble up with the text in it.
- **Small bands.** A band under 70 columns or under 8 rows draws no sprite. Under 8 rows
  the order is buttons, reason, `Suggest:`, then `You wrote:` cut to one row; `2` still
  fills your whole text. At 80x24 the final walk showed the buttons, the `Unclear:` line
  and `Suggest:`, then `↓ 3 more`, with the marker at column 0, the gap at column 1 and
  the text from column 2; a bare `2` filled the whole text.
- **Kinds named:** `Unclear`, `Contradicts an earlier turn`, `Off-card`, `Reopens D<n>`.
- **When it ends.** At a button press, or at a prompt you submit from the prompt box; a
  prompt-type slash command such as `/init` ended it in the walk. A prompt from another
  origin (a notification, a peer) leaves it up, and so do the inputs under "What does not
  end the bubble" below.
- **After the cap.** Once the session's 10 standby checks are spent, a haiku flag shows the
  idle sprite with one line and no buttons, `Sent, but a quick check found it unclear: the
  10 full checks of this session are used.` (or `flagged a possible conflict`); the prompt
  was sent. The line ends at your next submit.
- **Animation.** The thinking and talking loops run at 4 frames a second and stop about
  5 s after Enter, the talking pose on its closed mouth. The deadline runs from the start
  of the judgment, not from Enter (see "Deadline overruns" below).

## The mascot

`cc_coach_mascot` (or `CC_COACH_MASCOT`) picks where he lives: `pane` (the default),
`statusline` or `off`. It is read once, at the first draw of the band in a session, and
changes nothing about the judging. `CC_PROMPT_COACH=off` turns him off with the coach, and
the variable's `0` and `false` mean off too. **Gate** — `tests/coach-view.test.ts`,
"CC_COACH_MASCOT=off opens no pane, and the coach still judges", "off shows no mascot at
all", "CC_COACH_MASCOT=0 is off", "CC_COACH_MASCOT=statusline beats the pane option".

- **`pane`.** A pane titled `coach`, 18 columns wide, docked beside the transcript, opened
  once a session, only when the renderer is fullscreen (`"tui": "fullscreen"` in
  settings.json, or `CLAUDE_CODE_NO_FLICKER=1`): under the default renderer the CLI would
  seat an unasked pane inline above the prompt, so none opens. The CLI 2.1.292 types say an
  unasked pane waits undrawn below 144 terminal columns (110 once you have opened that pane
  yourself) and is seated when the terminal is widened. **Gate** — "opens one docked pane a
  session, only under the fullscreen renderer", "opens no pane where the renderer would seat
  it inline".
  - It shows the idle sprite at rest, the thinking loop with `checking…` while a prompt is
    held and the talking pose with `flagged` while the band shows a bubble; the bubble and
    its buttons stay in the band. A pane under 16 columns or 8 rows draws no sprite.
    **Gate** — "the pane shows the idle sprite and follows the judgment", "says flagged
    while the band shows a bubble".
  - At rest the eyes shut for 0.15 s every 4 s. `s: Still` stops the blink for the
    session. A pane that refuses the blink stops it until the pane draws again, then
    blinks again. **Gate** — "blinks every 4 s at rest", "Still stops the blink", "a pane
    that refuses the blink stops blinking until it draws again".
  - **He cannot be closed.** The pane's close mark and ctrl+x x raise a close the coach
    refuses while the display is `pane`, with a toast saying how to move or remove him.
    Esc only hands the keys back (the pane is not opened with `closeOnEscape`). **Recorded**
    — the CLI types say a `ui.close` hook answering without `next` keeps the pane open on
    a person's close; the test kit's engine raises no `ui.close` (its `ui` carries focus,
    input, mount, press, render, scroll and select), so no test exercises it.
  - **Switching away.** `statusline` or `off` set in `/config` reloads the plugin, and the
    pane still open from before is closed at the band's next draw; set through
    `CC_COACH_MASCOT` it takes a new session. Under any display but `pane` the pane draws
    nothing. **Gate** — "a display other than pane closes the pane a /config change left
    open", "the pane draws nothing and never blinks unless the display is pane".
- **`statusline`.** A pinned status line under the prompt, in every renderer: `(^_^) coach`
  at rest, `(-_-) coach  checking…` while a prompt is held, `(O_O) coach  Unclear: <reason>`
  while the band shows a bubble, back at rest on your next prompt. No sprite, no blink, and
  nothing to close. **Gate** — "statusline shows a text face in any renderer, and opens no
  pane", "the status line follows the judgment".
- **No model calls.** The mascot only draws: the pane's blink costs a timer, two blits (shut,
  then open 0.15 s later) and one more timer dispatch every 4 s.

## What it flags

- **Unclear.** With the default sensitivity, `unactionable`: nobody could act on it. It
  leans on a referent (it, that, the bug) that nothing in the recent turns or the run's
  context identifies, or it names no action at all. `ambiguous` also flags scope open to
  materially different readings that nothing in context settles. The judge is told that
  a prompt cut for length is never unclear for the cut; whether it obeys is judge
  quality, unmeasured.
- **Contradicts an earlier turn**, at any time: it reverses your own instruction in the
  recent turns without giving a reason.
- **Off-card**, only during a task-runner run on this branch with a card in progress: it
  asks for work outside the cards in progress.
- **Reopens D\<n\>**, only when that run's index names a spec, and only for a decision id
  the spec lists: it reopens a decision the spec settled.

The judge is told that skipping a phase (planning, review, tests) is never a conflict;
whether it obeys is judge quality, unmeasured. A run on this branch is task-runner's
`.claude/task-runner/active-run.json`, at the repository root, naming the current branch.
Its cards in progress are the index rows whose status starts `in_progress`, each with its
milestone's `Files:` line; its spec is the file the index's `Spec:` line names under
`taskmaster-docs/specs/`, read for its `## Goal` and its `## Decisions` rows. With no such
run the judge sees no card or spec context.

## Options

| `/config` option | variable | values | default |
|---|---|---|---|
| `cc_prompt_coach` | `CC_PROMPT_COACH` | on, off | on |
| `cc_coach_mascot` | `CC_COACH_MASCOT` | `pane`, `statusline`, `off` (the mascot only) | `pane` |
| `cc_coach_model` | `CC_COACH_MODEL` | `sonnet`, `opus` (the standby judge) | `sonnet` |
| `cc_coach_sensitivity` | `CC_COACH_SENSITIVITY` | `unactionable`, `ambiguous` | `unactionable` |

Set the option under `/config` or `/plugin configure prompt-coach`; the variable, set in
your shell or a settings.json `env` block, overrides it. `CC_PROMPT_COACH` turns the coach
off only at exactly `off`, `0` or `false`, in any case; any other non-empty value (`no`,
`disabled`, ` off` with a leading space) turns it on, over a `/config` off, and an empty
or unset variable leaves the option in charge. `CC_COACH_MODEL` and `CC_COACH_SENSITIVITY`
ignore case and surrounding spaces, and a value outside the list falls back to the option,
then the default. `CC_COACH_MASCOT` reads the same way, except that `0` and `false` (any
case) mean `off` rather than falling back.

Fixed in code: haiku as the first pass, the 5 s deadline, 10 standby checks a session,
and a 10-minute back-off after 3 judgments in a row fail (an API error, a refused call, a
timeout).

## Cost

- **Every eligible prompt:** one haiku call.
- **Every flag:** one standby call, at most 10 a session; a failed or timed-out one
  counts. A toast says when the cap is reached.
- **Mute** stops every call for the session. The cap, the mute and the back-off all end
  with the session.
- **Opus** as the standby is the slower choice: by the probe's timings, with opus in
  sonnet's place all 5 judgments would have finished inside the 5 s deadline, the slowest
  at 4236 ms from the hook's start, against 3298 ms for sonnet's slowest.
- **`/cost` shows none of it** (residuals below).

## Where it runs

- **CLI floor.** Below Claude Code 2.1.291 every prompt passes and the plugin does
  nothing. **Gate** — `tests/coach.test.ts`, "passes everything below the floor or when
  switched off". With mods off in the host the module does not load. **Recorded.**
- **The 2.1.287 caveat** other mods carry (a plugin's `tool.call` hook breaking Bash and
  file search in worktree subagents) does not apply: the coach registers no `tool.call`
  hook. **Recorded.**
- **Organization policy.** An organization that sets `allowManagedModsOnly` refuses the
  module, and nothing is judged. **Recorded** — from the CLI's own mod documentation, not
  measured.
- **An early-access API.** The CLI's mods API is early access and may change without
  notice. Everything here was observed on CLI 2.1.291 and 2.1.292 only, and the version
  check has a floor but no ceiling, so a newer CLI runs the coach unverified. **Recorded.**
- **Terminal only.** In a session the desktop app draws on, and in one with no terminal
  (mobile, VS Code), every prompt passes untouched. **Gate** — `tests/coach.test.ts`,
  "passes every prompt untouched off the terminal, the desktop included".
- **The sprite.** 16x16 pixels in 16 columns x 8 rows: idle, thinking and talking, two
  frames each for the last two. It starts as an Image when `TERM` is `xterm-kitty` or
  `TERM_PROGRAM` is `ghostty` outside tmux, and turns Raster half-blocks for the session
  at the first Image blit the CLI draws as its alt; everywhere else, tmux included, it is
  Raster. The CLI, not `TERM`, decides whether an Image gets pixels: the terminal's
  answers to its graphics query do (probe). The art is first-party, drawn in code; no
  image file ships.

## Residuals, stated

Each carries its standing. "Probe" is `rationale/2026-10-07-prompt-coach-probe.md` in
this marketplace's repository, and "walk" the maintainers' live walks on CLI 2.1.291 and
2.1.292, which are not published; nothing re-runs either.

Skipping and spend:

- **What is skipped.** A prompt with fewer than 4 tokens and fewer than 16 non-space
  characters, a slash command, a `!` or `#` prompt, a prompt with attachments and one from
  another origin are never judged (At Enter, above). **Gate** —
  `scripts/__tests__/coach-core-gate.test.sh` and `tests/coach.test.ts`, "skips
  ineligible prompts without a model call". A click on a transcript link carries origin
  `composer` by the CLI's types and is judged; neither it nor a phone prompt's origin was
  observed. **Recorded** (probe).
- **Spend:** a haiku call on every eligible prompt, and a standby call per flag, at most 10
  a session (Cost, above). **Gate** — `tests/coach.test.ts`, "stops escalating after the
  cap".
- **`/cost` shows none of the coach's calls**, nor does the session's usage; only each
  call's own usage counts them. **Recorded** (probe; the walk saw `$0.00` again while
  coach calls ran).
- **Aborted calls report zero usage**; whether they are billed was not observed.
  **Recorded** (probe).
- **The standby's token cap is not the module's.** The CLI sent the standby request with
  `max_tokens` 2448, not the module's 400, so the rewrite's size rests on the parser's
  bound: a reason over 200 characters or a rewrite over 80 words or 600 characters
  discards the verdict and the prompt passes. **Recorded** (walk); the bound is a **gate**
  — `scripts/__tests__/coach-core-judge.test.sh`.

What the judge sees, and how far to trust it:

- **A separate model call, on your own account.** Your prompt (its first 4,000
  characters), the last 6 turns with text (2,000 characters) and, during a run, the cards
  in progress (500) and the spec's goal and decisions (1,500) go to the judge model, never
  over 8,000 characters in all. **Gate** for the caps —
  `scripts/__tests__/coach-core-judge.test.sh`.
- **What the context meter cannot see.** This marketplace's `context-budget.sh` meters no
  text a mod puts anywhere: not the judge's input, and not a rewrite you send, which
  reaches the main conversation as your own prompt. **Unenforceable** — the meter runs no
  mod. A prompt the coach passes reaches the main model with nothing attached: **gate** —
  `tests/coach.test.ts`, "a passed prompt reaches next unchanged".
- **The standby only confirms.** The model you configure (sonnet or opus) sees only the
  prompts the haiku first pass flagged; a prompt haiku calls clear is never shown to it.
  **Gate** — `tests/coach.test.ts`, "passes a clear prompt untouched".
- **Judge quality is unmeasured.** Whether the judge flags the right prompts, and obeys
  the rules it is told, is not measured: the plugin tests stub the judge, so they prove
  the plumbing only, and no eval ships. **Unenforceable** without a live eval.
- **The rewrite can be steered.** Text planted in the recent turns, card titles and files,
  or the spec's decisions can shape the reason and the rewrite: a cloned repository's task
  files, or an assistant reply quoting a web page. Read the rewrite before you press
  Enter. **Unenforceable.**
- **Whose words the turns are.** Every user row with text goes to the judge as your own
  instruction. Whether those rows also carry an expanded slash command or the context
  another plugin's prompt hook attached (candor, taskmaster) was not observed; if they
  do, that text can draw a `contradicts` flag. **Recorded** as unobserved.
- **What limits that.** A `.claude/task-runner/active-run.json` that git tracks (one a
  clone brought), or one git cannot vouch for, is ignored. The index and the spec are read
  only as regular files of at most 256 KiB whose real path lies inside the repository.
  **Gate** — `tests/coach.test.ts`, "ignores the run of a committed active-run.json" and
  "reads run context only from a small regular file under the state root". What this does
  not stop: a cloned repository's own CLAUDE.md still reaches the main model unguarded,
  and task-runner and code-review still trust the same `active-run.json` through the
  shared kit; only the coach distrusts it. The git check runs inside the 5 s hold, capped
  at 2 s. **Recorded.** A reason with
  a tab or newline, or a reason or rewrite carrying a control or bidi character, discards
  the verdict and the prompt passes. Every `<`, `＜` and `﹤` the judge reads is written
  `‹`, so planted text cannot open or close a section of its input. The judge is asked to
  write each `‹` back as `<`, and one it leaves is turned back, unless your prompt holds a
  `‹` of its own, when every `‹` in the rewrite stays. **Gate** —
  `scripts/__tests__/coach-core-judge.test.sh`. `〈` and `⟨` are not escaped. **Recorded.**
- **Pictographs.** A reason carrying a pictograph (an emoji, and also ©, ®, ™ or ‼)
  discards the verdict, and the prompt passes. **Gate** —
  `scripts/__tests__/coach-core-judge.test.sh`.
- **Opus.** One reply observed (walk, `CC_COACH_MODEL=opus`): bare JSON, which the parser
  accepted, and the prompt was held. One sample; a reply wrapped in a code fence would be
  rejected by the parser and pass the prompt unflagged. **Recorded.**
- **Long specs.** The spec's goal and decision rows are cut at 1,500 characters, so on a
  long spec the judge sees only the first few decisions it could call reopened.
  **Recorded.**
- **A second reader of the index.** The coach parses the task index itself, beside
  task-runner's board (`board-core.ts`), which a plugin installed alone cannot import; the
  two can drift when the index shape changes. A `Files:` path with a space splits in two.
  **Recorded.**

Hold timing and order:

- **Enter can wait up to 5 s** on an eligible prompt; a clear one waits about the first
  pass's 0.6 s. **Gate** for the deadline — `tests/coach.test.ts`, "aborts calls still
  running at the deadline".
- **Concurrent prompts.** A prompt submitted while another is judged passes at once,
  unjudged, and can reach the model before the held one. **Gate** for the pass —
  `tests/coach.test.ts`, "a submit during an in-flight judgment passes unjudged";
  **recorded** for the order.
- **Deadline overruns.** A verdict whose bookkeeping finishes past 5 s passes the prompt,
  with no toast. **Gate** — `tests/coach-view.test.ts`, "a verdict counted past the
  deadline passes the prompt".
- **A refused timer.** If the CLI refuses the 5 s timer, the judgment ends at once and
  counts as a failure; 3 failures in a row start the 10-minute back-off, said in a toast.
  **Gate** — `tests/coach.test.ts`, "a deadline timer a hook refuses still lets the prompt
  through".
- **A model your organization refuses** (haiku off its allowlist) fails every judgment:
  each run of 3 starts a back-off with its toast, and the coach tries again 10 minutes
  later. **Gate** — `tests/coach.test.ts`, "says once that it is backing off".

The band and its buttons:

- **A drop needs a shown band.** Only after the marker blit proves the band is showing is
  a prompt dropped. Otherwise the flagged prompt passes with a toast,
  `Flagged (<kind>) but sent: <why>.`, where `<why>` is one of:
  - `the plugin panel above the prompt is hidden` — the band is collapsed;
  - `a survey holds the plugin panel above the prompt`;
  - `the plugin panel above the prompt is not showing the coach` — no band is drawn, or
    the marker blit is refused, denied for another reason or unanswered by the deadline.

  **Gate** — `tests/coach-view.test.ts`, "passes and toasts when the band cannot show".
  The marker-gated drop was walked live at 200x50 and 80x24 (**recorded**); the collapse
  toast was not re-walked with the marker (**recorded**).
- **The marker's column.** The marker is one blank column, column 0: beside the sprite,
  or before the gap where no sprite is drawn. **Recorded** (walk).
- **One band for every plugin.** The CLI draws one tree above the prompt box. While the
  coach draws, another plugin's band below it in hook order is not drawn; a plugin above
  it that draws hides the coach, and every flag then passes with the `not showing the
  coach` toast. No plugin in this marketplace draws there. **Recorded** (CLI types).
- **Beside task-runner's board.** The coach was never walked with `/task-board` open,
  though off-card judgments come during task-runner runs, when the board is most likely
  open; a docked pane narrows the band. **Recorded** as unobserved.
- **A band collapsed at idle.** ctrl+x ctrl+a acts only while the coach draws, so a band
  collapsed between prompts stays hidden and every later flag passes with the `hidden`
  toast, until a hold shows the hidden row and you re-expand it. **Recorded** (walk).
- **A band collapsed after a drop** hides the bubble until you re-expand it with ctrl+x
  ctrl+a; Up in the empty box also recalls the dropped prompt when prompt history is on. A
  collapsed band on a terminal drawing real Image pixels was never produced.
  **Recorded** (probe).
- **What does not end the bubble.** Local slash commands (`/help`, `/cost`): the CLI
  raises no prompt submit for them, so the bubble stays, and the plugin test that clears
  it on `/help` simulates a submit the live CLI never sends. **Recorded** (walk). `!`
  lines: the probe saw no prompt submit for `!echo`. **Recorded** (probe, one
  observation). Esc: on CLI 2.1.291-2.1.292 no hook sees Esc in the band.
  **Unenforceable.**
- **Digits.** While the bubble shows, a bare digit typed into the empty box presses a
  bubble button instead of typing; it flashes in the box for about 0.4 s before the fill
  or the mute clears it, which the CLI draws. **Recorded** (probe, walk).
- **The CLI's wording.** Collapse and alt detection match the deny wording of CLI
  2.1.291-2.1.292. If a later CLI rewords the collapse deny, a collapsed band still passes
  the prompt, with the vaguer `not showing the coach` toast. If it rewords the alt deny, a
  kitty or Ghostty session that gets no pixels keeps a blank Image instead of falling back
  to Raster, and the bubble shows without a sprite. **Recorded.**
- **Invisible characters.** The pass hash is taken from the text the box holds after a
  fill, so a code point the box strips (a zero-width space) does not defeat Send anyway;
  when a fill reports no text, the text given is hashed instead. **Gate** —
  `tests/coach-view.test.ts`, "2 fills your text and it passes unjudged".

The mascot:

- **Seen live once.** One maintainer screenshot (2026-10-07, 0.2.0, fullscreen, a terminal
  drawing Image pixels) showed the pane open beside the transcript with the idle sprite,
  so the open from the band's render hook works live. `Still` was not visible in it, and
  the blink, the refused close and the status line have not been seen live. **Recorded.**
- **The width floor** (144 columns, 110 once asked) is read from the CLI types, not
  measured. **Recorded.**
- **Beside `/task-board`.** Both are panes in one dock, one shown at a time (the CLI's
  pane roster). Whether a blink sent to the hidden coach pane is refused, which stops it
  until the pane is shown again, or drawn unseen was not observed. **Recorded.**
- **Two sprites during a hold.** While a prompt is held or flagged, the band's sprite and
  the pane's animate together. **Recorded.**

Sprite and install:

- **Pixels.** Real Image pixels are documented and probed for kitty and Ghostty only. The
  probe emulated their answers, and the CLI sent the pixels and their placeholder cells;
  real kitty or Ghostty pixels were never observed, nor how a real terminal scales the
  16x16 image. With `TERM=xterm-kitty` and no graphics answers the sprite is blank until
  it falls back to Raster (by 1.2 s in the walk). The Image outline is a fixed `#1f1a2e`,
  low contrast on a dark kitty theme (the Raster outline takes your text colour), and the
  badge shares the thinking dots' amber. **Recorded.**
- **Install by name.** `/all-plugins:install` leaving it out is a **gate** —
  all-plugins' `scripts/__tests__/all-plugins.test.sh`; `/stack-scan:suggest --full`
  leaving it out is **agent-graded** (a skill's rule).

## Standing

Standing: **gate** — `tests/coach.test.ts` and `tests/coach-view.test.ts` run under
`claude plugin test` in CI (the marketplace repository's `scripts/mod-tests.sh`) with the
judge stubbed, so a regression in a tested case fails the build; the plugin harnesses
`scripts/__tests__/coach-core-gate.test.sh`, `coach-core-judge.test.sh` and
`sprite.test.sh` hold eligibility, the cap and back-off, the judge's input caps and
prompts, verdict parsing and the sprite's pixels in CI. Untested here: the drawn screen
(the test kit records the tree and the blits, not the paint) and whether the judge
applies its rubric well, which is judge quality above. **Recorded**: a first live walk on
2.1.291 and 2.1.292 passed 8 of 8 screens, and a final one on the shipped code on 2.1.292
walked the marker-gated drop at 200x50 and 80x24, an opus verdict and `/init` ending the
bubble; the collapse toast was not re-walked with the marker. Those walks predate the
mascot; one screenshot has seen the pane since (The mascot, residuals).

- **The three rows in the root README's off-switch table: gate.** `scripts/generate.sh
  --check` fails the build when they drift from `userConfig` in `plugin.json`.
- **The Options table above: recorded.** All four columns are typed by hand here; nothing
  compares them with `plugin.json`. The gated copy is the root README's off-switch rows.
- **The state the coach keeps** (`types/index.d.ts`): **gate** for its keys — the host
  validator (`scripts/official-validate.sh` in CI) fails a `$.state` key the contract
  does not declare. Every plugin can read `$.state`, so the coach keeps there only hashes
  of the texts you marked to pass, the escalation and failure counts, the back-off time
  and the mute flag; the bubble's text lives in module memory, and nothing outlasts the
  session. **Recorded** for what goes into a declared key.
