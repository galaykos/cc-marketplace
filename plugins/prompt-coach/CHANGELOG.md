# Changelog

All notable changes to the `prompt-coach` plugin.

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
