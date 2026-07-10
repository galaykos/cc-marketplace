---
name: cmd-decision-records-new
description: "Use when the user asks to create a new Architecture Decision Record in taskmaster-docs/adr/ from the decision just made or described in arguments."
---

_This skill wraps the `/decision-records:new` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Create an ADR for $ARGUMENTS (if empty, use the most recent significant decision
in this conversation — an approach pick, schema choice, dependency adoption; if
none exists, ask what was decided).

1. Ensure `taskmaster-docs/adr/` exists in the project. Number: next `NNN` from existing
   files (start 001).
2. Filename: `taskmaster-docs/adr/NNN-<kebab-slug>.md`.
3. Fill the template from the decision-records skill — context, options
   considered (including the losers and why they lost), decision, consequences
   (good and bad), revisit-when trigger, status.
4. If this decision supersedes an earlier ADR, set that ADR's status to
   `superseded by NNN` — never delete or rewrite its content.
5. Print the path and a one-line summary.
