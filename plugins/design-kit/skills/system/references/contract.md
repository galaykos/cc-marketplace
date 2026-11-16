# The design contract: `contract.json`

A short file beside `tokens.json` in `.cc-artifacts/design-kit/design-system/` that says which
component draws a surface, which files own the shell, and where UI code lives. `tokens.json` says
what the values are; the contract says who may use raw markup. Reviews of real sessions found a
frontend with about 230 hand-built `rounded border` boxes against 7 uses of its own `Card`, so a
restyle became a sweep across pages instead of a token and shell change.

```json
{
  "surface": { "component": "Card", "import": "@/components/ui/card" },
  "primitives": ["resources/js/components/ui/"],
  "shell": { "owner": ["resources/js/layouts/"] },
  "scope": ["resources/js/"]
}
```

| Key | Meaning | Default when absent |
|---|---|---|
| `surface.component` / `surface.import` | The component every panel, card or boxed section uses | no surface check |
| `primitives` | Folders where the design system's own components live; they may use raw markup and values | none exempt |
| `shell.owner` | Layout files that draw the app frame (header, sidebar, page slot); they may build their own frame | none exempt |
| `scope` | Paths the contract covers | the whole repo |

Paths are relative to the project root; a folder ends in `/`.

## Who reads it

- ui-ux's `hooks/contract-check.sh`: after an Edit or Write of a markup file in `scope`, names the
  lines the edit added that build a surface by hand (a `div`/`section` with `rounded` and `border`),
  use a raw Tailwind palette class (`bg-gray-100`), or an arbitrary hex or px value (`text-[13px]`).
  Advisory; silent when the file is absent. **Standing: gate** for the patterns it greps
  (`plugins/ui-ux/scripts/__tests__/contract-check.test.sh`); it misses classes split across lines
  or built at runtime, CSS files and Bash writes.
- ui-ux's `ui-ux-engineer` and `ui-ux-reviewer`: build and review against it. **Agent-graded.**

## Drafting it

`/design-kit:system` step 4 drafts it from the component inventory and asks the user to confirm.
A component the inventory did not find is never named; a project without a card primitive gets no
`surface` key, and the hook then checks palette and arbitrary values only.
