---
description: Review API routes, controllers, or OpenAPI specs against api-design
argument-hint: [files-or-diff]
---

Invoke the api-design skill from this plugin first, then decide the branch. When the
surface is GraphQL or gRPC (schemas, resolvers, .graphql/.proto files), apply the
graphql-grpc skill from this plugin as the review rubric instead of the REST rules.

Branch decision (do this first): when $ARGUMENTS describes endpoints that do not exist
yet (a design task rather than a review), switch to the skill's contract-preview
protocol: render the proposed contract as the live HTML artifact with real example
payloads and get it approved before any implementation. An empty diff on a design task
still routes to contract-preview here — never to a "nothing to review" report.
Otherwise take the review branch below.

Review branch:

1. Resolve scope — the route files, controllers, FormRequests, API Resources, and
   OpenAPI/JSON Schema specs named in $ARGUMENTS, or the current diff if no argument.
2. Judge the contract the consumer sees (paths, methods, status codes, error shape,
   pagination, filtering, versioning, idempotency), not internal code style. When
   uncertain about semantics, verify against the RFCs (9110 for methods/status codes,
   9457 for problem details) instead of answering from memory. Report findings as
   `path:line — problem — fix`, ordered by severity. Skip naming nits unless they leak
   into the public contract.
3. Close with a coverage inventory and a self-refute pass: state `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   your highest-severity findings; if a finding does not survive it, drop or downgrade
   it with a note.

End with an offer, not a bare report. In the review branch, ask via AskUserQuestion
"Apply these fixes now (Recommended)" / "Report only"; after an approved contract
preview, ask "Start implementing this contract now (Recommended)" / "Stop here — spec
only". Headless: findings or approved contract only.
