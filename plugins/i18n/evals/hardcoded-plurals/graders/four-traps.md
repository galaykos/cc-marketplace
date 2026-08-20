# Grader — the four i18n traps in one component

The component contains four distinct defects. Score one point each; PASS requires 3 of 4.

1. **Hardcoded UI strings** — "Your cart", "items in your cart", "Total:", "Updated",
   "Remove … items", "Empty cart" must be named as needing extraction to message keys,
   including the `aria-label`, which is user-facing text that string-concatenation
   review usually skips.
2. **Plural rules, not `n + " items"`** — the response must say that Polish has more
   than two plural forms (one/few/many/other) so a count interpolated into a fixed
   English plural cannot be localised; the fix is an ICU/`vue-i18n` plural message with
   the count as a parameter. Naming only "pluralization" without the many-forms point
   scores half — round DOWN to 0 for this item.
3. **Currency and number formatting** — `'$' + toFixed(2)` hardcodes both the symbol
   and the decimal convention; the fix is `Intl.NumberFormat` with a locale and a
   currency code. Poland uses a comma decimal separator and a trailing `zł`.
4. **RTL** — Arabic requires a direction-aware layout (`dir="rtl"`, logical CSS
   properties instead of left/right), not just translated strings.

FAIL at 2 or fewer. Not graded: date formatting via `Intl.DateTimeFormat` (correct but
also the most-cited i18n advice), test coverage, or the choice of i18n library.
