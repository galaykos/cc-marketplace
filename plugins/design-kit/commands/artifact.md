---
description: Make one self-contained HTML artifact from a page, a markdown file, a folder or a brief — versioned in a local gallery on the design-kit preview URL; share on the LAN, to a pages branch, or as a zip only when you say so
argument-hint: "[file.html | file.md | dir | brief] [--name slug] [--zip]"
---

Load the `artifact` skill (this plugin) and follow it exactly. Every script call goes
through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"`; run `dk.sh check` first and
repeat its one line. Then act on `$ARGUMENTS`:

1. **Resolve the input.** A path to `.html`, `.md`, or a directory holding `index.html`
   is the source as-is. With NO argument, read `.design-kit/workshop.json` and offer
   (AskUserQuestion): "A bring-back page of the last pick (board, artboard, knobs,
   text edits, with a Copy-as-prompt control)" when a `board` entry exists / "Share
   the last deck as an artifact" when a `deck` entry exists / "A page from a brief".
   Anything else is a brief: pick a pattern from the skill's `references/patterns.md`
   and write the page from `skills/artifact/assets/page-shell.html` into
   `.design-kit/artifacts/.src/<slug>/index.html` with real content from this session.
   `--name <slug>` names the artifact; otherwise the file's basename or a slug of the
   brief's first words. If `design-system/DESIGN-SYSTEM.md` exists, apply its tokens.
2. **Bundle + serve:** `dk.sh bundle <source> [--name <slug>] [--zip]`. It prints
   `network:`, `unresolved-link:` and `WARN:` lines, then `artifact=… vN` and `url=`.
   Read the findings back to the user in one short list; fix unresolved links before
   continuing. Give the URL and the gallery base URL; say the page reloads on re-bundle.
3. **Offer sharing once**, via AskUserQuestion, in this order: "Keep it local
   (Recommended)" · "Open to my network (LAN)" · "Publish to a pages branch" · "Zip it".
   LAN: `dk.sh share <artifact> --lan`, print the URL and say any device on the network
   can open it while the server runs (a pick made from there is not recorded). Pages:
   `dk.sh share <artifact> --pages` without `--push`, read back the branch, remote and
   expected URL, ask "Push it?" as a second question, and only on yes re-run with
   `--pages --push`. Zip: `dk.sh share <artifact> --zip` and name the file.
4. **Report**: path, version, URL, what was inlined, what still needs the network,
   what was shared and where. Nothing left the machine unless step 3 said so.
