---
name: terse-compress
description: Use when explicitly asked to compress a prose memory file — "compress CLAUDE.md", "shrink my memory file", "make this doc denser to save tokens", or /terse:compress <path>. Rewrites one named markdown file in place, backing up the original first, preserving code, URLs, paths, numbers and headings exactly. Never runs on its own and never touches source code or config.
---

## The carve-out

This plugin's first law is that files on disk are never compressed. This skill is
the single exception, and it holds only because the file **is** the deliverable:
the user named it, and shrinking it is the request. Everything about it is gated
by that.

Refuse, and say which rule applies:

- No explicit path — never guess which file was meant
- Anything that is not prose markdown — source code, `.json`, `.yaml`, `.toml`,
  lockfiles, generated files, a file carrying a "generated from" header
- A file another tool parses by shape: a `SKILL.md` under a plugin, a template,
  a fixture, anything a validator or gate reads
- More than one file per invocation. One file, one backup, one diff to check

## Procedure

1. **Read the whole file first.** Compressing what you have not read is how a
   fact disappears.
2. **Back up.** Copy to `<file>.original.md`. If that path already exists, stop
   and ask — a second run would overwrite the only human-readable copy with an
   already-compressed one.
3. **Rewrite** applying the rules below.
4. **Verify before reporting**, mechanically, not by impression:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-compress.sh" FILE FILE.original.md
   ```

   Five checks that pass or fail on bytes: identifiers, paths and URLs all
   survived · heading count unchanged · fenced code blocks intact · every number
   still present · the file actually shrank. A non-zero exit means restore or fix, never report. What the
   script cannot judge is meaning — a compression that kept every identifier and
   deleted the sentence explaining why still exits 0.
5. **Report** in the plugin's report shape: verdict line with before/after bytes
   and percent, backup path, and any rule you had to break with its reason.

## Remove

Articles (a / an / the) · filler (just, really, basically, actually, simply,
essentially, generally) · pleasantries · hedging ("it might be worth", "you could
consider") · connective padding (however, furthermore, additionally, in addition)
· redundant phrasing ("in order to" → "to", "make sure to" → "ensure", "the
reason is because" → "because") · sentences that restate the heading above them.

## Preserve exactly, byte for byte

Fenced and indented code blocks · inline `code` spans · URLs and markdown links ·
file paths · shell commands · library, API and protocol names · proper nouns ·
dates, versions and every numeric value · environment variables · YAML
frontmatter · heading text · list nesting and table structure · every `MUST`,
`NEVER`, `ALWAYS` and other normative word — dropping one inverts a rule.

## Never

- Merge two sections because they seem related. Structure is the file's index
- Drop an example. Examples are the part a reader trusts
- Turn a table into prose, or a rule into a summary of the rule
- Compress a file you did not back up
- Run this because a file "looks verbose". Only when asked, only on a named path

## Reversal

`mv FILE.original.md FILE` restores it exactly. Say this in the report — a
compression the user cannot undo in one command is not a safe compression.

Standing: **agent-graded**, plus the five mechanical checks in step 4, which are
the only part with real teeth. Nothing in CI verifies a compressed memory file.
