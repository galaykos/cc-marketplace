# secret-scanning: prompt-box guard probe (2026-10-08)

Purpose: settle the open questions of `taskmaster-docs/specs/2026-10-08-mods-round-3-survey.md`
row #3 before secret-scanning 0.13.0 ships its prompt-box guard (`prompt.edit` decorations,
`prompt.submit` mask / send / cancel).

**Standing: `recorded`** — a one-time measurement; nothing re-runs it.

## Method

- CLI 2.1.294, driven in a pseudo-terminal with python `pexpect` and the `pyte` VT emulator.
- A scratch `CLAUDE_CONFIG_DIR` and a placeholder API key.
- `ANTHROPIC_BASE_URL` pointed at a local stand-in for the API that logs every request body and
  answers with a fixed reply. **No real model was called.**
- The test secret was a GitHub-token-shaped string, assembled at run time.
- The plugin was loaded with `--plugin-dir`.

## Results

| Question | Result |
|---|---|
| (a) Is the secret painted in the prompt box? | Yes: colour `ff87af` with an underline on the secret's span; neighbouring text unstyled. A large paste collapses to `[Pasted text #1 +41 lines]`, which is not painted, and a draft recalled with Up is not painted either. Both are still checked at submit. |
| (b) What reaches the API on Mask and send? | The request body carried `deploy with token [REDACTED:a GitHub token] now please`, and the secret appeared nowhere in it. Send as typed sent the secret. A dismissed question masked. |
| (c) Cancel | No request reached the API, and the prompt box was cleared. Up recalls the draft, secret included, from the local `history.jsonl`. |
| (d) A `claude -p` prompt | It arrives with origin `sdk`. There is nobody to ask, so `$.ui.ask` rejects and the mask stands: the request body carried the `[REDACTED:a GitHub token]` marker and not the secret. |
| (e) Cost of `prompt.edit` on a 100 KB draft | 2.6 ms for mixed text; 16 ms median and 24 ms maximum on the worst input found. The hook's budget is 50 ms. Scanning is capped at 100,000 characters. |
| A slash command holding a secret | A rewrite in `prompt.submit` does not mask a command's arguments: they were already expanded in `command.run`, which runs first, so the secret still reached the API. A drop does stop it. Shipped behaviour: a two-option question, `This command's arguments hold a GitHub token, and command arguments cannot be masked. Send it as typed?`. Dismissing it dropped the prompt (`Prompt dropped by a hook: secret-scanning kept your prompt back …`), and no request carried the command. |

## Not measured

- The desktop app, where decorations may not render.
- Masking inside `command.run`, which could mask a command's arguments. It is a possible
  follow-up, not shipped.
