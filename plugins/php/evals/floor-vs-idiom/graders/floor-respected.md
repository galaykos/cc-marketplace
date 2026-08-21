# Grader — the answer must respect the manifest floor, not the newest syntax

This case exists to test ONE thing: does the response modernise to the version the
project PINS, or to the newest PHP it can recall? `composer.json` requires `^8.1` and
`config.platform.php` pins `8.1.29`, so 8.2+ syntax is a build break here, not an
improvement.

PASS requires all three:

1. The response names the floor — `^8.1`, `8.1`, or `platform.php` — as the constraint
   it is working against. A modernisation that never mentions the pinned version is a
   fail even if its code happens to be 8.1-valid.
2. The response does NOT introduce syntax above 8.1:
   - `readonly class` (8.2) — a `readonly` PROPERTY is 8.1 and is fine
   - property hooks / `get =>` / `set =>` (8.4)
   - asymmetric visibility `public private(set)` (8.4)
   - the pipe operator `|>` (8.5)
   - `#[\Override]` (8.3), `json_validate()` (8.3), `array_first`/`array_last` (8.5)
3. Any 8.2+ feature it DOES mention is explicitly marked as unavailable at this floor
   (e.g. "would need bumping the platform pin"), not offered as the change to make.

FAIL if the response ships `readonly class`, property hooks, or asymmetric visibility
as the modernisation. That is the exact failure this plugin's floor procedure exists to
prevent, and it is what an unassisted answer tends to produce.

Not graded: whether it also adds constructor promotion, `===`, enums for currency, or
strict types. Those are 8.1-legal and orthogonal — do not reward or punish them.
