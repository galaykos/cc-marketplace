---
name: marketing-copy
description: Use when a project needs marketing words — slogans, feature blurbs, or a demo script — grounded in what the product actually is. Reads the README, plugin/package manifests, a short user brief, and any capture shotlist captions in docs/marketing/, then writes docs/marketing/copy.md. Pure text: no browser, no screenshots, no capture — pair it with a capture skill for the visuals.
---

## What this produces

One markdown file, `docs/marketing/copy.md`, with three sections:

1. **Slogans** — 5–8 candidate taglines, short, each a different angle
   (outcome, speed, pain removed, audience). One is marked the recommended pick.
2. **Feature blurbs** — one tight paragraph per headline capability, benefit
   first, mechanism second.
3. **Demo script** — the narration that pairs with the screenshots/GIF: an
   ordered beat list, one beat per shot, in the shotlist's order when one exists.

Nothing else. This skill does not touch the app, take screenshots, or start a
server — those belong to the capture skill.

## Inputs — ground the words in the product

Gather these before writing a single line; do not invent facts about the product:

- **README** (repo root, and the target plugin's own README when the copy is for
  one plugin) — the source of truth for what it does and who it is for.
- **Manifests** — `plugin.json` / `package.json` / `composer.json` descriptions
  and names, for the honest feature list and the product name.
- **User brief** — ask for it if not given: audience, tone (playful vs.
  enterprise), and the single most important thing to land. Keep it to a
  sentence or two; this is steering, not a questionnaire.
- **Shotlist captions** — if `docs/marketing/` holds captured shots with
  captions (from the capture skill), read them so the demo script and blurbs
  describe exactly what the reader will see. No captions present? The skill
  still runs standalone; the demo script becomes a suggested shot order instead.

If the README is missing or empty, say so and ask for a one-paragraph product
description rather than guessing — wrong copy is worse than late copy.

## Writing discipline

- **Claim only what the inputs support.** Every feature blurb traces to a real
  capability in the README or a manifest. No invented benchmarks, no "10x", no
  superlatives the product cannot back.
- **Benefit before mechanism.** Lead with what the user gets, then how it works.
  "Ship launch screenshots in one command" beats "uses a headless browser".
- **One angle per slogan.** Do not restate the same idea eight ways; span
  outcome, speed, cost, audience, and the pain removed so the user has real
  choices, not near-duplicates.
- **Match the brief's tone.** A playful brief gets playful copy; an enterprise
  brief gets precise, calm copy. When unsure, mirror the README's voice.
- **Keep it tight.** Slogans under ~8 words; blurbs one paragraph; demo beats one
  sentence. Marketing copy earns attention by respecting it.

## Consistency with the visuals

When shotlist captions exist, the copy and the shots must tell the same story:

- Each demo-script beat names the screen it narrates, in shotlist order, so the
  script can be read aloud over the screenshots or GIF without a mismatch.
- A feature blurb that describes a screen should use the same nouns the caption
  uses — if the shot says "Billing", the blurb does not call it "Payments".
- If a caption promises something the README does not cover, flag the gap rather
  than writing copy for a feature you cannot verify.

## Worked shape

The output file follows this skeleton — fill it from the inputs, never ship the
placeholders:

```markdown
# <Product name>

## Slogans
1. <angle: outcome> — **recommended**
2. <angle: speed>
3. <angle: pain removed>
…

## Feature blurbs
### <Capability A>
<benefit-first paragraph, one mechanism sentence>

### <Capability B>
<benefit-first paragraph>

## Demo script
1. **<screen from shot-01 caption>** — <one narration sentence>
2. **<screen from shot-02 caption>** — <one narration sentence>
…
```

The slogan count, blurb count, and demo-beat count all flex to the product — a
one-feature tool gets one blurb, not padding. Match the demo beats to the number
of shots when a shotlist exists.

## Output

Write `docs/marketing/copy.md` with the three sections above, in that order,
under a short H1 naming the product. Create `docs/marketing/` if it does not
exist. If a `copy.md` is already there, show the diff intent and confirm before
overwriting — prior copy may have been hand-edited.

End by reporting the file path and the recommended slogan, so the user has the
one-line takeaway without opening the file.

## Anti-patterns

- Inventing features, metrics, or testimonials not present in the inputs.
- Superlative soup — "revolutionary", "seamless", "cutting-edge" stacked with no
  concrete claim underneath.
- Eight slogans that are one slogan reworded — angles must differ.
- Writing a demo script whose beats contradict the shotlist order or captions.
- Reaching for the browser, a screenshot, or a server — that is the capture
  skill's job; this skill is words only.
- Overwriting an existing `copy.md` without confirming — it may be hand-tuned.
