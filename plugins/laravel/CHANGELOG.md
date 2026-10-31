# Changelog — laravel

Consumer-facing changes only. Newest first. Started at 0.10.3; earlier versions have no entries rather than invented ones.

## 0.10.4 — 2026-10-31

- **`laravel-best-practices` now warns that `->change()` drops every modifier you do not restate (Laravel 11+).** The leverage map's Laravel 11 section adds that rule. It also adds Carbon 3's float and possibly negative `diffIn*` results, the `mariadb` driver's native `uuid()` column, and 11's end of support (security fixes ended 2026-03-12).
- **`inertia-best-practices` says where v3 puts the page data**: a `<script type="application/json">` element, no longer the `data-page` attribute. Props stay visible in View Source either way.
- **New eval case `change-drops-modifiers`.** It is an unmeasured candidate: no control arm has run.

## 0.10.3 — 2026-10-28

- **The `inertia-best-practices` skill's description now reads in short, plain sentences.** Same adapters, topics and version note; it keeps the words the model matches it on.
