# Page patterns — archetypes a new page starts from

Every mockup request is one of a dozen shapes. Start from the shape, then let
the gestures move it. Each row is the blocks from `skins.md`'s vocabulary the
page is built from and the states it must declare. Realistic content always:
names, numbers that agree with each other, dates near today, no lorem.

| archetype | shell | blocks | states to declare |
|---|---|---|---|
| Landing / marketing | `.container` | `.hero` + `.display` + two `.btn`, logo row (`.logo`), `.cols-3` feature `.card`s with `.icon`, `.img-wide` product shot, testimonial `.card` with `.avatar`, pricing `.cols-3`, footer `.row.between` | — |
| Auth (sign in / up / reset) | `.container` narrow (`max-width: 24rem`) | `.logo`, `h1`, `.field`×n, `.check`, `.btn-primary` full width, `.divider`, `.btn-secondary` SSO, `.muted` switch link | `error` (`.field.invalid` + `.alert-danger`) |
| Onboarding / wizard | `.container` | `.breadcrumb` or `.segmented` as steps, one `.card` per step, `.progress`, `.actions` back/next | — |
| Dashboard | `.app` + `partials/sidebar` | `.topbar` with `.search`, `.pagehead`, `.cols-4 .stat`s with `.spark`, `.cols-main-aside`: `.chart` + `.feed` or `table` | `empty` (first run), `loading` (`.skeleton`s) |
| List / index | `.app` | `.pagehead` with `.btn-primary` create, filter `.row` (`.search`, `.select`, `.segmented`), `table` with `.badge`, `.avatar`, `.num`, `.pagination` | `empty` (`.empty` with `.icon` + create CTA), `loading` |
| Detail / record | `.app` | `.breadcrumb`, `.pagehead` with `.avatar-lg` + `.badge` + `.dropdown .menu`, `.tabs`, `.cols-main-aside`: sections as `.card`, sidebar `.list` of facts | `error` (not found) |
| Form / editor | `.app` or `.container` | `.card` per section, `.field`s in `.cols-2`, `.textarea`, `.switch`, sticky `.card-foot` with save/cancel | `error` (validation), `loading` (saving) |
| Settings | `.app` | left `.tabs` vertical or `.list`, right `.card`s per group, `.switch` rows, danger zone `.alert-danger` + `.btn-danger` | — |
| Inbox / messaging | `.app` | three columns: `.list` of threads with `.avatar` + `.dot`, message `.feed`, composer `.textarea` + `.btn-primary` | `empty` (no thread selected) |
| Checkout / order | `.container` | `.cols-main-aside`: `.field`s (address, payment with `.icon` credit-card) / summary `.card` with `.list`, `.btn-primary` pay | `error` (payment declined) |
| Kanban / board | `.app` | `.pagehead` with `.avatars` + filter, `.kanban` `.col`s of `.deal` cards with `.badge` | `empty` |
| Empty / error / 404 | `.container` | `.empty` with `.icon`, `h2`, `.muted`, `.btn-primary` back | — (it is the state) |

Mobile: the same page narrows through the panel's viewport select. Check it
once per archetype before calling the page done — a sidebar that becomes a
wrapped row is fine, a table that scrolls sideways is fine, a `.cols-4` that
stays four columns is not.
