# Third-party shadcn registries: install mechanics

> Last verified: 2026-09-26 — https://ui.shadcn.com/docs/registry/namespace — npm:shadcn@4

This file covers registries as **install sources**: where the code comes from and how to pull
it in safely. It does not treat them as design references and never recommends a block for a
brief. That is a design decision, and craft-layer's design-research owns it when installed.

ReUI and Aceternity also have their own skills in the `ui-libraries` plugin. The mechanics
here apply underneath them. Every rule below is **recorded**: it was checked against the live
docs and registry endpoints on the stamp date, or on the date written beside it, and no script
enforces it.

## Three ways a registry resolves

1. **The built-in directory.** `npx shadcn@latest add @<registry>/<item>` works with no
   configuration for every namespace in https://ui.shadcn.com/r/registries.json (browsable at
   https://ui.shadcn.com/docs/directory).
   - On the stamp date the directory had 382 entries: 299 healthy, 43 degraded, 39 unavailable
     and 1 under observation.
   - Read the entry's `health.status` before you promise an install. An `unavailable` registry
     fails at `add`, not at planning.
   - To browse, run `npx shadcn@latest search @<registry> -q "<term>"` (`list` is an alias).
2. **The `components.json` `registries` field.** Use it for a namespace the directory lacks, a
   private registry, or one that needs auth:

   ```json
   {
     "registries": {
       "@acme": "https://registry.acme.com/r/{name}.json",
       "@acme-pro": {
         "url": "https://registry.acme.com/r/{style}/{name}.json",
         "headers": { "Authorization": "Bearer ${ACME_TOKEN}" },
         "params": { "version": "latest" }
       }
     }
   }
   ```

   - `{name}` is required. `{style}` is optional and is replaced by the project's `style`, so a
     `{style}` registry serves the file built for YOUR base (`base-nova` vs `radix-nova`; see
     `bases.md`). When a component arrives on the wrong base, check the style first.
   - `${VAR}` is expanded from the environment in `url`, `headers` and `params`. Keep the token
     in `.env.local` and never write the literal value into `components.json`.
   - Paid tiers need this object form. At probe time, shadcnblocks and Skiper UI Pro items
     returned 401 to anonymous requests.
3. **A direct URL or GitHub address.** Use `npx shadcn add https://host/r/item.json`, or
   `owner/repo/item` for a GitHub registry. Private repositories work when the GitHub CLI is
   logged in.

## Look before you write

- `npx shadcn@latest view @reg/item` prints the item's files, dependencies,
  `registryDependencies`, CSS variables and required env vars. Check the dependencies against
  the hazards below before you run `add`.
- `add --dry-run` previews what `add` would do, and `add --diff [path]` diffs one file against
  your copy. Only after both, run `--overwrite`.
- Files are deduplicated by target path, and **the last one resolved wins**.
  - `add @a/auth @b/login-form` lets `@b`'s `login-form` silently replace `@a`'s.
  - `registryDependencies` resolve before the item itself.
  - `cssVars`, `tailwind` and `css` are deep-merged, so a registry's theme values can overwrite
    yours. Diff the global stylesheet after every third-party `add`.

## Two duplicate-package hazards

- **`motion` vs `framer-motion`.** These are one library under two names (both `14.0.0` on npm,
  2026-10-06). Most registries depend on `motion` (`motion/react`), but Skiper UI's free items
  depend on `framer-motion`.
  - Installing both ships two copies, and `MotionConfig` / `LazyMotion` context does not cross
    between them.
  - Rewrite the imports to whichever package the project already has.
  - A registry can also pin an older major. In a project on motion 14, `add --dry-run` for
    `@react-bits/CountUp-TS-TW` listed `motion@^12.23.12` as a dependency to add (2026-10-06),
    and a caret range never resolves to 14. Read the pin in `--dry-run` or `view` and keep the
    project's major.
- **`@base-ui/react` vs `@base-ui-components/react`.** These are Base UI's current and
  pre-rename package names.
  - Animate UI items still declare the old name (17 of 580 items). shadcn's Base components
    and coss use the new one.
  - Two copies means two separate portal and focus contexts. Rewrite the imports to
    `@base-ui/react`.

