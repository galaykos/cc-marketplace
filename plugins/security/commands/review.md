---
description: Security-review a diff or path against the security-review skill
argument-hint: [files-or-diff]
---

Security-review the code in $ARGUMENTS (or the current diff if no argument) against
the security-review skill from this plugin. Invoke the skill first. When the change
touches personal-data handling (PII, consent, retention, erasure, data-subject
rights), also apply the data-privacy skill from this plugin as a review lens; when
it touches auth mechanics (token model, OAuth2/OIDC flows, scopes, refresh
rotation), also apply the api-auth skill from this plugin.

Triage before the deep read: a trivial, single-file, or purely mechanical change with
no security-relevant surface earns a one-line verdict — state it and stop. Take the
full audit below when the change touches auth, input handling, crypto, secrets, or
dependencies, OR spans more than 5 files, OR exceeds 300 changed lines (a NEW file
counts its full length as changed).

Before reporting, read the project manifests (composer.json / package.json and their
lockfiles) and pin every finding to the installed versions — do not flag vulnerabilities
the installed framework version already mitigates, and do not recommend APIs above it.
When lockfiles are present, run `composer audit` / `npm audit` and fold known advisories
into the findings. Report findings as `path:line — problem — fix`, ordered by severity
(critical, high, medium, low), each with a one-line note on who can exploit it and how.
Skip theoretical issues with no reachable input path unless nothing else is found.

Close with a coverage inventory and a self-refute pass: state `Checked: …` and
`Not checked: … (why)` so it is explicit what was covered, what was clean, and what was
skipped — not only what broke. Then run one adversarial self-refute pass over every
`critical` finding; if a finding does not survive it, drop or downgrade it with a note.

When findings exist, offer remediation as a selectable choice (AskUserQuestion):
"Apply now, critical first" / "Report only". On an apply pick, dispatch the finding
list down the static chain `security:security-engineer → task-runner:task-executor if
installed → inline` — never leave the user to retype findings. Bare instructions only
when headless.
