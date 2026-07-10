---
name: cmd-dev-env-review
description: "Use when the user asks to audit existing Dockerfile and docker-compose files against docker-best-practices."
---

_This skill wraps the `/dev-env:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the Dockerfile(s) and compose file(s) in $ARGUMENTS (or discovered
from the repository root if no argument — include compose.yaml,
compose.override.yml, and .dockerignore) against the docker-best-practices
skill from this plugin. Invoke the skill first. Before reporting, read the
project manifests (composer.json, package.json, .env.example) so findings
are pinned to the actual stack: flag image tags that contradict the
manifests' version floors, `ext-*` requires missing from the extension
install lines, and services with no evidence in the code — cross-check
against the compose-init skill's service derivation table. Verify EOL claims
against endoflife.date rather than memory. Report findings as
`file:line — problem — fix`, ordered by severity, with layer-cache and
secret-leak findings first. This command audits and proposes diffs only —
it never rewrites files unprompted: after the findings, ask via
AskUserQuestion "Apply the proposed diffs now (Recommended)" / "Skip —
audit only", and apply exactly the shown diffs on acceptance. Headless:
findings and diffs only, no writes. Use this plugin's init command for
generation from scratch.
