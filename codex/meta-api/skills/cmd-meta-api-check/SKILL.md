---
name: cmd-meta-api-check
description: "Use when the user asks to resolve current Meta API version, required permissions, and doc-backed constraints for a task."
---

_This skill wraps the `/meta-api:check` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the meta-api skill from this plugin for $ARGUMENTS (a task description,
endpoint, or Meta product — if empty, ask what is being built). Everything
reported must come from pages fetched now, not memory.

1. Fetch the Graph API changelog and state the current version (plus the
   Marketing API version separately when ads are involved). Grep the codebase
   for hardcoded `/vXX.X/` paths and Meta SDK pins in lockfiles; flag anything
   at or past expiry.
2. Map $ARGUMENTS to a product area via the skill's link map and fetch the
   relevant reference pages.
3. Report, in order:
   - Current API version to write, and the exact endpoints involved
   - **Required permissions** with their access level (Standard vs Advanced),
     whether App Review / business verification is needed, and the
     works-in-dev-mode-only warning when it applies
   - The right token type for the use case
   - Constraints that shape the code: rate limits, pagination style, webhook
     availability, field requirements
4. If any needed page is unreachable, name it, say what could not be verified,
   and ask for a docs excerpt — do not substitute memory for the missing page.

5. When versions, permissions, and constraints all resolved, ask via
   AskUserQuestion: "Proceed with the task using these doc-backed versions
   and permissions now (Recommended)" / "Stop here — report only".
   Headless: report only.
