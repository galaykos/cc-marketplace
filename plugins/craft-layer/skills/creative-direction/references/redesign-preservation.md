# Redesign preservation — what an existing site keeps

A craft run aimed at a target that already ships a site is a redesign, and a redesign breaks
things a greenfield build cannot: a renamed slug drops an indexed page and every inbound link, a
renamed form field breaks the CRM import and autofill, a relabelled button ends the analytics
funnel someone reports on. The build looks better and no gate notices. This file owns the mode
a redesign runs in, what is read before anything is touched, and what never changes without
asking.

**Standing: `agent-graded`.** No script reads this file or `preserve.json`; `craft-reviewer`
compares the shipped build against the recorded values when the audit hands it both, and a
category recorded with no values is `not checked`, never kept. The one line a script reads is
the contract's `Brand echo:` (`offer-contract.md` Part 1): `divergence.mjs` excuses the echoed
accent and font values from its default-band and anti-corpus assertions, and any non-empty echo
skips `hue-repeat` and `font-repeat` for every value, not only the kept ones.

## The mode — three values, one default

| Mode | Changes | Keeps |
| --- | --- | --- |
| `keep-brand` | type, spacing, colour calibration, motion, section composition | the brand accent and font families, the IA, the content, every never-change value |
| `new-look` | the visual language, brand values included | the content, the IA, every never-change value |
| `greenfield` | everything | nothing is inherited; no `preserve.json` is written |

**A target already shipping routes, pages or content is a redesign, and its default is
`keep-brand`** unless the brief asks for a new look in its own words. A target with none is
`greenfield`. Generator output is not a site: a starter page or kit, demo routes, auth
scaffolding (Breeze or Jetstream's `/login` and `/register`, create-next-app's layout).
`greenfield` on a target that has a site is the user's call, never an inference. A site that is
an earlier craft run's own output — a `.craft-layer/run-log.md` or stamped `craft/` artifacts in
the target — defaults to `new-look` instead, so the run still differs from the run log, unless
the existing `preserve.json` records `keep-brand`, which carries forward; `preserve.json` is
written either way. The mode is the contract's `Redesign` row, marked `(inferred ← <signal>)`
when the run derived it. The default fails safe: a user who wanted a new look says so at the
fork and loses nothing, while a new look nobody asked for throws away the recognition the brand
already earned.

**Residual:** detection reads the target, not the brief, so re-platforming a live site the brief
names into an EMPTY target is classed `greenfield`: no `preserve.json` is written and the
reviewer cannot check that site's slugs.

**Confirming it costs no exchange.** The concept fork's single `AskUserQuestion` call carries
the mode as one more question inside that call, and with it approval for any never-change value
a candidate would change; a `guided` run may ask the approval in a section round instead.
Headless, unanswered, or with no fork to ask at, the default stands, nothing is approved, and
every recorded value is kept.

## Read before touching

From the target's files, before the deck draw, never from the brief or from memory:

- **Brand tokens** — the accent value(s), the font family names, the logo file, radius and
  surface treatment.
- **Information architecture** — the route tree, the primary nav, the path to the primary action.
- **Content blocks** — which carry the page and which are filler. The copy itself is ingested
  verbatim under `content-source.md`.
- **Patterns to keep and to retire** — what makes the site recognisable (a hero, an interaction,
  the voice) against sameness-fingerprint tells, broken layouts and dead links.
- **SEO baseline** — the indexed pages (the sitemap, else the route tree), each page's title and
  meta description, structured data. Titles and structured data are content: they carry over
  unless the brief rewrites them.

## Never change without asking

In `keep-brand` and `new-look` these are recorded as concrete current values and changed only
when the user approves that item, recorded in `preserve.json`'s `approved`. A brief asking for
"a new look" is not consent to rename a route.

| What | `preserve.json` key | Who depends on the exact value |
| --- | --- | --- |
| URL slugs and in-page anchors | `routes`, `anchors` | search engines, inbound links, deep links into a section |
| Primary nav labels | `nav` | returning visitors; tracking keyed on link text |
| Form field names, in order, per form | `forms` | CRM and email integrations, autofill, server validation |
| Analytics event IDs | `analytics` | every funnel and dashboard built on them |
| Logo / wordmark | `logo` | the brand itself (`offer-contract.md` Part 2) |
| Legal and consent copy | `legal` | the client's approved wording, reproduced in full (`content-source.md`) |

## `preserve.json`

Written at `/craft-layer:craft` step 0, before the deck draw, for `keep-brand` and `new-look`
only, at `<project>/.craft-layer/preserve.json` — project state that outlives the session, not
a `craft/` run artifact:

```json
{"stamp": {"date": "2026-10-05", "head": "<target git HEAD>"},
 "mode": "keep-brand",
 "routes": ["/", "/pricing", "/blog/launch-notes"],
 "anchors": ["pricing", "faq"],
 "nav": ["Product", "Pricing", "Docs", "Sign in"],
 "forms": [{"form": "/contact#lead", "fields": ["name", "email", "company", "message"]}],
 "analytics": ["cta_start_trial", "signup_submitted"],
 "logo": "public/brand/wordmark.svg",
 "legal": ["app/legal/privacy/page.mdx", "components/CookieBanner.tsx"],
 "approved": [{"item": "nav:Docs", "change": "Docs → Developers", "approvedAt": "2026-10-05T14:40Z"}]}
```

- `stamp.head` is the target's git HEAD; outside git, `stamp.hashes` maps each file a value came
  from to its SHA-256, so a reader can tell which revision the values describe.
- Values are read from source — the router or pages directory, the nav component, each form's
  field `name`s in source order, the analytics calls, the logo asset, the files holding legal
  and consent copy. A category the target lacks is `[]` or `null`.
- `approved` holds one entry per never-change value the user agreed to change: `item` is
  `<key>:<recorded value>`, `change` what it becomes, `approvedAt` when. `[]` until one is; a
  changed value with no entry is reported `approval not recorded`.
- A mode the fork changes is written back before step 1, with the contract's `Brand echo:`:
  `greenfield` removes the file, `keep-brand` ↔ `new-look` updates `mode`, and `Brand echo:` is
  added on entering `keep-brand` and removed on leaving it.

## Modernisation levers, in order

For `keep-brand`, take the cheapest lever that answers the brief and stop there:

1. Type — hierarchy, scale, measure and weight, inside the kept families.
2. Spacing and rhythm.
3. Colour recalibration — neutrals and surfaces retuned, the brand accent kept.
4. Motion on the existing components, sized by `motion-tiers`.
5. Hero and key-section recomposition.
6. Block replacement — last, and only for a block that cannot be saved.

`new-look` starts at whichever lever the concept needs; the never-change table still binds.

Adapted from leonxlnx/taste-skill (commit ce26fc25, MIT, © 2026 Leonxlnx) — its redesign
protocol and `redesign-skill` — rewritten here rather than copied; its claims and figures are
upstream's and unverified here.
