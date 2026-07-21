# Token vocabularies per stack

The preview is stack-agnostic; the OUTPUT is not. `theme-shell.html` always
reads the same internal names (`--background`, `--primary`, …) because the
skeleton is written against them. What changes per stack is **where the accepted
values get written and under what names** — and, for Bootstrap, *whether CSS
variables are even the right target*.

Read this after the stack gate in the skill body has resolved.

## What the preview does and does not decide

It decides **colour**: hue, chroma, lightness, surface stepping, contrast
pairing, light-vs-dark behaviour. Those are the same judgments in every stack,
which is why one skeleton serves all of them.

It does **not** decide component look. The skeleton's buttons and cards are
hand-built HTML reading token names — they are not your stack's components. A
Bootstrap project previewing here sees Bootstrap's *palette*, rendered on
generic components. Never present the preview as "this is how your app will
look"; present it as "this is how these colours behave across surfaces and
states". Component-level fidelity is a different tool (design-preview,
shadcn-studio) and a different decision.

## shadcn / ReUI / Aceternity

One vocabulary. ReUI's registry components and Aceternity's motion components
both consume shadcn's CSS variables, so a theme built here applies unchanged —
there is nothing stack-specific to translate.

- Target: `globals.css`, a `:root` block plus a `.dark` block.
- Names: exactly the skeleton's — `background`, `foreground`, `card`,
  `popover`, `primary`, `secondary`, `muted`, `accent`, `destructive`, each
  with its `-foreground` partner, plus `border`, `input`, `ring`, `radius`,
  `chart-1`…`chart-5`, and the optional `sidebar-*` group.
- Dark selector: `.dark`.

## Tailwind (semantic tokens)

Same semantic names as above — this is the model shadcn itself uses. What
differs is the value FORMAT and the mapping layer, and getting it wrong
produces a theme that silently does nothing:

- **v4**: values in `oklch()`, mapped via `@theme inline` in the CSS file. No
  colour block in a config file.
- **v3**: values as bare HSL triplets (`--primary: 222 47% 11%`), consumed by
  `hsl(var(--primary))` mappings in `tailwind.config`. Emit any missing
  mappings alongside the token block.

Read the lockfile for the major version before generating. A Tailwind project
with no shadcn layer has no semantic tokens at all yet — the theme creates that
layer, so say so rather than implying you are editing something that exists.

## Bootstrap 5.3+

The one genuinely different target, in two ways.

**Sass is the primary path, not CSS variables.** Bootstrap is a Sass codebase:
overriding `$variables` before the import regenerates the whole component set
consistently. `--bs-*` runtime variables exist from 5.3 but do NOT restyle
components whose colours were compiled from Sass — a button's background comes
from its own component-scoped `--bs-btn-bg`, set at build time. So a CSS-var-only
"theme" recolours some surfaces and leaves buttons untouched, which reads as a
broken palette rather than as a partial apply. Emit Sass by default; offer the
`--bs-*` block only when the project consumes Bootstrap's precompiled CSS and
has no Sass build to change.

```scss
// _custom.scss — BEFORE the Bootstrap import
$primary:       #1a2b3c;
$secondary:     #5b6470;
$danger:        #b42318;
$body-bg:       #ffffff;
$body-color:    #14161a;
$border-color:  #dfe3e8;
$border-radius: .625rem;
$theme-colors: map-merge($theme-colors, ("brand": #1a2b3c));
@import "bootstrap/scss/bootstrap";
```

**Mapping from the skeleton's names:**

| Preview token | Bootstrap Sass | Bootstrap CSS var |
| --- | --- | --- |
| `background` | `$body-bg` | `--bs-body-bg` |
| `foreground` | `$body-color` | `--bs-body-color` |
| `card` / `muted` | `$secondary-bg`, `$tertiary-bg` | `--bs-secondary-bg`, `--bs-tertiary-bg` |
| `muted-foreground` | `$secondary-color` | `--bs-secondary-color` |
| `primary` | `$primary` | `--bs-primary` (+ `--bs-primary-rgb`) |
| `secondary` | `$secondary` | `--bs-secondary` (+ `-rgb`) |
| `destructive` | `$danger` | `--bs-danger` (+ `-rgb`) |
| `border` | `$border-color` | `--bs-border-color` |
| `radius` | `$border-radius` | `--bs-border-radius` |
| `chart-1…5` | — | no equivalent; keep as project-local vars |

Three traps:

- **`-rgb` companions.** Utilities and `.text-bg-*` read `--bs-primary-rgb`, not
  `--bs-primary`. Set a colour variable without its `-rgb` triplet and those
  utilities keep the old colour.
- **Dark selector is `[data-bs-theme="dark"]`**, never `.dark`. A `.dark` block
  in a Bootstrap project is dead CSS.
- **No per-surface `-foreground` pairing.** Bootstrap has no `card-foreground`
  equivalent; readable pairing comes from `.text-bg-*` helpers and
  `$emphasis-color`. The skill's "every surface ships with a readable partner"
  rule still governs the DECISION — check the contrast pairs in the preview —
  but do not invent `-foreground` Sass variables that Bootstrap will ignore.

## Detection, before asking

Ask only what the repo cannot answer. Collect EVERY signal before deciding —
this is not a first-match cascade. Stopping at the first hit is what silently
mis-targets a migration, where two stacks are present by definition:

- **shadcn** — `components.json` present with `cssVariables: true`.
- **Bootstrap** — `bootstrap` in `package.json` dependencies, or any `.scss`
  importing `bootstrap/scss/bootstrap`.
- **Tailwind** — `tailwindcss` in dependencies. On its own (no
  `components.json`) it means the semantic layer does not exist yet. Alongside
  `components.json` it is not a separate signal — shadcn IS Tailwind-based, so
  that pair is one signal, not two.

Then: exactly one signal → state it and continue. Zero, or two genuinely
different ones (Bootstrap + Tailwind is the real case — a migration in flight)
→ ask outright which target this theme is for. Never guess between them; the
loser gets a theme written to a file it never reads.
