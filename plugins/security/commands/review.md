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

**Generic OWASP pass — the host's, not a second one.** When triage takes the full
audit AND the resolved scope is the pending branch diff (no path or file set in
$ARGUMENTS): Claude Code ships a built-in skill listed as bare `security-review`
with no owning plugin — this plugin's own skill lists as `security:security-review`,
and matching that is NOT a hit. When the bare host skill is listed, invoke it through
the Skill tool (never the `/security-review` slash form), report-only, and take its
findings as the generic injection/XSS/authz/secrets pass. Everything this command
carries that the built-in does not stays here and runs on top: the version pin
against the installed framework, `composer audit` / `npm audit` folding (or the
`/stack-scan:audit` citation), the `/secret-scanning:scan` fold, the threat-model
disposition audit, the data-privacy and api-auth lenses, the coverage inventory and
the self-refute pass. Filter the built-in's findings through
`security:security-review`'s exploitability triage before reporting — an
unreachable-path finding is dropped subject to the same unless-nothing-else-is-found
exception below. When $ARGUMENTS names a path or file set, or the host skill is
absent, run the whole review inline as written: the built-in reviews only the
branch diff and would not cover the requested scope. The `Checked:` line names
which branch did the generic pass. Standing: recorded — nothing checks which ran.

Before reporting, read the project manifests (composer.json / package.json and their
lockfiles) and pin every finding to the installed versions — do not flag vulnerabilities
the installed framework version already mitigates, and do not recommend APIs above it.
When lockfiles are present, run `composer audit` / `npm audit` and fold known advisories
into the findings — unless a `/stack-scan:audit` report already exists in this session:
cite its findings instead of re-running the same commands blind to it (stack-scan's
package-hygiene owns dependency-audit DEPTH — outdated lanes, transitive chains; this review
folds advisories into diff context). On a full audit, when the secret-scanning plugin
is installed, also run `/secret-scanning:scan` over the scope and fold its hits in —
its write-time hook cannot see secrets already committed, and this review's Secrets
section is the one place that looks back. Report findings as `path:line — problem — fix`, ordered by severity
(critical, high, medium, low), each with a one-line note on who can exploit it and how.
Skip theoretical issues with no reachable input path unless nothing else is found.

When the scope includes a design doc or threat model, audit its dispositions: every
threat marked Accept must name who accepted it and why — an acceptance with no owner
is acceptance-by-omission, the exact failure the threat-modeling skill names as an
anti-pattern, and nothing else reads dispositions back.

Close with a coverage inventory and a self-refute pass: state
`Checked: … (generic pass: host built-in | inline)` and `Not checked: … (why)` so it is explicit what was covered, what was clean, and what was
skipped — not only what broke. Then run one adversarial self-refute pass over every
`critical` finding; if a finding does not survive it, drop or downgrade it with a note.

When findings exist, offer remediation as a selectable choice (AskUserQuestion):
"Apply now, critical first" / "Report only". On an apply pick, dispatch the finding
list down the static chain `security:security-engineer → task-runner:task-executor if
installed → inline` — never leave the user to retype findings. Bare instructions only
when headless.
