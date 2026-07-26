# Register corpus — the buyer's question answered in an integrator's voice

`offer-contract.md` Part 3 already says it in prose: method disclosure, spec sheets and API
tables are **supporting** material, and a page built only of specs "has skipped every other
slot". It names the anti-pattern too — *Spec sheet as sales page*. Nothing greped for it, so
it caught nothing, and a build shipped a landing page whose every spine slot was ANSWERED and
whose every answer read as documentation: `POST /api/task` for what it is, a token scope for
who it is for, a schema fact for why change. The presence gate passed green. A human found it
by reading the page.

This file is the machine half. It owns three things: the **slot → region mapping** that makes
the check scoped rather than blunt, the **corpus of register markers** it tests against, and
the **assertion** that reads both.

**Density is not the defect.** A page can be dense and correct. The defect is a *buyer's*
question answered with an *integrator's* fact — and only in the three slots where a buyer is
the one asking.

## Part 1 — The slot → region mapping

A whole-page grep is the wrong gate: it fires on every technically-correct `how it works` and
`objection` section, which is exactly where `offer-contract.md` ROUTES spec detail. To tell
legal jargon from illegal, the gate has to know which region of the page answers which slot —
and of the eight spine slots only plain-what has ever had a positional anchor ("the page's
FIRST section in source order").

**Carrier: a `Spine regions:` line on `craft/build-task.md`,** written by the craft flow's
motion step alongside `Motion:`, `Signature:`, `Ambition:` and `Banned vocabulary:`. That step
runs at EVERY tier, so a `one-shot` run — the default, and the mode the failing build ran in —
produces the mapping with no ledger and no extra exchange.

```
Spine regions: plain-what=#hero, audience=#hero, problem=#status-quo, how-it-works=#method, price=#pricing, proof=#proof, objection=#limits, cta=#hero
```

Six rules bind the line:

- **ONE LINE, NEVER WRAPPED.** The pairs run to the end of the line and stop there. This is
  the same hard rule `concept-deck.md` states for the `Banned …` keys, in the same words and
  for the same reason: *one constraint per LINE, never wrapped — a continuation line is read
  as its own line.* `divergence.mjs` matches `Spine regions:` line by line, so a wrapped
  example loses every pair after the wrap SILENTLY (a trailing comma yields an empty pair
  that is dropped without a word), and a wrap falling before a buyer slot leaves no buyer
  slot mapped and SKIPs the gate outright. Wrap after `problem=` and the collision rule below
  has nothing left to collide with. Let it be long; a long line is not a defect here.
- **Slot names are the ledger's**, verbatim — `plain-what`, `audience`, `problem`,
  `how-it-works`, `price`, `proof`, `objection`, `cta`
  (`section-decisions/references/section-ledger.md`). One vocabulary, two carriers.
- **The value is an ANCHOR** — the `id` of the element that CONTAINS that slot's copy, which
  is the same handle the ledger's `section` column already holds and the same one in-page
  wayfinding needs. A TEXT-ONLY LEAF is the normal carrier and is graded like any other
  region — `<h1 id="plain-what">…</h1>` is the shape `/craft-layer:craft` step 6 asks for.
  What is not addressable is a wrapper with no copy in it: an `id` on a self-closing component
  invocation (`<Hero id="hero" />`) reaches nothing, and the gate reports that slot unchecked
  rather than guessing.
- **Several slots may share one region.** A hero routinely answers plain-what, audience and
  cta at once; write it three times.
- **A `guided` run does not re-derive it.** The ledger's `slot` + `section` columns ARE this
  mapping; the motion step copies them onto the line. The ledger is a cross-check, never the
  source, so nothing about this degrades on `one-shot`.
- **Collision goes to the buyer.** A region mapped to a buyer slot AND to `how-it-works` or
  `objection` is graded as a buyer region — the buyer's question is the one that gets
  displaced. A build where that is genuinely wrong waives the check with a reason rather than
  quietly widening what counts as legal.

An absent line is `not checked`, never a pass: the mapping is the gate's only input.

## Part 2 — The corpus

A **corpus of markers, not a blocklist of words.** The same distinction
`sameness-fingerprint.md` draws: cataloguing what to diverge FROM is the opposite of
prescribing. Every term below is legal on the page, in the nav, in the docs link, and in as
much of `how it works` and `objection` as a technical buyer wants — a limits list is SUPPOSED
to be concrete. What the corpus detects is one narrow thing: an integrator's register standing
where a buyer's answer belongs.

| Class | Reads as | Why it is a tell in a buyer slot |
| --- | --- | --- |
| `http-verb` | `POST /api/task`, `DELETE request` | the reader is being told how to CALL it, not what it does |
| `endpoint-path` | `/api/…`, `/v1/…`, `/tasks/{id}`, `/:id` | a route is an integration surface, never a value proposition |
| `auth-scheme` | bearer token, OAuth, JWT, Sanctum, `ability:machine` | how a machine proves identity; buyers ask who it is FOR |
| `status-code` | `HTTP 500`, `returns 403`, `429 Too Many Requests` | a failure mode quoted as a feature |
| `orm-schema` | `workspace_id`, global scope, foreign key, migration | the storage model standing in for the problem |
| `protocol-limits` | rate limit, requests per minute, idempotency key | operational envelope quoted before the offer |
| `internal-service-name` | this build's own service/queue/worker names | **agent-graded** — build-specific, so no pattern can carry it |

The six machine classes below are what `divergence.mjs` compiles. The seventh has no pattern
by construction and is graded by `craft-reviewer` (step 11), which reads the build's own
vocabulary; saying which half is which is worth more than a check pretending to cover both.

<!-- register-corpus:start -->
```
http-verb :: g :: \b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(?:/|https?://|\{|:)
http-verb :: g :: \b(?:GET|POST|PUT|PATCH|DELETE)\s+(?:request|call|endpoint)s?\b
endpoint-path :: gi :: (?:^|[\s"'(\[])/(?:api|v[0-9]+|graphql|rest|oauth|webhooks?)(?:/|\b)
endpoint-path :: g :: /\{[A-Za-z_]\w*\}
endpoint-path :: g :: /:[a-z_]\w*\b
auth-scheme :: gi :: \b(?:bearer token|bearer auth|oauth2?|jwt|json web token|sanctum|api[ -]?key|api[ -]?token|api[ -]?secret|access token|refresh token|client secret|personal access token|hmac|basic auth|token scope|scoped token)\b
auth-scheme :: gi :: \b(?:ability|scope|scopes|permission):[a-z_-]+
status-code :: gi :: \b(?:HTTP|status(?: code)?|error(?: code)?|response code|responds? with|returns?|rejects? with|rejected(?: with)?|fails? with|throws?)\s+(?:an?\s+)?[1-5][0-9]{2}\b
status-code :: gi :: \b(?:401|403|409|418|422|429|451|502|503)\s+(?:unauthori[sz]ed|forbidden|conflict|unprocessable|too many requests|bad gateway|service unavailable|errors?|status|responses?)\b
orm-schema :: gi :: \b[a-z][a-z0-9]*_id\b
orm-schema :: gi :: \b(?:foreign key|primary key|global scope|eloquent|active ?record|varchar|nullable|polymorphic|soft[ -]delete|join table|database schema|db migration|schema migration|ORM)\b
protocol-limits :: gi :: \b(?:rate[ -]limit(?:ed|s|ing)?|requests? per (?:second|minute|hour|day)|req/(?:s|min)|idempotenc\w+|retry-after|webhook payload|exponential backoff|throttl\w+)\b
```
<!-- register-corpus:end -->

Format: `class :: flags :: pattern`, one per line, JavaScript regular-expression source. The
block is the gate's input, so a pattern that will not compile is reported and dropped rather
than silently ignored.

**Every numeric pattern is ANCHORED to a tell, and `status-code` is why.** A bare
`\b(?:401|403|429|451|502|503)\b` shipped here once, and a bare three-digit number is not a
register marker — it is a number. It fires on `401(k)` in any benefits or fintech hero, on
"429 teams", on "$451/yr", on "Suite 502", every one of them correct buyer copy. So both
status-code rules carry context: rule 1 a PRECEDING tell (`HTTP`, `status`, `error`,
`returns`, `rejected`, `throws`), rule 2 a TRAILING one (`403 Forbidden`, `429 Too Many
Requests`, `502 errors`). A number quoted with neither is not evidence of anything, and the
class it belongs to would be waived into silence within one run if it kept saying otherwise.
Anchoring costs one true positive shape — a bare code inside a `<code>` span, which the copy
reader flattens to plain text before any pattern sees it, so the span cannot be a tell. That
is a declared limit below, not a gap to close by removing the anchor.

**Refresh rule.** Reviewed **on each craft-layer release**, exactly like
`sameness-fingerprint.md` — a deliberate corpus, never auto-derived. Add a class when a run
ships a buyer slot in a register no pattern here caught, and say what it was; never add a term
because it sounded technical. Removing a class needs the same evidence as adding one. **Last
verified: 2026-07-26.** `divergence.mjs` reads THIS file when `CLAUDE_PLUGIN_ROOT` is set and
falls back to a frozen snapshot otherwise, printing which one it used and its date on every
run — so a stale corpus is visible rather than assumed.

## Part 3 — The assertion

**Scripted.** `template/craft-gates/divergence.mjs`, check name `spine-register`, run by
`/craft-layer:audit` step 1 and `/craft-layer:craft` step 7 as `node scripts/divergence.mjs`.
It is a script and not another prose rule on purpose: the check it sits beside — the
plain-what line against the concept's metaphor vocabulary — is itself agent-graded prose, and
mirroring prose with prose reproduces the very defect this gate exists to end.

Exit-code semantics are the script's existing ones, unchanged:

- **`FAIL` → exit 1**, one detail line per hit naming the region, the slot, the marker, its
  class and its `path:line`. It has the same standing as every other craft finding: resolve it,
  or waive `spine-register` in `<project>/.craft-layer/waivers.json` with a reason.
- **`SKIP`** — no build task, no `Spine regions:` line, no buyer slot mapped, no mapped anchor
  found in the tree, or **one or more mapped buyer slots UNREADABLE while the rest carry no
  marker**. Reported with the reason, counted as `not checked`, never a pass and never a fail.
  That last case is the one worth stating outright: an unreadable slot used to be a note
  beside a PASS, so one of three buyer regions resolving cleared the gate with two slots
  ungraded — a note standing in for a verdict. A clean result over PART of the buyer spine is
  not a clean result. A `FAIL` still stands whatever else was unreadable: a marker found is
  evidence, and evidence is not weakened by a slot nobody could see.
- **exit 2** stays what it was: the script could not see the build at all (no token source).
  The register verdict is printed before that exit rather than swallowed, so a FAIL under a
  missing token source is still on the record.

**Declared limits**, stated rather than hidden:

- It reads SOURCE, not a rendered page, and it counts as copy only what
  `craft-reviewer`'s banned-vocabulary gate counts as rendered content — text between tags
  (including the run BEFORE the first child tag, and the whole of a text-only leaf), copy
  attributes (`alt`, `title`, `aria-label`, `placeholder`), and quoted values of copy-bearing
  keys (`title:`, `heading:`, `body:`, …). A `fetch('/api/subscribe')`, an import path, a
  `className` and an `href` are code, not copy, and are invisible here by design.
- **`data-*` is the one attribute this gate reads and the banned-vocabulary gate does not
  skip.** That gate hunts literal terms a human chose, so a `data-` string is worth checking.
  This one hunts the SHAPE of code — `\w+_id`, a route, a status number — and
  `data-testid="task_id"`, `data-state`, `data-slot` are made of that exact shape while being
  hooks no reader ever sees. Reading them would make "code is not copy" false and fire on
  correct pages, so they are excluded here and only here.
- A region is bounded by tag balance on the element carrying its anchor. Copy rendered from a
  child component file is outside that boundary and unchecked.
- A bare status code inside a `<code>` span reads as plain text once the region is flattened,
  so the span cannot anchor it and such a hit is missed. Deliberate: see the anchoring note
  above.
- Only `plain-what`, `audience` and `problem` are graded. The other five slots are unchecked by
  construction — that is the scoping, not an omission. Within those three, every mapped slot
  must be readable for a PASS; an unreadable one downgrades a no-hit run to `SKIP`.

## Anti-patterns

- **Buyer's question, integrator's answer** — every slot answered, every answer written for
  whoever is going to call the API. The failure this file exists for.
- **Whole-page jargon grep** — the blunt version: fires on the `objection` limits list the
  contract asked for, teaches builders to strip real detail, and gets waived into silence.
- **Mapping in the record, not on the build task** — a slot→region mapping the builders and
  the gate never receive is the concept-constraint failure one file over.
- **Blocklist creep** — the corpus growing into vocabulary a page may never contain. Six
  classes scoped to three slots; anything wider is a different, worse gate.
