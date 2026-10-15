# Host changelog audit: Claude Code 2.1.281–2.1.300 (2026-10-15)

**What was checked.** Five Opus readers split the CLI changelog
(`anthropics/claude-code` `CHANGELOG.md`, entries 2.1.281 through 2.1.300) and checked it
against this repository. 2.1.300 was installed. The last whole-surface host review was
`host-features-2026-09-29.md`, which stopped at 2.1.284. About 1,745 entries were read, and
most of them were UI, IDE, cloud or provider fixes with no plugin surface.

**Before any change**, on 2.1.300:
- every plugin and the marketplace passed `claude plugin validate --strict`;
- all 14 mod suites passed `claude plugin test`.

**Standing of this document: `recorded`.** Each change below names its own standing in its
plugin's CHANGELOG.

## What misbehaved, and the fix

- **Subagent turns raise `turn.start` (2.1.299).** code-review's suggest mod and session-hud
  reset per-turn state on every `turn.start`, so a subagent starting mid-turn wiped the
  main loop's edit count and cost footer. This was measured: the footer read $0.03 where
  $0.08 was right. Both now ignore a `turn.start` that carries `agentId`. candor's badge
  handler only re-reads, so it needed nothing.
- **Background Bash is stopped at its `timeout`: 30 min by default, 2 h at most (2.1.285).**
  The audit first read this as hitting every session. 2.1.288 narrowed it to unattended
  sessions (`-p`, the Agent SDK, CI, cloud), and an interactive 2.1.300 session ran past it.
  The risk is therefore hands-off runs.
  - task-runner's behavioral gate now has a total cap (`BEHAVIORAL_GATE_TOTAL`, default
    6,600 s) and its callers pass `timeout: 7200000`. Its old worst case was 210 minutes.
  - The gate writes its deadline (start + total + 60 s) into `running.pid`, and candor holds
    while that deadline is ahead. Without a deadline, as with an older task-runner, candor keeps
    its 240-minute window, because the two plugins version independently.
  - The preview-server skills pass the timeout and re-check the port before each later pass.
  - When the host stops a call it sends TERM, then KILL about 1.4 s later, to the whole
    process tree. That was measured with TaskStop. `setsid -f` and double-forked children
    survive.
- **The built-in `code-review` reuses the last typed level (2.1.223) and `--max-findings` (2.1.288).**
  Only the typed slash path saves those values, not a Skill-tool call, so `/code-review:review`
  inherits the user's saved choice on purpose. `Checked:` now names the level and limit the
  built-in ran at.

## Claims that had gone stale

- **The Agent tool takes `effort` per call from 2.1.292.** About fifteen task-runner,
  taskmaster and craft-layer passages said it did not, as did the boost-hook text. They now
  say it does from 2.1.292, and that below it the agent's frontmatter is the only lever.
  task-runner's floors mod passes a workflow agent through below 2.1.300, where its model
  rewrite is ignored, and passes a resumed spawn through on every version.
- **secret-scanning's prompt guard.** Its guarantees grew release by release (2.1.295,
  2.1.296, 2.1.299, 2.1.300) while the mods floor stays 2.1.291. The README and `redact.ts`
  list each gap by version rather than raising the floor, because raising it would turn the
  guard off on every path below the floor.
  - Measured: the one-second failure grace still lets a result through on 2.1.300.
  - Measured: a Read of a UTF-16LE file with a BOM is decoded on 2.1.300.
- **The host validator does more than our docs said.** It now checks unquoted
  `${CLAUDE_PLUGIN_ROOT}` in hooks.json, MCP entries, `${user_config.*}` references, install
  names, component paths and mod gating hooks. `official-validate.sh`'s header and
  CLAUDE.md now say so, with the version each check arrived in.
