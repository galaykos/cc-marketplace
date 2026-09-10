# Changelog — theme-design

Consumer-facing changes only. Newest first.

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
