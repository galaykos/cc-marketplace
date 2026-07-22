---
name: build-vs-buy
description: Use before implementing any capability that sounds generic — auth, pagination, date/time handling, queues, search, CSV/PDF, payments, validation, caching, retries — to check whether a library, service, or stdlib feature already solves it before writing a line.
---

The most expensive code is a working, tested, hand-rolled version of something
a maintained library already does better. The model's failure mode is eager
implementation: writing a date-range parser feels productive; noticing the
framework ships one does not. This gate runs BEFORE approach deliberation —
"use library X" is usually the approach that wins.

## Trigger cues

The capability about to be implemented sounds like a noun other projects also
need: authentication, authorization, pagination, date/time math, timezone
handling, money/currency, queues and retries, full-text search, CSV/Excel/PDF,
image processing, email sending, feature flags, rate limiting, validation,
slugs/ids, state machines, webhooks, caching. Project-specific business logic
never triggers this gate — nobody ships your domain rules as a package.

## Protocol

1. Name the generic capability in one line, stripped of project vocabulary
   ("parse and format ISO durations", not "handle our booking windows").
2. Check the closest shelf first, in order:
   - Language stdlib and the framework already installed — the answer is
     frequently already in the dependency tree.
   - Direct dependencies' extras (the ORM paginates; the HTTP client retries).
   - The stack's registry (packagist/npm/pypi — read the project manifests
     for which) for established packages.
3. Table the candidates (2–4 rows):

    | Candidate | Health | License | Covers need | Integration cost |
    |---|---|---|---|---|
    | lib-x | last release, adoption signal | MIT | ~90% | small adapter |
    | write it | n/a | n/a | 100% by definition | full write + forever maintenance |

   Health = maintained recently, real adoption, open-issue hygiene. "Covers
   need" is honest percent against the actual requirement, not the brochure.
4. Verdict — one of three:
   - Take: use it directly. Default when a healthy candidate covers ≥80%.
   - Wrap: use it behind a thin project-owned interface — when coverage is
     partial, the dependency is a swap risk, or its API leaks awkwardly.
   - Write: build it — only when the loop below says so.
5. Significant verdict → state it inline with the candidate table as the
   "options considered" record; persist only where the project already keeps
   decision docs.

## When WRITE legitimately wins

- Core domain: the capability IS the product's differentiation.
- The need is a 20-line subset and the candidate is a 20k-line framework —
  dependency weight exceeds the problem.
- Every candidate is unhealthy: abandoned, license-incompatible, or a
  security liability.
- The integration contortions cost more than the implementation ("we'd use
  10% of it and fight the other 90%").

Write the reason down; "we prefer our own code" is not on the list.

## The never-hand-roll list

Some wheels are booby-trapped. Reinventing these is a finding, not a choice:

- Cryptography, password hashing, token generation and validation.
- Authentication and session management (use the framework's).
- Timezone and DST arithmetic; calendar math beyond day addition.
- Parsers for standard formats: email addresses, URLs, CSV edge cases,
  HTML/XML/JSON/YAML.
- Money arithmetic in floats — use a money type or integer minor units.
- Sanitization and escaping — the framework's encoder, always.

For these, "buy" (stdlib/framework/vetted lib) is the only verdict; escalate
findings on existing hand-rolled versions to the security plugin's review.

## Cost honesty

The write-it row's true cost line: implementation + tests + edge cases the
library community found over years + maintenance forever + onboarding every
future maintainer. The library row's true cost: integration + upgrade churn +
the risk it dies. Compare those, not "an afternoon" vs "a dependency".

## Wrap discipline

When the verdict is wrap, the wrapper earns its existence only by being thin:

- One project-owned interface exposing the 3–5 operations the project
  actually needs, named in domain language.
- No pass-through inflation: a wrapper re-exporting the library's whole
  surface is a rename, not a boundary.
- The library import appears ONLY inside the wrapper module; the day it is
  swapped, the diff is one file.
- Wrap for swap-risk and API awkwardness — not by reflex; a stable,
  well-shaped dependency (the framework ORM) needs no coat.

## Worked micro-example

Capability: "export report data as CSV" in a Laravel app.

| Candidate | Health | License | Covers need | Integration cost |
|---|---|---|---|---|
| league/csv | active, wide adoption | MIT | ~100% (escaping, enclosures, streams) | composer require + 10 lines |
| SplFileObject::fputcsv (stdlib) | ships with PHP | n/a | ~85% — manual streaming, BOM handling | 0 deps, ~30 lines |
| write it | n/a | n/a | 100% claimed | escaping + encodings + injection edge cases the community already paid for |

Verdict: take league/csv — CSV escaping is on the never-hand-roll list
(standard-format parsing/writing), and the stdlib route re-implements the
15% where the bugs live. Table stands as the "options considered" record.

## Anti-patterns

- Resume-driven building: writing the fun version of a solved problem.
- Brochure trust: crediting a candidate with features unverified against the
  actual requirement — spike it (approaches plugin) when uncertain.
- Dependency maximalism: the inverse failure — a package for is-odd. The
  20-line-subset rule cuts both ways.
- Silent hand-rolling: implementing a never-hand-roll item without flagging.
- Re-litigating a standing take/wrap ADR without its revisit trigger firing.
