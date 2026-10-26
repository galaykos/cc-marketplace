# Second import batch, 2026-10-26: code-video prompts, design-taste, Motion Studio

Three inputs, the same admission bar as `rationale/gamedev-design-import-2026-10-26.md`
(`measured-zero-shapes.md`: keep inverted facts, footguns, hard numbers and mechanisms; cut
doctrine, style catalogues and restatement). Nothing here is measured against a control arm.

## yihui-dev/awesome-opus5-5-videos @92aee2f

A list of 703 prompts people gave Claude Opus 5.5 to make videos as code (MIT for the list; its
README says every prompt belongs to its creator, so none is reproduced here). All 703 were read in
full by two readers, half each; 207 are partial (captions, not prompts), ~80 are games or
interactive pages rather than video, and the densest numbers come from one ~19-prompt template
lineage, so repeated wording is copying, not agreement.

| Finding | Where it landed |
|---|---|
| The dominant ask (~200 entries) is brief → rendered film with sound; design-kit:motion covers only "animate a static design" | new `design-kit:film` |
| Recurring delivery failures in follow-ups: a config file or plan instead of a video; "success because the code compiles" | film's order and anti-patterns: the deliverable is the muxed MP4 |
| ~20 prompts specify a stateless `seek(t)` (no CSS transitions, timers, carried state or unseeded random); motion's recorder steps a stateful fake clock | film's frame contract and hand-rolled `seek(t)` capture; motion keeps its clock for designed stages |
| `[0, duration)` with no duplicated end frame; subframes + `tmix`, counters on frame time | film's frame contract |
| SFX placed by measured peak; loudness re-measured after the AAC encode; ducking; music first | `film.py peak`, `film.py loudness`, film's sound section |
| Single-frame pop scans; decoded-MP4 frames, not page screenshots | `film.py pops`, `film.py sheet` |
| Chromium traps: `will-change` blur under camera scale, preserve-3d flattened by opacity/filter, `visibility: visible` inside a hidden parent, no Range on simple servers (design-kit's `serve.py` included), headless WebGL | film's `picture-and-sound.md`; the WebGL switch set re-read from Chromium's `docs/gpu/swiftshader.md` |
| Remotion and HyperFrames ship their own agent skills (verified on remotion.dev and the HyperFrames README, 2026-10-26); Remotion needs a company licence above 3 employees (its `LICENSE.md`) | plugin-scout Framework-native rows; film defers renderer APIs to them |
| Banned-effect lists, springs-not-linear, one continuous take, palettes and fonts | cut — style shape |

## madebymustafa/design-taste @c4a6bff

24 skills, read in full. The ten genre packs fix palettes, faces and chrome (warm paper + serif +
vermillion, broadsheet hairlines, mono labels, numbered `01 —` kickers) that
`craft-layer`'s `sameness-fingerprint.md` lists as category defaults to diverge from, and ship
hexes and font names that `ui-ux:theming-system` and craft-layer never ship. The fourteen craft and
code skills restate what ui-ux (a11y-audit, design-tokens, motion, theming), craft-layer (offer
contract, voice, scroll-orchestration), resilience (performance-tuning) and code-review already
carry. One tell was missing: **cards nested inside cards** — added to `sameness-fingerprint.md`
(craft-layer 0.59.1).

## The Motion Studio brief (supplied by the user)

Implemented as `design-kit:film` rather than a skill in `~/.claude/skills/`: it ships with the
plugin, so every project that installs design-kit gets it. Mapping:

| Brief section | Where |
|---|---|
| Brief fields and defaults, `brief.txt` logging, run mode | `film/references/brief-and-files.md`; ⏸ = one AskUserQuestion |
| Before you start: tools, `./film/`, facts, capture, 3-second draft | film Entry; `film.py doctor`; workspace `.design-kit/film/<slug>/` (gitignored, served) |
| Four roles | `film/references/roles.md`; the reviewer's blindness is instructed, not enforced |
| X rules, picture, sound | film SKILL + `picture-and-sound.md`; also design-kit:motion's X MP4 now opens loaded |
| Self-check and ledger | `film.py check --ledger --round` (facts, holds, sync, contrast, palette, safe area, overlap, probe) |
| Delivery | film Delivery; `film.py sheet --frames` for the contact sheet |
| "Save as a skill with the capture, music, loudness and check scripts" | `scripts/film.py` (+ `film.test.sh`); capture is the renderer's, or the `seek(t)` loop |

Residuals, stated: the five ffmpeg-dependent harness cases skip where ffmpeg is absent and were
not run on the machine this was written on; beat detection is an energy-flux tracker, not a
learned model, and reads a fast track as half-time without `--bpm-hint`; nothing here renders a
film end to end in CI.
