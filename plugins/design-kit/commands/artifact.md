---
description: Make one self-contained HTML artifact from a page, a markdown file, a folder or a brief — versioned in a local gallery on the design-kit preview URL; share on the LAN, to a pages branch, or as a zip only when you say so
argument-hint: "[file.html | file.md | dir | brief] [--name slug] [--zip]"
---

Load the `artifact` skill (this plugin) and follow it exactly. Then act on `$ARGUMENTS`:

1. **Resolve the input.** A path to `.html`, `.md`, or a directory holding `index.html`
   is the source as-is. Anything else is a brief: pick a pattern from the skill's
   `references/patterns.md`, and write the page from `skills/artifact/assets/page-shell.html`
   into `.design-kit/artifacts/.src/<slug>/index.html` with real content from this session.
   `--name <slug>` names the artifact; otherwise the file's basename or a slug of the
   brief's first words. If `design-system/DESIGN-SYSTEM.md` exists, apply its tokens to
   the shell before writing content.
2. **Bundle.** `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-bundle.py <source> --name <slug>`
   (add `--zip` when asked). Read every `network:`, `unresolved-link:` and `WARN:` line
   back to the user in one short list; fix unresolved links before continuing.
3. **Serve.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh` (idempotent), then print
   `http://127.0.0.1:8124/artifacts/<slug>.html` and the gallery `http://127.0.0.1:8124/`.
   State the version (`v<N>`) and that the page reloads itself on re-bundle.
4. **Offer sharing once**, via AskUserQuestion with these options in this order:
   "Keep it local (Recommended)" · "Open to my network (LAN)" · "Publish to a pages
   branch" · "Zip it". On LAN: `preview.sh --lan`, print the LAN URL and say any device
   on the network can open it while the server runs. On pages: run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-publish.sh <artifact>` without `--push`,
   read back the branch, remote and expected URL, ask "Push it?" as a second question,
   and only on yes re-run with `--push`. On zip: re-bundle with `--zip` and name the file.
5. **Report**: path, version, URL, what was inlined, what still needs the network,
   what was shared and where. Nothing left the machine unless step 4 said so.
