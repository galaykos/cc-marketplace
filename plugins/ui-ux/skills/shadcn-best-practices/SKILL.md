---
name: shadcn-best-practices
description: Use when building or reviewing shadcn/ui components — CLI installs, composition over config, CSS-variable theming, accessibility defaults.
---

## You own the code, it isn't a dependency

shadcn/ui components are copied into your repo via the CLI (`npx shadcn add button`), not
installed as an npm package. Once generated, that file is yours: no upstream version to bump,
no changelog to track, and no excuse for leaving generated cruft unread. Treat `components/ui/*`
as first-party source, review it in PRs like any other code, and expect to edit it directly.

- Good: run the CLI, then open the generated file and adapt it to the project's needs.
- Bad: `npm install shadcn-ui` style thinking — waiting for "updates" or refusing to touch the
  file because "it's a library component."

## Customize the component source, not wrapper hacks

When a component needs different behavior or styling, edit the copied source in
`components/ui/`. Do not wrap it in another component that fights its defaults with extra props,
`!important`, or DOM overrides — that adds an indirection layer with no benefit since you already
own the original file.

```tsx
// Good: edit components/ui/button.tsx directly to add a new variant
const buttonVariants = cva(base, {
  variants: { variant: { ..., brand: "bg-brand text-white hover:bg-brand/90" } },
});

// Bad: leave button.tsx untouched and wrap it
function BrandButton(props) {
  return <Button {...props} className="!bg-brand !text-white hover:!bg-brand/90" />;
}
```

## Theme via CSS variables, not per-component overrides

shadcn/ui components read color, radius, and spacing from CSS custom properties defined in your
global stylesheet (`--background`, `--primary`, `--radius`, etc.). Change the theme by editing
those variables in one place, not by hardcoding colors into individual component files.

```css
/* Good: app/globals.css */
:root { --primary: 222 47% 11%; --radius: 0.5rem; }
.dark { --primary: 210 40% 98%; }
```

```tsx
// Bad: hardcoded hex values inside a single component
<Button className="bg-[#1a2b3c] rounded-[3px]">Save</Button>
```

## Keep Radix accessibility props intact

Most interactive shadcn/ui components (Dialog, Dropdown, Select, Popover) wrap Radix primitives
that manage focus trapping, `aria-*` attributes, and keyboard navigation for you. When you extend
markup, preserve the underlying Radix parts (`Root`, `Trigger`, `Content`, `Portal`) and pass
through `...props` so consumers can still set `aria-label`, `aria-describedby`, etc.

- Good: `<DialogContent aria-describedby={descId}>{children}</DialogContent>`
- Bad: replacing `DialogContent` with a plain `<div>` because "it's simpler," losing focus trap
  and `Escape`-to-close behavior.

## Compose primitives, don't reconfigure through props explosion

shadcn/ui favors composition (`Card`, `CardHeader`, `CardContent`, `CardFooter`) over a single
component with a dozen boolean props. When a component needs a new arrangement, compose the
existing pieces in new markup rather than adding `showHeader`, `hideFooter`, `variant2` flags.

```tsx
// Good
<Card>
  <CardHeader><CardTitle>Plan</CardTitle></CardHeader>
  <CardContent>{body}</CardContent>
</Card>

// Bad
<Card showHeader hideFooter title="Plan" body={body} />
```

## Don't fork the design language per component

Every component pulls from the same design tokens (spacing scale, radius, color roles). If one
screen needs a different look, change the tokens or add a documented variant in `cva()` — don't
let a single feature quietly introduce a one-off border radius or shadow that only exists in that
file. Inconsistent one-offs are how design systems rot.

- Good: add a `variant: "compact"` to the shared `cva` config, used wherever needed.
- Bad: `className="rounded-[2px] shadow-[0_1px_2px_rgba(0,0,0,0.4)]"` inline in one form.

## Install only what you use, and re-run the CLI for updates deliberately

The CLI adds one component (and its Radix dependency) at a time. Don't bulk-copy the entire
registry "just in case." If you want to pull in upstream fixes later, re-run
`npx shadcn add <component> --overwrite` deliberately and diff the result — don't silently
overwrite local customizations.

## Common mistakes

- Wrapping components in `!important`-laden CSS instead of editing the source file.
- Deleting Radix `Portal`/`Root` wrappers, breaking focus management and z-index stacking.
- Hardcoding colors instead of referencing theme CSS variables, breaking dark mode.
- Letting `components/ui` drift from the rest of the codebase's lint/format rules because "it's
  generated code."
- Adding boolean-prop soup to a component instead of composing existing subparts.
- Forgetting to run `npx shadcn add` for a new primitive and hand-rolling a Radix wrapper instead.

## Verify Against Current Docs

shadcn/ui's CLI flags, registry structure, and component APIs change between releases. Before
relying on memory for install commands, theming variables, or a specific component's props,
check the current docs: https://ui.shadcn.com
