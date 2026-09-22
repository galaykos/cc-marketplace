# Board spec format

`scripts/board-build.py <spec>` accepts JSON or markdown. Write the spec to
`.design-kit/boards/<slug>.spec.json` (or `.md`) so a later round can edit one artboard and
rebuild; the builder writes the board beside it.

## JSON

```json
{
  "title": "Invoice inbox",
  "brief": "Accountants triage 200 invoices a day",
  "device": "desktop",
  "css": ".dk-hero h1{max-width:18ch}",
  "boards": [
    {"title": "Dense table", "tradeoff": "Fastest scan; weakest on phone", "body": "<nav class=\"dk-nav\">…</nav>…"},
    {"title": "Card queue", "tradeoff": "One decision at a time; slower bulk work", "device": "phone", "body": "…"},
    {"title": "Split view", "tradeoff": "Context without leaving the list; needs width", "device": "tablet", "body": "…"}
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `title` | yes | board title; also the file slug |
| `brief` | no | one line shown in the top bar |
| `device` | no | default frame for artboards that name none: `phone` 375×812, `tablet` 768×1024, `desktop` 1280×800 |
| `css` | no | extra CSS injected once for the whole board (the signature element, a column width) |
| `boards[]` | 2–4 | one per direction |
| `boards[].title` | yes | short, names the structural idea ("Split view", not "Option B") |
| `boards[].tradeoff` | yes | one line: what this direction wins and what it costs |
| `boards[].device` | no | overrides the board default |
| `boards[].body` | yes | HTML from `primitives.md`; no external references, no lorem |

## Markdown

```markdown
# Onboarding
Brief: New sellers list a first product in under five minutes
Device: phone

## Board: Single scroll
Trade-off: No navigation to learn; long on small screens
```html
<div class="dk-pad dk-stack">…</div>
```

## Board: Stepper
Trade-off: Progress is visible; four taps minimum
Device: tablet
```html
…
```
```

The first `#` heading is the title; `Brief:` and `Device:` lines before the first
`## Board:` apply to the board; each `## Board:` section takes `Trade-off:`, an optional
`Device:`, and one fenced `html` block as its body.

## Flags

| Flag | Effect |
|---|---|
| `--out <path>` | write here instead of `.design-kit/boards/YYYY-MM-DD-<slug>.html` |
| `--tokens <file>` | DTCG tokens for accent/spacing/radius/font; default `design-system/tokens.json` when present; the path heuristics used are printed to stderr |
| `--device phone\|tablet\|desktop` | default frame when the spec names none |
| `--docroot <dir>` | default `.design-kit` |

Exit 2 names the gate that failed: artboard count outside 2–4, an empty body, lorem
ipsum, an external reference, an unknown device, or an unfilled shell slot.
