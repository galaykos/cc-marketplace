# marketing-suite

Meta-bundle: turn a working repo or app into launch assets in one install.

- **[marketing-capture](../marketing-capture/README.md)** — auto-detects an
  available browser backend and captures the real running app into framed
  screenshots + a native-only demo GIF under `marketing/`.
- **[marketing-copy](../marketing-copy/README.md)** — slogans, feature blurbs,
  and a demo script grounded in the README, manifests, and the capture captions.
- **[marketing-image-ops](../marketing-image-ops/README.md)** — resize, optimize,
  OG images, favicons, and frames via an adopted third-party image MCP (you
  register one; see that plugin's README).

`design-preview` is used opportunistically as a live-app driver when present —
it is **not** a bundled dependency, so it installs and uninstalls independently.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install marketing-suite@cc-plugins-marketplace
```

## Uninstall

```bash
/marketing-suite:uninstall
```

Removes the bundle and prunes its auto-installed members (`marketing-capture`,
`marketing-copy`); manually installed plugins are untouched.

## Typical flow

1. `marketing-capture` → shoot the real app into `marketing/`.
2. `marketing-image-ops` → resize/optimize the shots, build an OG image + favicon.
3. `marketing-copy` → read those shot captions and write `marketing/copy.md`.
4. Ship the framed screenshots, the GIF, the images, and the copy together.
