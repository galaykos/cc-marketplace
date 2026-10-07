# Prompt coach — engine behaviour probe (2026-10-07)

Purpose: settle the engine behaviour the prompt-coach spec
(`taskmaster-docs/specs/2026-10-07-prompt-coach-mod.md`, A8 and D18) rests on before
the module is written, and check the spec's kill-triggers (a)-(e) against measured
evidence.

**Standing: `recorded`** — a one-time measurement; nothing re-runs it.

## Probe plugin

Throwaway, built under `mktemp -d`, never in the repo. Below, `$P` is that directory,
`/tmp/probe-coach.RmloiN`.

- `$P/plugin/.claude-plugin/plugin.json` — `probe-coach` 0.0.1, `"types": "./types/index.d.ts"`.
- `$P/plugin/types/index.d.ts` — `PluginState['probe-coach']`: `band` (mode, original, reason, rewrite), `muted`.
- `$P/plugin/hooks/hooks.json` — `{"modules":["./probe.tsx"]}`.
- `$P/plugin/hooks/probe.tsx` — one unmatched `session.start` (version, surfaces, log flush timer),
  one unmatched `prompt.submit` and one `ui.render` matched `{ component: 'AbovePrompt' }`, each
  with `.catch(($, e, next) => next(e))`. A prompt starting `coach` sets the band to
  `thinking`, animates a 16x8 `Raster` and a 16x8 `Image` with `$.ui.blit` every 150 ms,
  reads `$.session.messages()`, builds a judge input, calls `$.model.complete` on `haiku`
  (rubric system prompt, `effort: 'low'`, `maxTokens: 8`, `timeoutMs: 4000`, an
  `AbortController` signal) then on `sonnet` (strict-JSON verdict prompt, `maxTokens: 400`,
  `timeoutMs: 20000` so the latency is not cut at the deadline), sets the band to
  `speaking` and returns `{ drop }`. A `[chain]` prompt also awaits one Raster blit after
  the verdict and logs the time from hook entry to that point; `[opus]` then repeats the
  standby request on `opus`, after the timed span. The band draws three plain Buttons on
  hotkeys 1, 2, 3 whose `onPress` calls `$.prompt.fill` (1 the rewrite, 2 the original) or
  sets `muted` (3), after the text by default or before it with `PROBE_BUTTONS_FIRST=on`;
  `PROBE_WRAP=on` wraps the texts. On `desktop` it draws an `Svg` with `isInteractive`. A
  blit deny during the hold, or a band last drawn with `hasSurvey`, passes the prompt and
  calls `$.ui.toast`. With `PROBE_MODELS` unset the hold is a 1.8 s `$.clock.sleep` and
  no model is called.
- `$P/plugin/tests/probe.test.ts` — five `claude plugin test` cases (pin row).

Live sessions were driven with python `pexpect` and read with the `pyte` VT emulator
(0.8.2, wheel fetched into `$P`), in a fresh git repo `$P/work`, main model
`--model haiku`, every hook event appended to a JSONL log by the module.

## Host and CLI versions

- Host: Ubuntu 26.04, GNOME on Wayland. Terminal emulators installed: `ptyxis`, `xterm`;
  `which kitty ghostty wezterm foot` all printed `not found`; iTerm2 is macOS-only. The
  agent session itself had no `TERM` (it runs under the desktop app). Every live session
  ran in a 200x50 pexpect pty with `TERM=xterm-256color` unless a row says otherwise.
- The agent's environment carried `CLAUDE_CODE_CHILD_SESSION`, which the sessions
  inherited: the CLI then saves no transcript and keeps no prompt history (Up recalled
  nothing). The history check below unset it.
- 2.1.292 — installed `claude --version` printed `2.1.292 (Claude Code)`.
- 2.1.291 — `npx -y @anthropic-ai/claude-code@2.1.291 --version` printed `2.1.291 (Claude Code)`;
  live sessions ran its binary from the npx cache with `DISABLE_AUTOUPDATER=1`. The
  installed CLI was not replaced.
