---
name: cmd-security-review
description: "Use when the user asks to security-review a diff or path against the security-review skill."
---

_This skill wraps the `/security:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Security-review the code in $ARGUMENTS (or the current diff if no argument) against
the security-review skill from this plugin. Invoke the skill first. Before reporting,
read the project manifests (composer.json / package.json and their lockfiles) and pin
every finding to the installed versions — do not flag vulnerabilities the installed
framework version already mitigates, and do not recommend APIs above it. When lockfiles
are present, run `composer audit` / `npm audit` and fold known advisories into the
findings. Report findings as `path:line — problem — fix`, ordered by severity
(critical, high, medium, low), each with a one-line note on who can exploit it and how.
Skip theoretical issues with no reachable input path unless nothing else is found.

When findings exist, offer remediation as a selectable choice (AskUserQuestion):
"Apply the fixes now, critical first (Recommended)" / "Skip — report only".
Bare instructions only when headless.
