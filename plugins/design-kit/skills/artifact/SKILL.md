---
name: artifact
description: Use when session output is easier to look at than to read — an annotated diff, options side by side, a dashboard from data already pulled, a live checklist — or the user asks for an artifact, a shareable page, or to bundle a page. One self-contained HTML file, versioned in a local gallery, shared only on explicit consent (LAN, a pages branch, or a zip). Owns the bundling and share rules; page content is yours.
argument-hint: "[file.html | file.md | dir | brief] [--name slug] [--zip]"
---

## Entry: /design-kit:artifact

Run this section only when a new artifact starts — the user typed `/design-kit:artifact`
or asked for a new one; when loaded mid-task (after an edit, or to review a change), skip
to the next section.

Every script call goes through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"`; run
`dk.sh check` first and repeat its one line. Then act on `$ARGUMENTS`:

1. **Resolve the input.** A path to `.html`, `.md`, or a directory holding `index.html`
   is the source as-is. Typed with NO argument (`/design-kit:artifact` alone), read
   `.design-kit/workshop.json` and offer (AskUserQuestion): "A bring-back page of the
   last pick (board, artboard, knobs, text edits, with a Copy-as-prompt control)" when a
   `board` entry exists / "Share the last deck as an artifact" when a `deck` entry exists /
   "A page of this session's output" when there is output to page / "A page from a brief".
   Loaded by the model with content already in hand (a diff, a report, a table), that
   content is the brief — go to Building one.
   Anything else is a brief: pick a pattern from this skill's `references/patterns.md`
   and write the page from `assets/page-shell.html` into
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

## What an artifact is here

One `.html` file under `.design-kit/artifacts/` that a browser renders with nothing
beside it: every stylesheet, script, image and font inlined, no backend, no route but
itself. It is served on this plugin's preview URL (gallery at `/`, live reload) and it
stays on this machine until a share step is chosen. The bundler
(`scripts/artifact-bundle.py`) makes the file; you make the page.

Standing, per rule: the bundler's checks (inlining, UTF-8, stamp, versions, network
report, unresolved-link report, 16 MiB warning) are **gates** — a harness drives each.
Page quality — hierarchy, honesty of the data shown, restraint — is **agent-graded**.
Reading comments left on a page is **out of scope**: nothing here has a comment
channel, and a page cannot grow one by wishing.

## When a page earns it, and when it does not

A page earns existence when the reader must compare, scan, or interact: a diff with
reasoning in the margin, three layouts beside each other, a table of forty rows the
reader will sort by eye, a checklist that changes as work proceeds. Terminal text wins
for a verdict, a stack trace, one number, or anything under ~15 lines. Do not make a
page because the output is long; make it because it is visual or comparative. A page
costs more tokens than the same content as text — inline CSS, control scripts and
especially images — so leave out interactivity nobody asked for.

## The rules the bundler cannot enforce for you

- **Write real content.** The page shows data from THIS session — the actual diff,
  the numbers already pulled, the options already drafted. Placeholder rows and
  invented figures are a fabricated report with a nicer font.
- **Diagrams as SVG or HTML, never raster.** A screenshot embedded as a data URI is
  the usual reason a page crosses 16 MiB and the least legible thing on it.
- **Summarise big data; do not inline it.** Forty rows render; four thousand do not
  read. Aggregate, then offer the full set as a download only if asked.
- **One page, in-page anchors.** A relative link to another file is dead once bundled;
  the bundler reports each one. Sections link with `#ids`.
- **No external requests unless declared.** The bundler leaves `https://` references
  in place and lists them as `network:`. Say in the reply which hosts the page needs;
  a page with none works offline and on the LAN without surprises.
- **Design system first.** If `design-system/DESIGN-SYSTEM.md` exists, its colours,
  type and radius replace the shell's `:root` values before any content. The shell's
  look is a fallback, not the project's.
- **Accessibility floor.** Headings in order, a visible focus ring on any control,
  colour never the only signal (the shell's `.pill` classes carry a word), motion only
  behind `prefers-reduced-motion: no-preference`.

## Building one

1. Start from `assets/page-shell.html` (`<!-- SLOT: title -->`, `<!-- SLOT: body -->`).
   Pick a pattern from `references/patterns.md` — walkthrough, compare, dashboard,
   checklist, bring-back — or combine two, never five.
2. Write the page to a scratch path (`.design-kit/artifacts/.src/<slug>/index.html`
   with any local assets beside it).
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh bundle <source> [--name slug]` bundles once,
   starts or reuses the preview and prints the bundler's `network:`, `unresolved-link:`
   and `WARN:` lines, then `url=`. Fix every unresolved link and decide each network line
   on purpose, re-bundling after a fix; give the user that URL and the
   gallery base URL. The page reloads itself when re-bundled.
4. Revising means re-bundling: the bundler keeps `v1`, `v2`… under
   `.design-kit/artifacts/.versions/<slug>/` and appends to `<slug>.versions.json`.
   Never edit the bundled file by hand; edit the source and re-run.

A `.md` input renders through the shell with a small converter (headings, paragraphs,
one-level lists, blockquotes, rules, fenced code, pipe tables, links, images, inline
code, bold, italic). Nested lists, reference links, footnotes and setext headings are
not supported; raw HTML passes through. Say so if the source uses them.

## The share ladder — each step is a question, default "keep it local"

Ask with AskUserQuestion, first option "Keep it local (Recommended)", before any of:

| step | what leaves the machine | how | say first |
|---|---|---|---|
| LAN | the page, to anyone on the same network while the server runs | `dk.sh share <file> --lan`, then print the URL | "any device on this network can open it; stop with `dk.sh serve --stop`" |
| Pages branch | the page, committed and pushed to `<remote>/design-kit-pages` | `dk.sh share <file> --pages` (dry run) → confirm → `--pages --push` | the branch, the remote, that Pages must be enabled by the user, the expected URL |
| Zip | nothing; a file beside the artifact | `dk.sh share <file> --zip` | where it landed |

The publish script works in a scratch worktree and never touches the current branch
or working tree; it pushes only with `--push`, which is only passed after the user
said yes to the dry run's summary. It never force-pushes, never deletes, never enables
Pages, and adds no attribution trailer. There is no fourth path: if the user wants a
hosted URL without a git remote, say what this plugin cannot do and name the zip.

## Anti-patterns

- Making a page of prose that should have been three sentences.
- A dashboard with a chart of numbers the session never pulled.
- Editing `.design-kit/artifacts/<slug>.html` directly — the next bundle overwrites it.
- Publishing before the dry-run summary was read back and answered.
- Calling the host's remote Artifact tool from this flow; this plugin's artifacts
  are local by design, and the two galleries do not know about each other.
