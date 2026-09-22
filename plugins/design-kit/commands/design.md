---
description: Draft 2-4 UI directions for a brief as artboards on one local canvas — editable text, adjustment knobs, pick-and-copy back as a prompt — then hand the pick to implementation
argument-hint: "[brief] [--screens 2-4] [--device phone|tablet|desktop] [--theme design-system/tokens.json]"
---

<!-- host-ok --> Local twin of the host's `/design`: same artboard idea, files under
`.design-kit/boards/`, no upload, no sign-in.

Draft a design board for $ARGUMENTS. Invoke the `design` skill of this plugin and follow it
exactly; the rules below are the entry sequence, not a substitute for the skill. Every
script call goes through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"`.

1. `dk.sh check` first; repeat its one line. Then parse `--screens` (default 3, clamp
   2–4), `--device` (default `desktop`; a brief that says mobile, app, or phone →
   `phone`), `--theme` (default `design-system/tokens.json` when it exists, else the
   shell's neutral defaults). With an empty brief, read `.design-kit/workshop.json`:
   if it holds a `brief`, offer it; otherwise ask in a single round what is being
   designed, for whom, and the one thing it must make easy.
2. Consent, once per session, via AskUserQuestion — the FIRST option is the read-back
   when `.design-kit/decisions.jsonl` holds an unread row: "I picked on the board —
   read it" (run `dk.sh decision --latest --consume`, treat every line as a requirement,
   go to step 5) / "Draft the board (Recommended)" / "ASCII sketches in chat instead" /
   "Stop". ASCII → wireframes in chat and skip the rest.
3. Write the spec to `.design-kit/boards/<slug>.spec.json`, then `dk.sh board <spec>
   [--device D]`. It builds, starts or reuses the server, and prints `board=` and
   `url=`. Give the user the URL plus one line per artboard: number, title, trade-off.
   If the builder exits 2, fix the spec it names and rebuild; never bypass it.
4. Ask for the pick (AskUserQuestion): "Read my pick from the board" · pick artboard N
   · revise N · add a direction · done for now. The board records every pick, knob
   move and text edit to the server as it happens; "Read my pick" runs
   `dk.sh decision --board <board> --consume` and prints the same prose the board's
   "Copy edits as prompt" button gives — either path, every line is a requirement.
   On revise/add, edit the spec, rebuild in place (the open tab reloads itself), ask again.
5. On a pick: `dk.sh decision --record "board <title>, artboard N (<name>), <knobs>,
   text edits: <n>"` so `design-system/DECISIONS.md` carries it; then offer
   `/design-kit:in-codebase` with no arguments (it reads the same pick — Recommended),
   or the project's UI build command, or `dk.sh export <board> --png|--pdf` for someone
   outside the session. Stop the server only if this command started it.