- Aliases: `/model` on 2.1.292 lists `Opus · Opus 5.5`, `Sonnet · Sonnet 5.5`,
  `Haiku · Haiku 4.5` (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-4-5` in the
  CLI's model catalog). `$.model.complete` resolves an alias "like a `--model` value"
  (types index.d.ts:6142); its result does not name the model, so the resolution is read
  from `/model`, not from the calls.

## Results

| probe | verdict | evidence |
|---|---|---|
| drop-empty-box | yes | Yes when the button row lies inside the band's scroll window (types index.d.ts:10196). 42 live drops on 2.1.292 and 2.1.291: `$.prompt.read()` 900 ms after each drop returned `{"text": "", "cursor": 0}` every time; the transcript row became `● Prompt dropped by a hook: probe-coach held this prompt (set CC_PROMPT_COACH=off to stop)` and the band drew `You wrote:`, `Suggest:` and `1: Use rewrite  2: Send anyway  3: Mute` over an empty `❯`. 18 bare digits typed into the empty box with the button row in view pressed the band Buttons: every `$.prompt.fill` answered `isFilled: true` (15 `use`, 3 `send`; e.g. `{"label": "use", "isFilled": true, "text": "REWRITE: fix it -- name the file and what done means"}`) and the next screen showed the text in the box; 1 more pressed Mute (`{"ev": "mute"}`). Same on 2.1.291 (2 drops, `use` and `send` both `isFilled: true`). At 80x24 with a 202-char prompt and a wrapped 250-char rewrite the band showed 3 body rows and `↓ 10 more` (render props `maxRows: 4, bodyRows: 3`): with the button row last, as the visual contract draws it, `2` was typed into the box (`❯ 2`, no fill); with the row first, `2` pressed Send anyway and the box held the 202-char text. With the band collapsed a digit also went into the box (`❯ 1`, 3 times): see band-unavailable. |
| band-unavailable | partial | Collapsed, terminal: ctrl+x ctrl+a over a shown bubble drew `▸ plugin panel hidden · ctrl+x ctrl+a or click to show`; the `AbovePrompt` render hook kept being raised with unchanged props (`maxRows: 17, bodyColumns: 195`, no collapse field). The one proven detector is a denied Raster blit: every one during a collapsed hold was denied, `no Raster of its own is mounted under key "sprite" in above-prompt` (43 of 43, two sessions), against 0 of 664 denied with the band expanded (all 26 sessions). Using that deny, the probe passed the prompt and its `$.ui.toast` drew top-right (`probe-coach: the band cannot show (collapsed or a survey), prompt passed`) and the turn ran. Image blits during the same collapsed holds were denied too (`no Image of its own is mounted under key "img"`), but only under `TERM=xterm-256color`, where the Image draws its alt anyway; a collapsed band on a terminal that draws Image pixels was not tried. Desktop: the blitted elements are terminal-only (`Raster`, `Image`), so this detector does not exist there, and no other was found. Survey: with `CLAUDE_FORCE_DISPLAY_SURVEY=1` the band showed `How is Claude doing this session? (optional)  1: Bad 2: Fine 3: Good 0: Dismiss` and the render hook saw `hasSurvey: true`; typing the prompt flipped it to `hasSurvey: false` before Enter (the typed text arrived intact), so a survey holding the band at the moment of Enter was never produced. |
| hold-draw | yes | During every hold the render hook drew the `thinking` band (`PROBE checking your prompt…`, render prop `isWorking: true`) while the transcript showed the held text with the engine spinner (`✢ Thinking…`); all 664 Raster blits in expanded-band holds were accepted (`deny: null`), and replaying the 2.1.292 main session's raw output through pyte showed the sprite's first row change colour pattern 33 times during the holds. Raster colours were quantised to the 256-colour palette under `TERM=xterm-256color` without `COLORTERM` (`ffcc00` drawn `ffd700`, `3366ff` drawn `5f5fff`). |
| cost | no | Coach spend does not appear in `/cost`. Main session: 14 `$.model.complete` calls (12 answered) then `/cost` read `Total cost: $0.0000`, `Usage: 0 input, 0 output, 0 cache read, 0 cache write`, `Total duration (API): 0s`. Control session: after one main Haiku turn `/cost` read `Total cost: $0.0731`; after a haiku + sonnet coach pair (437 + 716 input, 8 + 154 output tokens) it still read `$0.0731`, and `$.session.usage().cost.usd` was `0.073118` before and after the pair. The only meter is the `usage` on each `$.model.complete` result. |
| image-terminals | partial | No real iTerm2, WezTerm or foot on this host (above), so pixels in those terminals were not observed. What the CLI decides was probed by emulating each terminal's identity and answers in the pty: 2.1.292 sends `XTVERSION` and DA1 and, once they are answered, a kitty graphics query (`i=31,s=1,v=1,a=q,t=d,f=24`). With a graphics `OK` reply and `XTVERSION` `kitty(0.39.1)` or `ghostty 1.1.3`, the Image blits were accepted, the first of the session included (the query was sent at byte 96 of the output, before the first prompt at byte 4478), and the CLI transmitted pixels (13 `a=T,U=1` kitty graphics commands, 256 U+10EEEE placeholder cells). With the same `OK` reply and `XTVERSION` `WezTerm 20240203-110809-5046fc22`, `iTerm2 3.5.10` or `foot(1.20.2)` every blit was denied: `the Image draws its alt here: the terminal draws no placeholder images (probe: graphics reply OK, terminal WezTerm …)` (likewise `iTerm2 3.5.10`, `foot(1.20.2)`). `TERM=xterm-kitty` with no answers: no graphics query was sent, and every Image blit, the first included, was denied `(env: terminal=kitty, not asked yet, no answer)`; with `TMUX` set: `(env: inside tmux or screen)`; plain `xterm-256color`: `(env: terminal=xterm-256color, not asked yet, no answer)`. So the engine itself keeps iTerm2, WezTerm and foot on the alt, and `TERM=xterm-kitty` alone does not get pixels: the terminal's answers decide. No surviving no-answer run set `TERM_PROGRAM`, so this record claims nothing about `TERM_PROGRAM` on its own. |
| origin-kinds | partial | Typed at an idle prompt: `{"origin": {"kind": "composer"}, "wait": false, "turnId": null}` (every coach prompt, both CLIs). Typed during a running turn with plain Enter: `{"kind": "composer"}, "wait": false, "turnId": "063e0095-…"`. Typed during a running turn with ctrl+x Enter: `{"kind": "composer"}, "wait": true, "turnId": "bea61b3d-…"`. As the types say, `composer` covers "Enter at the prompt, typed or queued, or a click on a transcript link" (index.d.ts:8813): the kind does not tell a queued prompt from a typed one. `turnId` (index.d.ts:9013) marks a submission made while a turn ran; `wait` (index.d.ts:9022) marks only an explicit `chat:queueSubmit` (ctrl+x Enter). A transcript-link click was not observed. Phone (Remote Control `bridge`) and desktop prompts were not reachable from here (no phone client attached; desktop below), so their kinds are unobserved. Local transcripts of desktop-app sessions stamp user entries `{"kind": "human"}`, the transcript's own taxonomy, which does not settle the hook's `e.origin.kind`. |
| desktop-fill | partial | Not run on the real desktop surface: the desktop app is running (`/usr/lib/claude-desktop/claude-desktop`, 2.9939.4) but has no automation channel (its command line carries no remote-debugging port; `xdotool`, `ydotool` and `wtype` are not installed; Wayland session), and loading the probe there would mean installing it into the person's live plugin configuration. What did run: `claude plugin test` mounting `AbovePrompt` on the `desktop` surface on 2.1.291 and 2.1.292 — the tree with `Svg isInteractive` validated against the desktop element table and pressing `use` called `prompt.fill` with the rewrite. That proves the tree, not the paint, the drop or the fill on the desktop. |
| latency-first | yes | Haiku first pass (Haiku 4.5; `/model` notes effort is not supported for Haiku, so `effort: 'low'` is dropped), `maxTokens: 8`, timed around `$.model.complete` inside `prompt.submit`. Judge input ~860-920 chars (420-437 input tokens), 2.1.292, n=6: 557, 573, 575, 598, 603, 615 ms, median 586.5 ms. Judge input 7,424 chars (2,105-2,111 input tokens), n=5: 605, 641, 643, 683, 747 ms, median 643 ms. Judge input 7,924 chars (2,265-2,271 input tokens), n=5: 613, 626, 646, 660, 678 ms, median 646 ms. The earlier aggregate of 14 (median 600.5 ms, max 747 ms) is the first two sets plus three calls not listed above: 597 ms (control session, 2.1.292) and 572, 554 ms (2.1.291). The reply was never one word at `maxTokens: 8` (`unclear\n\nThe prompt "coach fix it`), so the label is its first word. |
| latency-standby | yes | Sonnet standby (Sonnet 5.5), `maxTokens: 400`, `effort: 'low'`, strict-JSON verdict, 94-226 output tokens, every reply parseable JSON with `verdict`, `kind`, `confidence`, `reason`, `rewrite`. Call time alone: short input, n=6: 1582, 2024, 2161, 2180, 2236, 2240 ms, median 2170.5 ms; 7,424-char input, n=5: 1938, 1984, 2088, 2128, 2582 ms, median 2088 ms; 7,924-char input, n=5: 2222, 2235, 2311, 2494, 2675 ms, median 2311 ms. Sum of the haiku and sonnet call times only (no hook work, no Enter): short 2197-2838 ms, median 2736.5 ms; 7,424 chars 2543-3225 ms, median 2769 ms; the earlier aggregate of 14 (median 2770 ms, max 3315 ms) adds three sums not listed above: 2988 ms (control session; 597 + 2391) and 2860 ms (572 + 2288), 3315 ms (554 + 2761) on 2.1.291. Timed from `prompt.submit` hook entry to verdict ready (`$.session.usage`, `$.state.set`, `$.session.messages`, a 7,924-char judge input, haiku, sonnet, one awaited Raster blit), n=5: 2902, 2905, 2965, 3132, 3298 ms, median 2965 ms, headroom against 4 s median 1035 ms, min 702 ms; hook entry to the start of the judge input (`$.session.usage`, `$.state.set`) 5-11 ms, `$.session.messages` plus building the input under 1 ms, the blit 0-1 ms. Enter to hook entry, timed from the driver's keypress on the same clock: 75, 57, 56, 56, 56 ms, so Enter to verdict ready median 3021 ms, headroom 979 ms, min 645 ms. Opus (Opus 5.5) on the same request, n=5, run after each timed span: 1828, 2113, 2352, 3564, 3582 ms, median 2352 ms; with opus in sonnet's place each chain would read 2511, 2736, 2990, 4231, 4236 ms from hook entry, median 2990 ms (headroom 1010 ms), and 2 of 5 past 4 s. Abort: a `signal` aborted at 300 ms and a `timeoutMs: 300` both resolved `reason: "aborted"` in 301 ms and reported zero usage (billing not observed). |
| pin-2.1.291 | yes | `npx -y @anthropic-ai/claude-code@2.1.291 plugin validate --strict ./plugin`, run on the final probe: exit 0, `✔ Validation passed`, listing `hooks: session.start, prompt.submit, ui.render{component=AbovePrompt}` and `calls: $.clock.after, $.clock.every, $.clock.sleep, $.env.get, $.fs.read (via flush), $.fs.write (via flush), $.model.complete (via timed), $.prompt.fill, $.prompt.read, $.session.messages (via judgeInput), $.session.surfaces, $.session.usage, $.session.version, $.state.get, $.state.set, $.ui.blit, $.ui.resolve, $.ui.toast`, state `probe-coach.band, probe-coach.muted` declared. `npx -y @anthropic-ai/claude-code@2.1.291 plugin test ./plugin`: exit 0, `5 pass 0 fail` — drop after a haiku and a sonnet call that read `session.messages`; Raster and Image in the band blitted during the hold; the three Buttons, `send` filling the box; desktop `Svg isInteractive` with a fill; a denied blit passing the prompt with a toast. Negative control on 2.1.291 (drop answered `next(e)`, `isInteractive` removed): exit 1, `3 pass 2 fail`, the two cases those mutations target. 2.1.292 validate and test: also exit 0, `5 pass`. Live on 2.1.291 the drop, the empty box, both fills and both model calls behaved as on 2.1.292. |

## Recovering a collapsed bubble

Tested after a drop, band collapsed with ctrl+x ctrl+a (no model calls):

- (i) Re-expanding with ctrl+x ctrl+a brought the bubble back whole (`You wrote:`, `Suggest:`,
  `1: Use rewrite  2: Send anyway  3: Mute`), and `1` then filled the box
  (`{"label": "use", "isFilled": true}`, `❯ REWRITE: first stranded prompt alpha bravo charlie -- …`).
- (ii) Up in the empty box recalls the dropped prompt. With prompt history on
  (`CLAUDE_CODE_CHILD_SESSION` unset, `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE=1`), after one
  answered prompt and one dropped one, collapsed: the first Up showed
  `History 2/2 ❯ coach stranded prompt for the history check`, the second
  `History 1/2 ❯ Reply with the single word ok.` With history off (every other session,
  above) Up recalled nothing, not even a `/cost` or `!echo` line submitted earlier.

## Kill-triggers

- (a) After a drop the bubble's digit buttons cannot fill the box — not tripped, with a layout condition: with the button row in view, 18 of 18 digits pressed into the empty box filled it on 2.1.292 and 2.1.291. Two cases strand the person's text in the bubble. One is a collapsed band, 3 digits typed `1` into the box. That is what D15 guards: never drop what the coach cannot show; when the band cannot show (a survey holds it, or it is collapsed where detectable) the prompt passes and a one-line toast says why. A collapsed band was detected before the drop by the Raster blit deny. After a drop it is recoverable by re-expanding or by Up. The other is a button row scrolled out of the band's window. At 80x24, with the row last as the visual contract draws it, `2` was typed into the box. Placing the row first pressed the Button. The contract's layout is the user's to re-decide.
- (b) `$.model.complete` is refused or never resolves inside a `prompt.submit` hook — not tripped: 43 of 43 calls answered and 2 of 2 aborts resolved in 301 ms, on both CLIs, with no hook timeout.
- (c) The haiku first pass takes more than 2 s at the median — not tripped: median 586.5 ms (n=6), 643 ms at 7,424 chars (n=5), 646 ms at 7,924 chars (n=5), max 747 ms.
- (d) The sonnet standby's median time to a complete verdict leaves less than 1 s of the 4 s deadline — borderline, the user's call: not tripped on the hook's own clock, tripped by 21 ms counted from Enter. From `prompt.submit` hook entry to verdict ready, with the judge input near the 8,000-char cap, the median was 2965 ms, leaving 1035 ms: 35 ms above the line. The minimum headroom was 702 ms, and 2 of 5 chains left under 1 s. Adding the measured 56-75 ms from Enter to hook entry, the median is 3021 ms, leaving 979 ms. The first cycle's figure, which this record had called "counted from Enter", was only the sum of the two call times: medians 2736.5 and 2769 ms, leaving 1231-1264 ms, 231-264 ms above the line. Opus as the standby: median 2990 ms from hook entry (1010 ms left), 2 of 5 past 4 s.
- (e) An engine call the module needs fails `claude plugin validate --strict` or `claude plugin test` on CLI 2.1.291 — not tripped: both exit 0 for every engine call listed in the pin-2.1.291 row, and the tests fail when the drop or the Svg prop is mutated.

Outcome: (b), (c) and (e) are clear. (d) is borderline and (a) carries a layout condition; both go to the user before the module is built.

D18 outcome: the desktop's drop-then-fill and its prompt origin were not observed (desktop-fill, origin-kinds). D18 moves the desktop out of v1 only "if either fails"; neither failed and neither was seen, so keeping or dropping the desktop surface for v1 is the user's decision.

## Observed on the way, for the module and its README

- A dropped prompt leaves one `● Prompt dropped by a hook: <reason>` row in the transcript per drop, and never enters it: `$.session.messages()` returned 0 entries in sessions whose only prompts were dropped, 3 after one answered turn. It does enter the prompt history (Up recalls it).
- A collapsed band stays collapsed across later prompts until the person re-expands it.
- Every Image blit on a terminal that draws the alt is denied with the reason, so the engine's own pixel decision is readable at run time.
- A `!echo` bash-mode line did not reach the `prompt.submit` hook, and a model turn followed it (one observation).

## Model spend

45 `$.model.complete` calls from the probe, all on 2.1.292 except 4 on 2.1.291:

| alias | resolved (`/model`) | calls | input tokens | output tokens | list price per MTok (CLI catalog) | estimate |
|---|---|---|---|---|---|---|
| haiku | Haiku 4.5 | 19 | 25,686 | 152 | $1 in / $5 out (`haiku_45`) | $0.026 |
| sonnet | Sonnet 5.5 | 21 (2 aborted, zero usage reported) | 39,432 | 3,351 | $2 in / $10 out (`tier_2_10`) | $0.112 |
| opus | Opus 5.5 | 5 | 17,141 | 1,009 | $4 in / $20 out (`tier_4_20_cache_read_0_20`) | $0.089 |

About $0.23 at list price for the probe's calls, none of it visible in `/cost` (cost row).
Prices are the 2.1.292 binary's `pricing_tiers`, the table its `/cost` prices with; no
cache tokens were reported. Plus 9 main-session turns on Haiku 4.5 (cost control, queued
origins, survey, the passed prompt, the history control, and one that followed a `!echo`
line). `/cost` read $0.0731 after 1 turn and $0.0782 after 2 (control session) and
$0.0668 after 2 (survey session); the other 5 turns were not read. At most $0.0731 each
puts the 9 under about $0.51. The other 21 sessions made no model call from the probe.

## What this probe does not cover

- Real iTerm2, WezTerm, foot, kitty and Ghostty: the terminal side was a pty answering as
  each would; whether a real terminal answers that way was not observed.
- The desktop surface and the phone (`bridge`) origin: not reached (rows above).
- A survey present at the moment of Enter: the forced survey was dismissed by typing the
  prompt; a survey that appears mid-typing was not produced.
- A collapsed band on a terminal drawing Image pixels.
- Latency on a slower network or under rate limiting: 26 sonnet and opus calls from one
  host within 32 minutes.
- The runs were isolated from this repository's hooks but not from `~/.claude`: the
  person's installed plugins loaded beside the probe. No screen showed another plugin
  drawing in the band or dropping a prompt; their hooks were not otherwise separated.
