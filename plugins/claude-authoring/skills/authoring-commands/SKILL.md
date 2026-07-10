---
name: authoring-commands
description: Use when writing or reviewing a Claude Code slash command (.md under commands/) — frontmatter shape, thin-entry-point discipline over a skill, $ARGUMENTS handling, headless-safe AskUserQuestion offers, and the house pattern this marketplace's commands follow.
---

# Authoring commands

A command is the one artifact the user starts **deliberately, by name**. It is not
where knowledge lives — that is a skill. A good command is a thin, predictable entry
point: parse the argument, load the skill that carries the judgment, run a short
numbered procedure, offer the next action. When a command grows a body of rules, the
rules belong in a skill the command loads.

## Frontmatter

Two keys, one required:

    ---
    description: <one line: what the command does when invoked>
    argument-hint: [<expected-args>]
    ---

- `description` is mandatory — the validator rejects a command without it
  (`scripts/validate.sh`). Write what happens when the user runs it, not a topic.
- `argument-hint` is optional but expected whenever the command takes input; it is
  the `[placeholder]` the UI shows after the command name.
- Add no other keys. A command is not an agent — no `name`, `model`, `tools`,
  `effort`. (Agents live in `agents/` and carry all five; do not confuse the two.)

## The body: a thin procedure over a skill

The house pattern, seen across this marketplace's `/…:review`, `/…:check`,
`/taskmaster:*` commands:

1. **Open by naming the skill** the command loads and the goal, then hand off:
   "Invoke the `<skill>` skill from this plugin and respond to $ARGUMENTS with:".
   The command orchestrates; the skill decides.
2. **A short numbered list** — imperative steps, no branching prose. Each step is
   one action producing one thing.
3. **A final offer** (see headless rule below) when the result maps to real work.

If the command has no skill to load — it is pure mechanism — reconsider whether it
should be a skill instead. A command with a hundred lines of embedded rules is a
skill wearing a command's frontmatter; the rules cannot fire contextually and cannot
be reused by anything else.

## Handling $ARGUMENTS

- Reference the literal token `$ARGUMENTS` — the harness substitutes the user's text.
- **Empty-argument path.** State it explicitly: "if empty, ask what to <do> first".
  A command that silently does nothing on no input reads as broken.
- Do not re-parse `$ARGUMENTS` with elaborate grammar. Split on the obvious (a name,
  then a description); ask for anything missing rather than guessing.

## Headless-safe offers

A command often ends by proposing an action. Offer it as a choice, never take it
unprompted, and always give the non-interactive path:

    When the result maps to real repo work, ask via AskUserQuestion:
    "<do it now> (Recommended)" / "<report only>". Headless: report only.

- Interactive → `AskUserQuestion` with the recommended option first.
- Headless (no TTY, cron, piped) → fall back to report-only, or print the exact
  next command. `AskUserQuestion` is unavailable there; a command that blocks on it
  hangs the run.
- Destructive or outward-facing actions are never the silent default — the user
  opts in every time.

## Cross-references

A `/<plugin>:<command>` string anywhere in the file must name a **registered**
plugin — the validator resolves every such reference (`scripts/validate.sh`) and
fails on an unknown plugin. Reference sibling commands by their real names; do not
invent a command that does not exist yet.

## Release rider

A new command changes its plugin: **bump the `plugin.json` version** (CI gates on it)
and keep the plugin.json and marketplace descriptions telling the same story. A
command is not new-plugin scope, so no bundle-membership change — but a whole new
plugin that ships a command still follows authoring-plugins' registration + bundle
rules.

## A minimal real command

The whole shape, for a review command that loads a skill and offers a fix pass:

    ---
    description: Review SQL in the given path against sql-best-practices
    argument-hint: [path]
    ---

    Invoke the `sql-best-practices` skill from this plugin and review $ARGUMENTS
    (if empty, review the current diff). Respond with:

    1. One finding per line: `file:line — severity — problem — fix`.
    2. Severity-sort; skip style nits unless they change meaning.
    3. When findings map to real files, ask via AskUserQuestion: "Apply the fixes
       now (Recommended)" / "Report only". Headless: report only.

Nothing more is needed: frontmatter, a skill load, a numbered procedure, a guarded
offer. Everything the reviewer *knows* lives in the skill, not here.

## Reviewing an existing command

- Frontmatter terminated, `description:` present, no agent-only keys.
- Loads a skill (or is justified pure mechanism), not a wall of embedded rules.
- Empty-`$ARGUMENTS` behavior stated.
- Every action offered, with a headless fallback; nothing destructive by default.
- Every `/<plugin>:<command>` reference resolves to a registered plugin.

## Anti-patterns

- **Rules-in-a-command.** Judgment and knowledge embedded in the command body
  instead of a skill it loads — unreusable, un-triggerable, unmaintainable.
- **Silent empty-argument.** No stated behavior when `$ARGUMENTS` is blank.
- **Blocking AskUserQuestion.** An offer with no headless fallback, hanging any
  non-interactive run.
- **Unprompted action.** A command that edits, commits, or sends without the user
  choosing it — a command starts behavior by name, not by inference.
- **Agent frontmatter on a command.** `model:`/`tools:` on a `commands/*.md`; those
  belong to `agents/`.
