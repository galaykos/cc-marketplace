---
description: Classify a shell command against the destructive-command rules — deny, ask or allow — without running it. Use before proposing a risky command, when a command was blocked and the reason needs unpacking, or when tuning the project allow-file.
argument-hint: "<command>" [--why]
---

# /command-guard:check

Classify `$ARGUMENTS` without executing anything.

## Steps

1. If `$ARGUMENTS` is empty, ask which command to check and stop.

2. Run the guard in CLI mode. The command is passed as a single argument, so
   quote it:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/hooks/destructive-guard.sh" --check '<the command>'
   ```

   Exit code: `0` allow, `1` ask, `2` deny. Never run the command itself, not
   even the ones that come back `allow` — this command classifies, it does not
   execute.

3. Report, in this shape:

   - **Verdict** — `deny` / `ask` / `allow`, and for deny/ask the one-line
     reason the guard printed.
   - **Segment that matched** — commands are judged per segment; name the one
     that fired so the user can see which part is the problem.
   - **Non-destructive alternative** — the guard prints one; if the verdict is
     `allow`, skip this.
   - **What `allow` does not mean**, whenever the verdict is `allow`: the guard
     matches known shapes in the command string. It cannot see inside a script,
     a Makefile target, an npm script, or application code. Say this plainly
     rather than reporting `allow` as a safety certificate.

4. If the user asks why a verdict came out the way it did, or wants to change
   it, read `skills/destructive-commands/references/rules.md` — it has the rule
   families, the allow-file format, and the guard's stated limits. Never
   propose editing the allow-file unless the user has asked for the exemption;
   it is theirs, and the guard blocks agent writes to it by design.
