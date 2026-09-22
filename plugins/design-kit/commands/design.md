---
description: Draft 2-4 UI directions for a brief as artboards on one local canvas — editable text, adjustment knobs, pick-and-copy back as a prompt — then hand the pick to implementation
argument-hint: "<brief> [--screens 2-4] [--device phone|tablet|desktop] [--theme design-system/tokens.json]"
---

<!-- host-ok --> Local twin of the host's `/design`: same artboard idea, files under
`.design-kit/boards/`, no upload, no sign-in.

Draft a design board for $ARGUMENTS. Invoke the `design` skill of this plugin and follow it
exactly; the rules below are the entry sequence, not a substitute for the skill.

1. Parse `--screens` (default 3, clamp 2–4), `--device` (default `desktop`; a brief that
   says mobile, app, or phone → `phone`), `--theme` (default `design-system/tokens.json`
   when it exists, else the shell's neutral defaults). If the brief is empty, ask for
   one in a single round: what is being designed, for whom, and the one thing it must
   make easy.
2. Consent, once per session, via AskUserQuestion: "Draft the board (Recommended)" /
   "ASCII sketches in chat instead" / "Stop". ASCII → draw the directions as wireframes
   in chat and skip the rest. Stop → stop.
3. Write the spec to `.design-kit/boards/<slug>.spec.json`, build it with
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/board-build.py <spec>`, start or reuse the
   server with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh`, and print the board URL
   plus one line per artboard: number, title, trade-off. If the builder exits 2, fix the
   spec it names and rebuild; never bypass it.
4. Ask for the pick (AskUserQuestion): pick artboard N · revise N · add a direction ·
   done for now. On revise/add, edit the spec, rebuild in place — the open tab reloads
   itself — and ask again. When the user pastes the board's "Copy edits as prompt" text,
   treat every line of it as a requirement.
5. On a pick: offer `/design-kit:in-codebase` with the artboard, knob values and text
   edits carried over (Recommended), or the project's UI build command, or export via
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/board-export.sh <board> --png|--pdf` for someone
   outside the session. Stop the server only if this command started it.
