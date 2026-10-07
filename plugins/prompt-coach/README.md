# prompt-coach

A prompt coach for the terminal. At Enter it holds an eligible prompt for up to 5 s
while a model judges whether nobody could act on it, whether it contradicts an earlier
instruction, or, during a task-runner run on this branch, whether it strays off the
running card or reopens a decision its spec settled; only a confidently flagged prompt is dropped, and an animated
pixel-art sprite shows your text, the reason and a rewrite, with buttons that fill the
prompt box and never submit it. A haiku first pass judges every eligible prompt, and the
standby model below confirms a flag, at most 10 times a session. Terminal only; it
needs Claude Code 2.1.291 or newer with mods allowed.

No hooks module ships yet: until one does, it judges nothing and only adds its three
`/config` options. It installs only when you name it: bulk installs leave it out.

## Options

| `/config` option | variable | values | default |
|---|---|---|---|
| `cc_prompt_coach` | `CC_PROMPT_COACH` | on, off | on |
| `cc_coach_model` | `CC_COACH_MODEL` | `sonnet`, `opus` (the standby judge) | `sonnet` |
| `cc_coach_sensitivity` | `CC_COACH_SENSITIVITY` | `unactionable`, `ambiguous` | `unactionable` |

Set the option under `/config` or `/plugin configure prompt-coach`; the variable, set in
your shell or a settings.json `env` block, overrides it.

## Standing

- **The three rows in the root README's off-switch table: gate.** `scripts/generate.sh
  --check` fails the build when they drift from `userConfig` in `plugin.json`.
- **The `values` column: recorded.** It is typed by hand here; nothing compares it with
  `plugin.json`'s `options`.
- **The state the coach keeps** (`types/index.d.ts`: hashes of the texts you chose to pass,
  the escalation count, the mute flag, the back-off): **recorded** until a module writes it;
  the host validator then fails a `$.state` key the contract does not declare.
- **Cost:** **recorded.** The coach's model calls do not appear in `/cost` — measured once,
  `rationale/2026-10-07-prompt-coach-probe.md` in this marketplace's repository; nothing
  re-runs it.
