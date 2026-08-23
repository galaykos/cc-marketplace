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

   **Known limitation, and it bites exactly where you most want this command.**
   The invocation above goes through the Bash tool, so the plugin's own
   `PreToolUse` hook reads it and sees the deny-tier target quoted inside — and
   denies it. For a deny-tier target this step therefore fails, which is the case
   where "a command was blocked and the reason needs unpacking" applies. Standing:
   **unfixed by design**. A self-exemption was written twice and reverted twice
   (0.2.0 matched its tokens as substrings and fell to `bash -c PAYLOAD name arg…`;
   0.2.1 matched by argv position and fell to command substitution, backticks, and
   redirection, because skipping classification skips the whole segment while the
   shell still evaluates what is inside it). A convenience command does not justify
   a hole in a deny gate. See the comment at `hooks/destructive-guard.sh` and the
   `no self-exemption` section of `scripts/__tests__/destructive-guard.test.sh`,
   which pins every known vector.

   **What to do instead when the target is deny-tier.** Do not retry with
   different quoting, a wrapper, or a script file — the guard reads those too, and
   the answer is already known: it is `deny`. Skip step 2 and go straight to step
   3, reporting the verdict as `deny` and reading the reason out of
   `skills/destructive-commands/references/rules.md`, which lists every deny rule
   and its rationale. `ask`- and `allow`-tier targets run fine.

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