- **The CI pin moved from 2.1.291 to 2.1.300.** The users' mods floor stays 2.1.291.
- **`pc_host_overlap`'s roster was rebuilt from the 2.1.300 binary.** It gained fifteen names,
  among them `debug`, `commit`, `pr`, `plugin-authoring` and `workflow-authoring`.
  - The host's `debug` is user-only, which is why reading the skill listing missed it.
  - A bare `/debug` runs the host's; ours stays `/debugging:debug`.
- **Smaller corrections.**
  - `pc_plugin_dependencies`: silent at update, visible in `claude plugin list` since 2.1.287.
  - turn-cost.sh: priced from the CLI's model catalog (Haiku 5.5, Opus 5.5, per-model cache
    reads).
  - plugin-scout: with the official `code-review` plugin enabled, one of the pair loses its
    hooks.
  - session-hud: the type column needs 2.1.293.
  - ultracode is an `/effort` toggle.
  - candor's resumed-subagent probe gained an amendment.

## Adopted

- **command-guard: `onFailure: "block"` (2.1.295).** A guard that times out or cannot start
  now blocks instead of letting the command through.
  - A 2.1.291 CLI accepts the key and keeps the hook, which was measured. Below 2.1.295 the
    key does nothing.
  - The cost is stated: a guard that cannot start blocks every Bash, Write and Edit call until
    `/plugin disable`.
  - `rm -rf \` is now denied too, which the host's own check (2.1.281) also asks on.
- **`pc_gating_catch` (2.1.290 `gatingHooks`).** `official-validate.sh` fails a mod gating
  hook with no `.catch`, because the host's `--strict` only prints a note.
- **`pc_plugin_root_quoting`.** This fails the build on an unquoted `${CLAUDE_PLUGIN_ROOT}` on
  a runnable command or skill line, after an interpreter or in command position (a script run
  by its path). It found 60 lines in 14 plugins, all quoted now. With a space in the install path
  the behavioral gate's own line had failed with exit 127. The host checks hooks.json only.
- **`/candor:level`.** It asks `claude plugin configure --json` (2.1.285) first, so managed
  settings and drop-ins are seen, and falls back to reading the files.
- **Install lines.** Five READMEs gained the install lines the validator asks for.

## Overlaps recorded, nothing removed

- `/doctor prompt-audit` (2.1.283) covers much of `/hindsight:claude-md`'s judgment pass. The
  plugin keeps the scripted stale-reference check, which gives the same rows every run, and
  the six-criterion score.
- `/advisor` (a server-side stronger-model advisor) covers the second-opinion part of
  `approaches:consult`. Consult keeps the blind facts-only brief, the read-only repo
  investigation and the irreversible-command nudge. Whether a blind brief beats the advisor
  is unmeasured: the Admission question is open.
- The host's dangerous-`rm` checks (2.1.281) cover part of command-guard's ask tier. The
  deny tier is unaffected.

## Not done

- **`prompt.change` (2.1.300) for secret-scanning's painter.** On 2.1.291 the event name stops
  the whole module loading, a computed name is refused, and on 2.1.300 the hook only
  observes.
- **Text `bold` → `weight` (2.1.299).** Waits for the mods floor to reach 2.1.299.

## Undecided: needs a logged-in session

- Does auto mode answer a hook `ask` in `-p` where it is the default: since 2.1.285, only on a
  third-party provider or with telemetry off (2.1.284 covers interactive sessions)? command-guard
  and database say an unanswered ask is a deny.
- Does a mod's `prompt.submit` now run before a slash command expands (2.1.299)?
- Can Up still recall a dropped prompt after 2.1.295? prompt-coach and secret-scanning promise
  it.
- Does prompt-coach's `maxTokens: 8` call still return text on Haiku 5.5, which thinks
  adaptively? An empty reply reads as clear, so this failure would be silent.
- Have the new `api-request*` transcript lines (2.1.300) lengthened transcripts? That would
  shrink drift.sh's and candor's fixed tail windows.
- Which of two same-named plugins "comes first" when one loses its hooks (2.1.296)?
