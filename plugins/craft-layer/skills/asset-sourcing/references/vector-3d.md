# SVG / vector + 3D-model sourcing

SOURCING decisions only — where a vector or model comes from, its format, and its licence. ALL
perf / poly / texture / budget numbers live in Tier 3
(`plugins/craft-layer/skills/motion-tiers/references/tier-budgets.md` +
`.../references/webgl-3d.md`) and `plugins/craft-layer/skills/threejs-best-practices/SKILL.md`.
**No perf recipes here** — cite those.

## SVG / vector

- **Build-in-code first** — a shape, an icon, a simple illustration is often cheaper hand-authored
  as inline SVG (themeable, zero request) than sourced. Reach for a sourcing decision only when the
  fidelity is beyond hand-authoring.
- **Optimise** — run vector output through an optimiser (e.g. SVGO) to strip editor cruft; inline
  small/critical vectors, file-reference large or repeated ones.
- **Licence** — a sourced vector or illustration is under the licence gate (`licence-discipline.md`);
  record class + source.

## 3D models

- **Format** — glTF / GLB is the delivery standard; compress geometry (Draco / meshopt) and
  textures; ship USDZ alongside for iOS AR quick-look when AR is in scope. These are open FORMATS,
  not vendors.
- **Where from (categorical)** — build-in-code (procedural / parametric), an open-source-lib model,
  an asset-marketplace model, or a commission — decide per the six-axis framework in
  `sourcing-decision.md`; the call is licence- and fidelity-driven.
- **Budget + correctness** — poly / texture budgets, draw calls, disposal, and LOD are **owned by
  Tier 3 / threejs** — cite them; never restate a number here.
- **Licence** — a sourced model is under the licence gate; a marketplace model usually carries a
  specific commercial / attribution licence — record it.
