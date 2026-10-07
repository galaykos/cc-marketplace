# Classic hooks beside a `modules` key — coexistence probe (2026-10-06)

Purpose: settle kill-trigger (c) of the spec `2026-10-06-ship-claude-code-mods`
before any mod ships. Each planned mod lands as a `modules` entry in a plugin's
`hooks/hooks.json` beside that plugin's existing classic hooks, so the plugin must
keep working on an older CLI. The open question was whether CLI 2.1.282 — the
version CI installs today, below this marketplace's 2.1.291 mods floor — still fires
a plugin's classic hooks when hooks.json carries a top-level `modules` key, or rejects
/ skips the file.

**Standing: `recorded`** — a one-time measurement; nothing re-runs it.

## Probe plugin

Throwaway, built under `mktemp -d` (`/tmp/probe-coexist.PhvZ5t`), never in the repo:

- `.claude-plugin/plugin.json` — `{"name":"probe-coexist","version":"0.0.1","description":"Throwaway probe: classic hooks beside a modules key","author":{"name":"probe"}}`
- `hooks/hooks.json` — `{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"touch \"$PROBE_MARK\""}]}]},"modules":["./m.ts"]}`
- `hooks/m.ts` — `export function register(on) {}`

Every run was made from `$P/work` inside the temp dir, with a fresh `PROBE_MARK`
path that did not exist beforehand (`ls` printed `No such file or directory`).

## CLI versions

- 2.1.282 — `npx -y @anthropic-ai/claude-code@2.1.282 --version` printed `2.1.282 (Claude Code)`, exit 0. No global install touched.
- 2.1.291 — installed `claude` (`/home/ivan/.local/bin/claude`), `claude --version` printed `2.1.291 (Claude Code)`.

## Results

| CLI | command | exit | marker after run |
|---|---|---|---|
| 2.1.282 | `PROBE_MARK=$P/marks/run-2.1.282 npx -y @anthropic-ai/claude-code@2.1.282 -p "reply ok" --plugin-dir $P/plugin` | 0 (stdout `ok`) | present (`-rw-rw-r-- 0 bytes, Oct 6 10:52`) |
| 2.1.291 | `PROBE_MARK=$P/marks/run-2.1.291 claude -p "reply ok" --plugin-dir $P/plugin` | 0 (stdout `ok`) | present (`-rw-rw-r-- 0 bytes, Oct 6 10:52`) |

Validator on 2.1.282 — `npx -y @anthropic-ai/claude-code@2.1.282 plugin validate --strict $P/plugin`, exit 0:

```
Validating plugin manifest: /tmp/probe-coexist.PhvZ5t/plugin/.claude-plugin/plugin.json

Validating hooks: /tmp/probe-coexist.PhvZ5t/plugin/hooks/hooks.json

  ❯ ./m.ts hooks: nothing
  ❯ ./m.ts calls: nothing on $

✔ Validation passed
```

No "unknown key" notice: 2.1.282's validator already parses the `modules` entry
and reports what the module registers (nothing, here).

The same validation in CI's environment — a throwaway `HOME`, `DISABLE_AUTOUPDATER=1`,
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`, stdin closed, as
`scripts/official-validate.sh` runs it — on a local `npm install --prefix` of
2.1.282 (`npx` itself fails under an empty `HOME` on this machine's node shim):
exit 0, `✔ Validation passed`, the same two `./m.ts` lines. The installed 2.1.291
under the same environment on this probe plugin: exit 0, `✔ Validation passed`.

Verdict: classic hook fired on 2.1.282

## What this means for the spec

Kill-trigger (c) did not trip. A plugin can add a `modules` entry to its existing
hooks.json and keep its classic hooks firing on CLI 2.1.282 and 2.1.291, and
`plugin validate --strict` on 2.1.282 (CI's pinned version) accepts the file under
CI's environment, so the `official-validate.sh` step does not go red on the shape alone.

Residuals this probe does not cover:

- It proves the classic hook fires with `modules` present; it does not prove the
  module itself loaded or ran on either CLI — `m.ts` registers nothing, and whether
  mods were active (remote switch, `allowManagedModsOnly`) was not observed.
- Only `UserPromptSubmit` in `-p` mode was exercised; other events and the
  interactive session were not.
- The runs were isolated from this repository's hooks and plugins but not from
  `~/.claude`; no other installed hook references `$PROBE_MARK`, so the marker
  can only have come from the probe's hook.
- No control run without `modules` was made: the marker appeared on both CLIs,
  so there was no negative result to explain.
- No CLI that treats `modules` as an unknown key was tested: 2.1.282 already
  recognises it. The result does not extend to CLIs older than 2.1.282.
