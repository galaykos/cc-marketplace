---
name: threat-modeling
description: Use during design — before code exists — to threat-model a feature or system: identify assets and trust boundaries, enumerate threats with STRIDE, write abuse cases, and decide mitigations. The design-phase complement to security-review's code-level audit; reach for it when the blast radius of getting security wrong is high.
---

# Threat modeling

Security review finds flaws in code that exists; threat modeling finds them in a design
before you build it, when they are cheapest to fix. It answers four questions: **what
are we building, what can go wrong, what are we doing about it, and did we do a good
job.** Do it when the stakes justify it — new auth, money movement, PII handling, a new
trust boundary — not for a copy tweak.

## 1. Model the system — assets and trust boundaries

- **Assets** — what an attacker wants: credentials, PII, money, admin capability,
  availability. Name them; they are what you are protecting.
- **Trust boundaries** — every point where data crosses from less-trusted to
  more-trusted: browser → server, service → service, user input → parser, third-party
  webhook → handler. **Threats live at boundaries.** A simple data-flow sketch (who
  calls what, where the boundaries are) is enough; you are not drawing UML.
- **Entry points** — every place external input enters: forms, APIs, file uploads,
  message consumers, CLI args.

## 2. Enumerate threats — STRIDE

For each boundary and asset, walk STRIDE — it is a checklist that stops you modeling
only the attack you already thought of:

- **S**poofing — pretending to be someone else (weak auth, forgeable tokens).
- **T**ampering — modifying data in transit or at rest (no integrity check, mutable
  client-trusted value).
- **R**epudiation — denying an action with no proof (no audit log).
- **I**nformation disclosure — leaking data (verbose errors, IDOR, over-broad API).
- **D**enial of service — exhausting a resource (unbounded query, no rate limit).
- **E**levation of privilege — gaining rights you shouldn't (missing authz check, mass
  assignment, injection to code execution).

## 3. Write abuse cases

Flip each user story into an attacker story. "As a user I reset my password" becomes
"as an attacker I reset *someone else's* password" — now enumerate how (guessable token,
no rate limit, host-header injection in the reset link, token that never expires). Abuse
cases turn STRIDE's abstractions into concrete, testable requirements.

## 4. Decide a response per threat

Every identified threat gets one of four dispositions — explicitly, not by silence:

- **Mitigate** — add the control (rate limit, authz check, signed token). The default.
- **Eliminate** — remove the feature/data that creates the risk (don't store what you
  don't need).
- **Transfer** — push it to someone equipped (use the provider's hosted checkout).
- **Accept** — a documented decision that the risk is tolerable, with who accepted it.
  "Accept" by never having considered it is not acceptance.

## A worked pass — password reset

- **Assets**: the account, the reset token. **Boundary**: unauthenticated request →
  account takeover capability. **Entry point**: the reset form + the reset link.
- **STRIDE surfaces**: Spoofing (request reset for any email), Tampering (host-header
  injection rewrites the link domain), Information disclosure (response reveals whether
  an email exists), DoS (unlimited reset emails), Elevation (guessable/non-expiring token
  → take over any account).
- **Abuse cases**: "reset someone else's password via a guessable token"; "harvest valid
  emails from the differing response".
- **Dispositions**: high-entropy single-use token with a short TTL (mitigate); identical
  response whether or not the email exists (mitigate disclosure); rate-limit per
  email/IP (mitigate DoS); build the link from a server-configured base URL, never the
  request host (mitigate tampering). Each is now a testable requirement, before any code.

## Prioritize by risk

Not every threat earns a control now. Rank by **likelihood × impact**; fix the
high-impact, plausible ones, consciously defer the rest. A threat model that mitigates
everything equally has not prioritized — and usually ships nothing.

## How much is enough

Threat modeling scales to the stakes. A new payment flow or auth system earns a full
pass with a data-flow diagram and a written disposition per threat; a small feature
touching an existing boundary earns fifteen minutes of "what crosses the boundary here,
walk STRIDE, note the two that matter". The failure modes are equal and opposite: a
100-page model no one reads, and no model at all on the feature that moves money. Aim
for the lightest artifact that changes a design decision — usually a short threat list
with dispositions, not a document.

## Defer rule

- Finding these flaws in code that already exists → `security-review` (this plugin's
  code-level audit). Threat modeling is the design-phase sibling.
- Regulatory data-handling obligations (retention, erasure) → the `data-privacy` skill (this plugin).
- Auth mechanism specifics (token types, OAuth flows) → the `api-auth` skill (this plugin).

## Anti-patterns

- **Modeling after building** — a threat model written to rubber-stamp a finished design.
- **STRIDE theater** — filling the grid without abuse cases or dispositions; a document
  no one acts on.
- **Only the obvious threat** — modeling the injection you expected, missing the IDOR and
  the missing rate limit next to it.
- **Mitigate-everything** — no prioritization, so the important controls drown.
- **Silent acceptance** — an unaddressed threat treated as accepted by omission.
- **One-and-done** — modeling at kickoff and never revisiting when the design changes.