## Registries that break the generic rule

| registry | how it installs | the rule |
|---|---|---|
| **Tremor** | Not in the directory, and no CLI install. It is copy-paste from tremor.so, built on Recharts and individual `@radix-ui/react-*` packages. The npm `@tremor/react` is stale: `3.18.7` from 2025-01-13, with a React 18 peer | Use the copy-paste code, not the npm package. Its chart colours are `chartColors` in `chartUtils.ts`, which are Tailwind palette classes (`bg-blue-500`), not tokens. Remap them to `var(--chart-N)`, or the charts fork from the theme. Its chart API is its own, not shadcn's `ChartContainer` |
| **coss ui** (formerly Origin UI; originui.com 301s to coss.com/ui) | `@coss` is in the directory: `init @coss/style`, or `add @coss/ui` | It is built on Base UI, and `@coss/ui` installs its full primitive set into `components/ui` under shadcn's file names. On a Radix project it overwrites your primitives with a different base. Match the base first, or add only its composed items |
| **21st.dev** | Not in the directory. Each component has its own registry URL, and an anonymous `/r/…` request returned 403 "Authentication required" | Needs a 21st API key; the free tier allows 2 installs a day. Its llms.txt says the key goes in an `x-api-key` header or as a Bearer token. Put it in an env var through the object form, never in a pasted command or your shell history. Items are per-author, so review deps, colours and a11y as third-party code |
| **React Bits** | `@react-bits` is in the directory, with four variants per component: `-JS-CSS`, `-JS-TW`, `-TS-CSS`, `-TS-TW` (e.g. `@react-bits/Aurora-TS-TW`). `add` writes `components/<Name>.tsx`, outside `components/ui/`. Its README counted 200+ components on 2026-10-06. The same items install through jsrepo (below) | Pick `-TS-TW`. Read an item's props from `npx shadcn@latest view @react-bits/<Name>-<variant>` before writing usage, never from memory: each component has its own API. On 2026-10-06 CountUp took `to`/`from`, not the `end`/`start` remembered from react-countup. Its motion items import `motion/react` and pin motion 12 (the motion hazard above). Runtime deps are heavy (`ogl`, `gsap`, `three`, `motion`), so price the bundle with craft-layer's `motion-tiers` when installed. Colours are props, not tokens: wire them to CSS variables. The licence, read 2026-10-06, is MIT + Commons Clause: use inside a product is allowed, selling or redistributing the components themselves is not |
| **Magic UI** | `@magicui` is in the directory: `npx shadcn@latest add @magicui/<name>` writes `components/ui/<name>.tsx`, beside shadcn's primitives. Its motion items import `motion/react` | Check each item's dependency ranges in `view`. On 2026-10-06 Globe declared `cobe@^0.6.4` while npm's `cobe` was 2.0.1, so a project already on cobe 2 hits a major conflict. Keep one major, and test Globe on it before you ship |

A **theme** registry such as tweakcn installs a `registry:style` item, not components. The
`shadcn-theming` skill governs it.

## jsrepo, the second copy-in CLI

Read 2026-10-06 against the `jsrepo@3.8.1` package.

- `jsrepo add` writes the item's source files into your tree. The result is owned code, like a
  shadcn `add`, not an npm dependency, so the owned-code rules apply to it.
- Since 3.0 its config is `jsrepo.config.ts` (`.mts` in a package that is not `"type":
  "module"`). The `jsrepo.json` you may remember is the 2.x format, and 3.x does not read it.
  The config needs a `paths` entry for the item's type (`component` for React Bits) before
  `add` can write the item. Without one, `add` stops with "No path was provided".
- `add` has no `view` or `--dry-run`. Read the item's source at its registry URL first, and
  leave `--yes` and `--overwrite` off a first install so its prompts still fire.
- React Bits serves the same items to jsrepo by URL:
  `npx jsrepo@latest add https://reactbits.dev/r/<Name>-<variant>`.
