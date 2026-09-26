# DOM-owning widgets — maps, rich-text editors, charts

> Last verified: 2026-09-26 — https://github.com/maplibre/maplibre-gl-js/blob/main/CHANGELOG.md — npm:maplibre-gl@6.11
> Also re-read that day: https://tiptap.dev/docs/editor/getting-started/install/nextjs and the
> `@tiptap/react`/`@tiptap/vue-3` 3.31.3 source; Livewire 4.x `wire:ignore` and `navigate`
> docs; the lazy-loading guide bundled in next@16.3.6. Leaflet 1.9.4 was imported on Node to
> confirm it throws `window is not defined`.

Standing: **recorded** — loaded with `nextjs-best-practices` (the `/code-review:review`
fan-in or the router) and cited from the `web-developer` agent's domain checklist. No
script or eval checks any rule here, and no control arm has shown the base model failing
them; the two version breaks below are the candidates for one.

These live in one file, not per framework, because the library owns its DOM subtree
whatever renders the page around it. The same four rules hold under Next, Inertia
(React or Vue) and Livewire; only the mount hook differs.

## The four rules

1. **Create on the client, after the container exists.** The constructor needs a real
   element (`new Map({ container })`, `new Editor({ element })`, `new Chart(canvas, …)`);
   the server has none. Create in the effect/mount hook, never at module scope or in render.
2. **One instance per mount, destroyed on unmount** — `map.remove()`, `editor.destroy()`,
   Chart.js `chart.destroy()`. Keep the instance in a ref; do not recreate it on every
   render. React Strict Mode mounts twice in development, so a missing cleanup shows up as
   two maps or two editors. Tiptap's `useEditor` (React and Vue) destroys for you; a
   hand-built `new Editor()` does not.
3. **Keep the host framework out of the widget's DOM.** Under Livewire, put `wire:ignore`
   on the container so a re-render does not overwrite what the library built. Under
   `wire:navigate`, `DOMContentLoaded` fires only on the first visit, so initialise on
   `livewire:navigated` (it also fires on first load), or in an Alpine `x-data` whose
   `destroy()` tears the instance down. Under React or Vue, the container renders no
   children of its own.
4. **An editor's HTML output is an XSS sink.** `editor.getHTML()` returns whatever the user
   typed or pasted. Stored and rendered back, it is user-controlled markup: sanitise at
   render time (DOMPurify in the browser, or the server's HTML sanitiser), and never pass it
   raw to `dangerouslySetInnerHTML`, `v-html` or Blade `{!! !!}`. Sanitising on input
   alone is not enough. Where the product allows it, store `editor.getJSON()` instead. The
   general rule lives in `security:security-review` ("XSS").

## Mount per host

| host | create | destroy |
|---|---|---|
| Next (App Router) | `useEffect` on a ref inside a `'use client'` component. `'use client'` still prerenders on the server, so a library that reads `window` at import (Leaflet 1.9) needs `next/dynamic(() => import('./Map'), { ssr: false })`, called from a Client Component; it throws in a Server Component | the effect's cleanup |
| Inertia + React / Vue | `useEffect` / `onMounted` on a ref; with Inertia SSR on, load a library that reads `window` at import with `import()` inside that hook | cleanup / `onBeforeUnmount` |
| Livewire (+ Alpine) | `wire:ignore` container; Alpine `init()` or a `livewire:navigated` listener | Alpine `destroy()` |

## Version breaks a mid-2025 memory gets wrong

**Tiptap 3 with React under SSR** (Next, or Inertia React with SSR on): pass
`immediatelyRender: false` to `useEditor`, from a client component (`'use client'` on Next).
Install `@tiptap/react`, `@tiptap/pm` and `@tiptap/starter-kit`. Set the option explicitly.
When it is unset, `@tiptap/react` 3.x falls back to `false` only where it detects Next, with
a dev warning. Under any other SSR host it renders immediately on the client, and the result
does not match the server HTML (a hydration mismatch). The option is React-only:
`@tiptap/vue-3`'s `useEditor` already creates the editor in `onMounted`.

**MapLibre 6** (6.0 breaking changes):
- ESM-only. Write `import * as maplibregl from 'maplibre-gl'` or named imports
  (`import { Map } from 'maplibre-gl'`). There is no default export: 6.11.2's `.d.ts` and
  `.mjs` export none, so `import maplibregl from 'maplibre-gl'` is the 5.x habit.
- The UMD bundles are no longer published, so a CDN `<script>` becomes
  `<script type="module">`.
- The CSP bundle is gone. The worker now loads as a real URL, so the `worker-src blob:`
  workaround is no longer required.
- WebGL2 is required (WebGL1 support is removed). Listen on `map.on('error', …)` and render
  a non-map fallback (a list or table of the same places) when no WebGL2 context exists.
- `GeoJSONSource.setData(data)` lost its second argument (`waitForCompletion`) and no longer
  returns `this`, so do not chain it.

## When NOT to apply

A static map image, a server-rendered SVG chart or a read-only rendered document owns no DOM
after load. None of the lifecycle rules apply to it, but rule 4 still applies to any stored
HTML it renders.
