# Primitive bases: Radix, Base UI, React Aria

> Last verified: 2026-09-26 — https://ui.shadcn.com/docs/changelog — npm:shadcn@4

Read this after the SKILL body's base section sends you here. Every rule below is
**recorded**. It was checked against the live shadcn and Base UI docs on the stamp date, and
no script reads a project's base.

## Detect the base; never assume Radix

| signal in `components.json` | base | package |
|---|---|---|
| `"style": "base-<preset>"` | Base UI | `@base-ui/react` |
| `"style": "radix-<preset>"`, or legacy `"new-york"` / `"default"` | Radix | `radix-ui` (older: `@radix-ui/react-*`) |
| `"style": "aria-<preset>"` | React Aria | `react-aria-components` |

- The name after the prefix (`vega`, `nova`, `maia`, `lyra`, `mira`, `luma`, `sera`, `rhea`)
  is a visual preset. Only the prefix names the base. `style` cannot be changed after init.
  `default` is deprecated, and both it and `new-york` date from before the prefixes existed,
  when Radix was the only base.
- `package.json` lists both `@base-ui/react` and `radix-ui`: the project is mixed. That means
  a migration in progress, or blocks pulled from a registry on the other base. Apply the rules
  below per FILE: read the file's primitive import before you edit it.
- `@base-ui-components/react` is Base UI's old package name. npm marks it "renamed to
  @base-ui/react", and its last release was `1.0.0-rc.0`. Treat it as Base UI. It is also a
  duplicate-package hazard (see `registries.md`).
- `npx shadcn init` produces Base UI when run without options. A script or CI job that
  expects Radix must pass `-b radix` (`--base base|radix|aria`).
- On React Aria, components wrap React Aria parts (`Modal`, `ModalOverlay`, `Dialog`,
  `Heading`), and the Aria registry scopes its own state selectors. Read the installed file
  instead of porting Radix or Base UI classes into it.

## What a Radix habit gets wrong on Base UI

| Radix habit | Base UI form | what happens if you keep the habit |
|---|---|---|
| `<DialogTrigger asChild><Button>Open</Button></DialogTrigger>` | `<DialogTrigger render={<Button variant="outline" />}>Open</DialogTrigger>` | Base UI has no `asChild` prop, so the child `<Button>` renders nested inside the trigger's own `<button>` |
| `render` pointed at a non-button element, e.g. `render={<div />}` | also pass `nativeButton={false}` | `nativeButton` defaults to `true`, and Base UI then assumes a native `<button>` |
| a link styled as a button: `<Button asChild><a href="…" /></Button>` | `<a href="…" className={buttonVariants({ variant: "secondary" })}>` | `render={<a />} nativeButton={false}` puts `role="button"` on the link. shadcn's Button docs forbid it |
| `data-[state=open]:animate-in`, `data-[state=closed]:…` | `data-open:animate-in`, `data-closed:…` | Base UI sets `data-open` / `data-closed` and never `data-state`, so the class never matches |
| `DialogPrimitive.Content` / `.Overlay` in `components/ui/dialog.tsx` | `DialogPrimitive.Popup` / `.Backdrop`. Menus, popovers and selects also have a `Positioner` inside `Portal` | those parts do not exist on Base UI |

The shadcn wrapper names stay the same on every base (`DialogContent`, `DialogOverlay`).
Part names matter only when you edit a `components/ui` file or write against the primitive
directly.

Prefer `data-open:` and `data-closed:` on **both** bases. `shadcn/tailwind.css` defines them
to match Radix's `[data-state="open"]` as well as Base UI's `[data-open]`. It defines the same
pair for `data-checked`, `data-unchecked` and `data-disabled`, plus `data-active`,
`data-selected`, `data-horizontal` and `data-vertical`. Without that import, Tailwind v4's
built-in `data-open:` still matches `[data-open]` but not Radix's `data-state`.

## Styling plumbing (Tailwind v4, every base)

- The global stylesheet imports `tailwindcss`, then `tw-animate-css`, then
  `shadcn/tailwind.css`.
  - `tw-animate-css` replaced `tailwindcss-animate`, which was deprecated in March 2025. It is
    loaded with a CSS `@import`, not a `@plugin`.
  - `shadcn/tailwind.css` comes from the `shadcn` package. It carries the custom variants above
    and the accordion keyframes. Do not drop `shadcn` from dependencies while that import
    remains. `npx shadcn eject` inlines the file and removes the dependency, and cannot be
    undone.
- **`cn`** (since 2026-09-03): components use `import { cn } from "cn"`, a drop-in for
  `twMerge(clsx(...))`, and `lib/utils.ts` becomes `export { cn } from "cn"`.
  - New code follows whichever form the project already uses. Components added to an older
    project install `cn` alongside `lib/utils.ts`, and the old helper keeps working.
  - `npx shadcn@latest migrate cn` rewrites the imports and removes `clsx` / `tailwind-merge`
    once nothing references them. It is **Tailwind v4 only**: a v3 project stays on
    `tailwind-merge` v2.
- **`npx shadcn@latest migrate radix` does NOT move a project from Radix to Base UI.** It
  rewrites `@radix-ui/react-*` imports to the unified `radix-ui` package.
  - Moving to Base UI is done by shadcn's migration skill (`npx skills add shadcn/ui`, then ask
    to "migrate <component> to base-ui"). It works one component at a time and writes a report
    to `.migration/`.
  - Nothing requires migrating. Radix is supported and not deprecated.

## Drawer and Toast differ per base

- **Drawer on Base UI** is built on Base UI's Drawer. It does not use `vaul`, so do not
  install it. Its props differ from vaul's:
  - `swipeDirection="down|up|left|right"`, not `direction="bottom"`;
  - `snapPoint` / `onSnapPointChange`, not `activeSnapPoint` / `setActiveSnapPoint`;
  - `onOpenChangeComplete`, not `onAnimationEnd`;
  - `initialFocus={false}`, not a prevented `onOpenAutoFocus`;
  - `disablePointerDismissal`, not `dismissible={false}`.

  Selectors use `data-swipe-direction`, not `data-vaul-drawer-direction`. vaul-only props
  (`handleOnly`, `repositionInputs`, `shouldScaleBackground`) have no equivalent.
- **Drawer on Radix** still uses vaul (`1.1.2`, December 2024). The vaul README says the
  repository is unmaintained, so pin it and do not wait for fixes.
- **Toast on Base UI:** `npx shadcn add toast`, then `import { toast } from
  "@/components/ui/toast"`. Show one with `toast.add({ title, description, actionProps })`
  and close it with `toast.close(id)`. The docs URL `/docs/components/base/sonner` now serves
  this Toast page.
- **Toast on Radix:** the old `toast` / `useToast` is deprecated. Use `sonner`
  (`import { toast } from "sonner"`, plus one `<Toaster />`).
- A Base UI project that already ships sonner may keep it. The Base drawer demo in shadcn's
  own docs still imports `toast` from `"sonner"`. Do not add a second toast system next to it.
