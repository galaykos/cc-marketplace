---
name: cmd-testing-review
description: "Use when the user asks to review test code and coverage against testing-best-practices."
---

_This skill wraps the `/testing:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the test code in $ARGUMENTS (or the current diff if no argument) against
the testing-best-practices skill from this plugin. Invoke the skill first. Before
reporting, read the project manifests (composer.json / package.json and their
lockfiles) and pin every finding to the installed test-stack versions
(pestphp/pest, phpunit/phpunit, laravel/dusk, vitest, jest, @playwright/test,
@testing-library/*, msw) — do not flag patterns the installed version already
solves, and do not suggest APIs above it. Also review coverage of the diff:
for production code changed without a corresponding test, name the missing test
and the pyramid layer it belongs at. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.

When findings or missing tests exist, offer the next step as a selectable
choice (AskUserQuestion): "Apply the fixes and write the missing tests now
(Recommended)" / "Skip — report only". Bare instructions only when headless.
