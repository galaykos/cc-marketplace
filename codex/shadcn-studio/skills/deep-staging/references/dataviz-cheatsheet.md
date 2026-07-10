# Dataviz cheat-sheet (frozen floor)

The minimal chart-form guidance for the **dataviz lane** when the host `dataviz`
skill is **not** installed. Deliberately small and **frozen** — it does not track
the host skill. If the host `dataviz` skill is present, ignore this file and let
it govern.

## Chart form by question

Pick the mark from the question the decision asks, not from the data type:

| The question is about… | Mark |
|---|---|
| Comparing values across categories | Bar (horizontal if labels are long) |
| A trend over time | Line (or area for one cumulative series) |
| Part-of-whole, few slices | Stacked bar; pie only for ≤3 slices, never for precise reads |
| Correlation between two measures | Scatter |
| Distribution of one measure | Histogram |
| A single number or 2–3 KPIs | A stat tile or a small table — **not** a chart |

When ≤3 numbers answer the question, a chart is decoration. Use a stat tile.

## Encoding discipline

- Rank encodings by accuracy: **position > length > angle/area > color**. Put the
  variable that matters most on position or length; never on area or color alone.
- One encoding per variable. Do not also color-code what position already shows.
- Start bar axes at zero. Line axes may crop, but say so.
- Sort categorical bars by value, not alphabetically, unless order is inherent.
- Direct-label where you can; a legend is a lookup tax on every read.

## Color

- Use the sandbox's `--chart-1..5` tokens as the categorical palette — they are
  theme-aware and contrast-checked. Do not introduce raw hex.
- Categorical: distinct hues, ≤5 series; beyond that, group the tail into "Other".
- Sequential/diverging (a magnitude ramp): a single-hue light→dark scale, or a
  two-hue diverging scale around a meaningful midpoint — never a rainbow.
- Never encode meaning by color alone; pair with label, position, or pattern for
  color-vision accessibility.

## The four states (dataviz lane)

- **populated** — the chart with realistic data and a working tooltip.
- **empty** — "No data for this period", not an empty axis frame.
- **loading** — a Skeleton the size and shape of the chart, not a spinner.
- **error** — a clear failure message with a retry affordance.

## When NOT to chart

- The answer is one number → stat tile.
- The reader needs exact values → table.
- There is no decision behind the chart → cut it; dataviz is a decision lane.
