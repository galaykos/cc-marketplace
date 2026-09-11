# Changelog — theme-design

Consumer-facing changes only. Newest first.

## 0.1.1

### Fixed
- `pending-events.sh` cut its 3,000-char injection mid-JSON and still advanced the
  cursor past the cut, so any gesture past roughly the seventh in a batch was lost
  from both surfaces. It now prints whole events only, advances the cursor to the
  last one printed, and says how many stay queued for the next poll. Gated by the
  harness.
- Editor: the first click after a drag dropped on a sibling was swallowed (the
  `justDragged` guard waited for a `click` the browser never fires when mousedown
  and mouseup hit different elements). The guard now expires with the mouseup.
- Editor: a colour pick reported `computed` AFTER the preview, so the skill's
  nearest-token match saw the new colour. `describe()` is captured before the
  first preview frame.
- Server: `/favicon.ico` answers 204 when the root has none, instead of logging a
  404 in every session's console.

### Added
- Editor panel follows `prefers-color-scheme: dark`.
- Event protocol: `page: "/"` is `pages/index.html` in html mode, stated.

## 0.1.0

### Added
- `/theme-design:init` — opens a browser design session: a stdlib Python server
  (`server/serve.py`) serves standalone HTML prototypes (`html` mode) or proxies the
  project's dev server (`proxy` mode) with a chat + direct-manipulation editor
  injected into every page. Claude long-polls `/__td/next` from the running session,
  applies gestures to real files, replies through `/__td/reply`, and the page
  live-reloads.
- `/theme-design:export` — tokens.css (light + dark, contrast-checked), prototype
  pages, a design brief from the session's decisions and transcript, and an
  optional direct write into the project's theme file.
- `design-session` skill with the event protocol and export targets as references,
  a shadcn-named `tokens.css` starter and a token-only page shell.
- `pending-events.sh` UserPromptSubmit hook — injects unconsumed browser events into
  a terminal turn while a session is running; silent otherwise.
- Harness `scripts/__tests__/serve.test.sh` (26 assertions) covering the bridge
  contract, editor injection, CSRF header, traversal refusal, SSE, proxy injection
  and Location rewriting, and the status/stop lifecycle.
