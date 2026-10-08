# Changelog

All notable changes to the `prompt-coach` plugin.

## 0.3.2 — 2026-10-08

- **The pane closes, and the coach comes back.** 0.3.0's "the pane can no longer be closed" was wrong on CLI 2.1.294: refusing a person's close (answering `ui.close` without `next`, as the CLI types describe) closed the pane anyway (`rationale/2026-10-08-mods-ui-survey-and-pane-probe.md` §3). A close from the close mark or ctrl+x x now goes through, and while the display is `pane` the coach re-opens the pane 0.1 s later. The CLI seats that re-open only on a terminal 144 columns or wider; narrower, the pane waits undrawn until the terminal is widened. A plugin's close, such as the `/config` display switch, is not undone.
- **The toast says what happens.** "The coach stays" is now "The coach comes back", or "comes back at 144 columns or wider" when the re-open waits, followed by how to move or hide him in `/config`. It no longer names `CC_COACH_MASCOT`, so that it fits the toast box's three lines.
- Walked once live on 2.1.294 at 200 and 130 columns. The test kit cannot raise a close of either origin, so no test covers it.

## 0.3.1 — 2026-10-08

Fixes from a review of 0.2.0-0.3.0:

- **Switching the mascot away in `/config` now closes the pane.** A `/config` change reloads the plugin while its pane stays open, so after choosing `statusline` or `off` the old pane kept drawing, blinking and refusing its close with a toast asking for the setting already made. A display other than `pane` now closes a pane left open, and one other than `statusline` clears a status line left pinned, once, at the band's next draw; the pane draws nothing under any display but `pane`, and the close is refused only while the display is `pane`. The toast says `CC_COACH_MASCOT` takes a new session.
- **A frame still in flight no longer lands on a redrawn pane.** A tick waiting on its band blit when a judgment ended went on to blit the old thinking or talking frame over the pane's rest pose; each blit now re-checks the pose.
- **Docs:** Esc never closed the pane (it is not opened with `closeOnEscape`), so 0.3.0's "Esc shows the toast" is withdrawn; the blink costs two blits every 4 s, not one; `CC_COACH_MASCOT`'s `0`/`false` rule is stated beside the other variables. Six new tests, and the refused-blink test now proves the blink resumes after a redraw.

## 0.3.0 — 2026-10-07

- **Pick where the mascot lives.** `cc_coach_mascot` / `CC_COACH_MASCOT` is now `pane` (the
  default), `statusline` or `off`. `statusline` pins a text face under the prompt in every
  renderer: `(^_^) coach` at rest, `checking…` during a hold, the flag's kind and reason
  while the bubble shows. The variable's `0` and `false` still mean off.
- **The pane can no longer be closed.** Its close mark and ctrl+x x show a toast
  naming the setting instead; the refusal follows the CLI types and is not exercised by a
  test, since the test kit cannot raise a person's close.
- **Upgrading from 0.2.0.** A `/config` value of `false` for `cc_coach_mascot` no longer
  fits the option, and the CLI reads it as the default `pane`: set `off` again.

## 0.2.0 — 2026-10-07

- **A mascot pane.** In the fullscreen terminal UI (`"tui": "fullscreen"`) the sprite stays
  on screen in a pane titled `coach`, 18 columns wide, docked beside the transcript and
  opened once a session. It idles at rest, thinks while a prompt is held and talks while
  the band shows a bubble; the bubble and its buttons stay in the band. Under the default
  renderer no pane opens.
- **A blink.** At rest the mascot blinks every 4 s; `s: Still` in the pane stops it for the
  session.
- **Option.** `cc_coach_mascot` (`CC_COACH_MASCOT`, on) turns the mascot pane off without
  touching the judging; `CC_PROMPT_COACH=off` turns both off.
- Proven in the test kit only; no live walk has seen the pane.

## 0.1.0 — 2026-10-07

- **First release: a prompt coach at Enter, as a hooks module (Claude Code ≥ 2.1.291).**
  `hooks/coach.ts`, the only entry under `modules` in `hooks/hooks.json`, holds an
  eligible prompt (typed in this terminal, no attachments, not led by `/`, `!` or `#`, at
  least 4 tokens or 16 non-space characters) for up to 5 s while haiku judges it and, on a
  flag, the standby model confirms. Only a confident flag the band can show is dropped,
  checked by a 1x1 Raster marker blit: the box is left empty and the band above it shows
  the sprite, your text, the reason and a rewrite. Everything else, the coach's own
  failures included, passes the prompt untouched.
- **What it flags.** Unclear (nobody could act on it; with `ambiguous` sensitivity, also
  scope open to different readings), contradicts an earlier turn, and, during a
  task-runner run on this branch, off-card and reopens a decision of the run's spec.
  The judge is told that skipping a phase is never a conflict; whether it obeys is judge
  quality, unmeasured.
- **The bubble.** Buttons first: `1` fills the box with the rewrite and `2` with your
  text, and either filled text passes unjudged whenever it is sent again this session;
  `3` mutes the coach for the session with a toast. The coach never submits. A band under 8 rows or 70 columns draws no
  sprite. A collapsed band, one a survey holds or one not drawing the coach passes the
  flagged prompt with a toast.
- **The sprite.** 16x16 first-party pixel art drawn in code, idle, thinking and talking:
  an Image on kitty and Ghostty outside tmux, Raster for the session once the CLI draws
  the Image as its alt, and Raster everywhere else.
- **Options.** `cc_prompt_coach` (`CC_PROMPT_COACH`, on), `cc_coach_model`
  (`CC_COACH_MODEL`, `sonnet` or `opus`, default `sonnet`) and `cc_coach_sensitivity`
  (`CC_COACH_SENSITIVITY`, `unactionable` or `ambiguous`, default `unactionable`); the
  variable beats the option. Fixed in code: haiku as the first pass, the 5 s deadline, 10
  standby checks a session, a 10-minute back-off after 3 failures in a row.
- **Cost and install.** A haiku call per eligible prompt and a standby call per flag, at
  most 10 a session; `/cost` shows none of it. Bulk installs leave it out:
  `/all-plugins:install` and `/stack-scan:suggest --full` skip it.
- **Where it runs, residuals named.** Below CLI 2.1.291, in a session the desktop app
  draws on and in one with no terminal, every prompt passes (both covered by
  `tests/coach.test.ts`); an organization's `allowManagedModsOnly` refuses the module
  (from the CLI's mod documentation, not measured), and with no `tool.call` hook the
  2.1.287 caveat does not apply. The README states every residual with its standing, the
  unmeasured judge quality included (the tests stub the judge). `tests/coach.test.ts` and `tests/coach-view.test.ts` run under
  `claude plugin test`, and `types/index.d.ts` declares the session state the coach keeps.
