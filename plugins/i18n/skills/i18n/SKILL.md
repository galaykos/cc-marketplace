---
name: i18n
description: Use when adding or reviewing internationalization/localization — translation catalogs and key hygiene, ICU MessageFormat pluralization and gender, locale-aware dates/numbers/currency, RTL layout, fallback chains, and translation extraction. For a product shipping outside one language/market; not for a single-locale app that will stay that way.
---

# Internationalization & localization

i18n is cheap to build in and expensive to retrofit — every hardcoded string, every
`"You have " + n + " items"`, becomes a find-and-fix across the codebase later. The
core discipline: **no user-facing string in code; every string is a key resolved from
a catalog at runtime.** Everything else follows.

## Keys and catalogs

- **Semantic keys, not English text as the key.** `cart.empty_message`, not
  `"Your cart is empty"` — the English is just one catalog entry, and reusing the source
  string as the key breaks the moment two contexts need different translations of the
  same words.
- **One namespace per feature**; keep catalogs small and co-located with the feature
  where the tooling allows. A single 5000-line `en.json` is unmergeable and unreviewable.
- **Never concatenate translated fragments.** `t('greeting') + name` assumes English
  word order; other languages put the name first. Interpolate into one message with a
  placeholder: `t('greeting', {name})` → `"Hola, {name}"`.

## Pluralization and gender — use ICU

`if (n === 1) "item" else "items"` is an English-only rule. Arabic has six plural
forms, Polish three, Japanese one. Use **ICU MessageFormat** so the catalog owns the
rule per language:

```
{count, plural, =0 {no items} one {# item} other {# items}}
```

The code passes `count`; the translator writes the right forms for their language. The
same applies to `select` for gender. Never encode plural or gender logic in code.

## Locale-aware formatting

Dates, numbers, and currency are **not** string operations — they are locale functions:

- **Numbers** — `1,000.5` (en) vs `1.000,5` (de) vs `१,०००.५` (hi). Use `Intl.NumberFormat`
  / the framework equivalent; never hand-format.
- **Dates/times** — order, separators, and calendar differ; format via `Intl.DateTimeFormat`
  in the user's locale AND time zone. Store UTC, render local.
- **Currency** — symbol, placement, and decimal count are locale × currency (`1 234,56 €`
  vs `$1,234.56`, ¥ has no decimals). Format with the currency code, do not hardcode `$`.

## RTL and layout

Right-to-left languages (Arabic, Hebrew) mirror the UI. Use **logical CSS properties**
(`margin-inline-start`, not `margin-left`), set `dir="rtl"`, and never assume left=start.
Icons with direction (arrows, chevrons) flip; test the mirrored layout, don't assume it.

## Fallback and missing keys

- A **fallback chain** — `fr-CA → fr → en` — so a missing regional string degrades to
  the base language, then the default, never to a raw key shown to the user.
- **Missing-key policy**: in dev, surface loudly (the key name, a console warning); in
  prod, fall back silently but log, so gaps are visible without leaking `cart.empty_message`
  to a customer.

## Extraction and workflow

Strings are **extracted** from code to catalogs by tooling, not copied by hand — a hand-
maintained catalog drifts from the code within a sprint. Wire extraction into the build,
give translators context (a description per key, a screenshot where possible), and treat
the source catalog as the contract translators fill.

## When NOT to i18n

A genuinely single-locale internal tool that will stay that way does not need the
machinery — a translation layer over one language is ceremony. But the moment a second
locale is plausible, retrofitting is far more expensive than building the key/catalog
discipline in from the start. The judgment is "will this ever ship in another language",
not "does it today".

## Reviewing an i18n integration

- No user-facing literal strings in components/templates — all via a `t()`/catalog lookup.
- Keys are semantic, namespaced, and not the English source text.
- Plurals and gender use ICU `plural`/`select`, never `n === 1` logic in code.
- Dates, numbers, and currency go through `Intl`/framework locale formatters.
- Layout uses logical CSS properties and a tested RTL mirror; `dir` is set.
- A fallback chain exists; missing keys log and degrade, never show the raw key.
- Extraction is tooling-driven; translators get per-key context.

## Defer rule

- Visual/RTL layout mechanics (logical properties, flip testing) also touch `/ui-ux:review`.
- Locale-aware data storage (collation, timezone columns) → `database-design`.

## Anti-patterns

- **Hardcoded strings** — the retrofit tax; every one is a later find-and-fix.
- **Locale from the browser only** — ignoring an explicit user preference; let users choose.
- **Source text as the key** — breaks when two contexts diverge.
- **Concatenated fragments** — English word order baked into code.
- **`n === 1 ? …` plurals** — English-only; use ICU.
- **Hand-formatted dates/numbers/currency** — wrong in most locales.
- **`margin-left` everywhere** — an LTR assumption RTL cannot mirror.
- **Fixed-width text containers** — German runs ~30% longer than English; a button
  sized to fit "Save" clips "Speichern". Design for text expansion, not the shortest
  language.
