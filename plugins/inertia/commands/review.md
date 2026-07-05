---
description: Review Inertia.js code against inertia-best-practices
argument-hint: [files-or-diff]
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
inertia-best-practices skill from this plugin. Invoke the skill first. Before reporting, read
the project manifests (composer.json / package.json and their lockfiles) and pin every finding
to the installed `inertiajs/inertia-laravel` and `@inertiajs/*` versions — do not suggest v2
APIs (deferred props, `usePoll`, prefetching, merge props) on a v1 install, and do not flag
patterns the installed version already solves. Match the idiom to the installed adapter
(`@inertiajs/vue3`, `@inertiajs/react`, or `@inertiajs/svelte`) — never Vue examples for a
React codebase or vice versa. When uncertain about an API or behavior, verify
against the official docs for the pinned version — https://inertiajs.com — instead of answering
from memory. Report findings as `path:line — problem — fix`, ordered by severity. Skip
formatting nits unless they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
