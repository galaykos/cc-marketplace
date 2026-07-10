# i18n

Internationalization that is cheap to build in and expensive to retrofit.

- **`i18n` skill** — no user-facing string in code (semantic keys resolved from
  catalogs), ICU pluralization and gender, locale-aware dates/numbers/currency via
  `Intl`, RTL with logical CSS properties, fallback chains, and tooling-driven
  extraction. Includes a when-NOT-to-i18n judgment.
- **`/i18n:review`** — flag hardcoded strings, English-only plural logic, hand-formatted
  dates/numbers, and LTR-only layout assumptions.

RTL layout mechanics also touch ui-ux; locale-aware storage touches database.
