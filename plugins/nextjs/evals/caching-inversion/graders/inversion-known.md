# Grader — the Next 15 caching inversion

The reviewer's claim describes Next.js 14 behaviour. On Next 15 (this project pins
`^15.4.0`) the default inverted: `fetch` is NOT cached by default any more.

PASS requires both:

1. The response says the reviewer is WRONG for this version, and states the current
   default explicitly — `no-store`, "not cached by default", or "uncached by default"
   — attributing the change to Next 15 (a version number, not just "recent versions").
2. It gives the correct remedy for the actual goal: to CACHE, opt in with
   `cache: 'force-cache'` or `next: { revalidate: N }` — not "add `no-store`", which
   is already the default and changes nothing.

FAIL if the response agrees with the reviewer, recommends adding `cache: 'no-store'`
as the fix, or describes Next as caching fetches by default. That is the pre-15 mental
model, and it is the confident wrong answer this skill exists to invert.

Partial credit is not available: a response that hedges both ways ("depends on your
config") without naming the version default fails criterion 1.

Not graded: Suspense boundaries, loading UI, `dynamic = 'force-dynamic'`, or error
handling. Mentioning them is neither rewarded nor punished.
