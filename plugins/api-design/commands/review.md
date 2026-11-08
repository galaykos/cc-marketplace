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

2. **Hand up when the scope is wider than this rubric.** If the scope includes files
   outside this plugin's surface and `/code-review:review` is installed, hand the WHOLE
   scope to it and stop. It is the fan-in for overlapping review surfaces and loads
   every matching stack skill — this plugin's included — in one pass; running the
   per-stack commands separately is what produces the duplicate findings the fan-in
   exists to prevent, and leaves the stacks nobody happened to invoke unreviewed.
   Deferring is not a smaller answer — the aggregator reaches this plugin's rubric too.
3. Judge the contract the consumer sees (paths, methods, status codes, error shape,
   pagination, filtering, versioning, idempotency), not internal code style. When
   uncertain about semantics, verify against the RFCs (9110 for methods/status codes,
   9457 for problem details) instead of answering from memory. Report findings as
   `path:line — problem — fix`, ordered by severity. Skip naming nits unless they leak
   into the public contract.

   **A changed OpenAPI spec, when the user already has oasdiff.** When the scope changes
   a spec that also exists at the base ref and `command -v oasdiff` finds it, run from
   the repository root, with `<base>` the ref the diff was resolved against and `<spec>`
   the spec's path from the root: `oasdiff breaking --format json <base>:<spec> <spec>`.
   The `<ref>:<path>` form reads the base through `git show` (oasdiff 1.11.11+, `$ref`s
   across files from 1.15.0); for an older oasdiff, write `git show <base>:<spec>` to a
   temp file and compare that, single-file specs only. No network unless the spec
   `$ref`s a URL. Never pass `--fetch` (it fetches into the user's repository) or
   `--open` (it uploads the comparison to oasdiff.com). Exit 0 with or without breaks;
   non-zero means a spec did not load, and its first line goes under `Not checked`. Each
   change is a finding: locator `revisionSource` `file:line` (`baseSource`, marked
   `(base)`, for a removed element), problem its `text` and `[id]`, fix per the skill's
   Versioning section. `level` 3 (ERR, a definite break) ranks above 2 (WARN, the spec
   cannot decide); merge with your own finding on the same operation. A spec absent at
   `<base>` is new and has nothing to break. Not on PATH: `Not checked: oasdiff (not
   installed)`, and go on — never install it. Standing: recorded — nothing checks the
   run happened.
4. Close with a coverage inventory and a self-refute pass: state `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   your highest-severity findings; if a finding does not survive it, drop or downgrade
   it with a note.

End with an offer, not a bare report. In the review branch, ask via AskUserQuestion
"Apply these fixes now (Recommended)" / "Report only"; after an approved contract
preview, ask "Start implementing this contract now (Recommended)" / "Stop here — spec
only". On either apply pick, dispatch the work down the static chain
`web-dev:web-developer if installed → task-runner:task-executor if installed →
inline` — api-design ships no worker agent of its own, so naming the chain is the
only thing that keeps an approved contract from dying in chat.
Headless: findings or approved contract only.
