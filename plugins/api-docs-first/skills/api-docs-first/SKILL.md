---
name: api-docs-first
description: Use before writing any code that calls an external API, SDK, or third-party library — verify current official docs first; if docs are not accessible, stop and ask the user for a docs URL or file. Never code an integration from memory alone.
---

## Why this exists

Training data has a cutoff. Libraries and APIs do not stop shipping releases on that date —
method signatures get renamed, auth flows get replaced, pagination styles change, error
response shapes are restructured, whole endpoints are deprecated. Writing integration code
from memory means writing code against a version of the API that may no longer exist. The
fix is cheap: check the docs for the version actually in use before writing the call, not
after it fails in review or in production.

## The procedure

1. **Identify the exact library/API and version — from the lockfile or manifest, not from
   imports alone.** An `import stripe from "stripe"` tells you nothing about which major
   version is installed. Check `package-lock.json`, `package.json`, `composer.lock`,
   `Gemfile.lock`, `requirements.txt` / `poetry.lock`, `go.mod`, `Cargo.lock`, or the
   equivalent for the ecosystem. For a remote API (not a library), identify the API version
   from config, base URL path (`/v2/`), or the account/service dashboard if there's ambiguity.
   Do not assume the version matches whatever you last saw in training data.

2. **Locate current official docs for that exact version.** In order of preference:
   - WebFetch or WebSearch the vendor's official docs site, if available in this environment.
   - A local docs directory in the repo (`docs/`, `api-docs/`, a vendored OpenAPI/Swagger
     spec, generated SDK reference).
   - A vendored README or CHANGELOG shipped inside `node_modules/<pkg>`,
     `vendor/<pkg>`, or the installed package's own docs folder.
   - IDE-installed type stubs or `.d.ts` files — these reflect the actual installed version's
     public surface even when prose docs are unreachable, and are good for confirming method
     signatures exist and their parameter shapes.
   Prefer sources that are version-pinned or clearly dated over generic "latest" pages when
   the installed version is not current — a "latest" page can silently describe a newer major
   version than what's in the lockfile.

3. **Verify the SPECIFIC endpoints/methods/parameters you are about to use — not general
   familiarity with the library.** "I've used this SDK before" is not verification. Confirm,
   against the docs you just located: the exact method name, its required and optional
   parameters, the request/response shape, and any required headers or auth scheme. Do this
   per call site, not once for the whole library — different methods in the same SDK can be
   added, deprecated, or changed independently of each other.

4. **If no docs are reachable, STOP and ask the user for a URL or file path.** Never proceed
   on memory alone. It is better to pause and ask than to ship integration code built on a
   guess. Do not scaffold "best effort" code in the meantime — see "How to ask" below for
   exactly what to request and what to avoid doing while waiting.

5. **Note version-sensitive areas that deserve extra scrutiny even when docs are found.**
   These are the places where stale-memory bugs concentrate:
   - Auth flows (API keys vs. OAuth vs. signed requests; token refresh mechanics).
   - Pagination style (offset/limit vs. cursor vs. page tokens — these get swapped between
     major versions more often than most other surface area).
   - Error response formats (status codes, error body shape, retryable vs. terminal errors).
   - Deprecations and removals (a method that still "works" in your memory may now log a
     deprecation warning or have been removed entirely).
   - SDK method renames across major versions (the same operation may have a different method
     name, module path, or calling convention in v10 vs. v14).

## Signals you are coding from stale memory

Treat any of these as a hard stop — go back to step 2 or 4:

- You're guessing at a parameter name because "it's probably called that" rather than reading
  it off a signature or doc example.
- The snippet you're about to write matches a pattern you recall clearly, and that pattern
  predates your knowledge cutoff — recall does not equal currency.
- The lockfile version number is higher than the latest version you have confident knowledge
  of for that library.
- An example response shape you're relying on doesn't match what the docs you just fetched
  actually show (or you haven't fetched anything to compare against).
- You find yourself writing "this should still work" instead of "the docs confirm this works."

## Worked example

Task: "Integrate Stripe subscription creation."

- Step 1: `package-lock.json` shows `"stripe": "14.x"`. Memory strongly associates Stripe
  calls with `stripe.subscriptions.create({...})` using patterns common around v10 — but v14
  has moved through several breaking changes since (e.g., API version pinning via
  `apiVersion`, changes to expand behavior, updated error classes).
- Step 2: WebFetch the official Stripe API reference for subscriptions, or open the vendored
  TypeScript types under `node_modules/stripe` if network access isn't available.
- Step 3: Confirm the exact `subscriptions.create` parameter names and required fields for
  v14, not the v10 shape recalled from memory — field names, expansion syntax, and default
  behaviors are all candidates for drift.
- Step 4: Only after that confirmation, write the integration code.
- Result: version mismatch caught before writing a single line, instead of after a runtime
  error surfaces the drift.

## How to ask the user for docs

When no docs are reachable, ask for one of:

- A docs URL (the specific page for the version in use, if known).
- A local file path (README, CHANGELOG, OpenAPI/Swagger/GraphQL schema file already in the
  repo or provided by the user).
- An OpenAPI/GraphQL spec file, if the API is internal or undocumented publicly.

State plainly which library/API and version you need docs for, and why (e.g., "the lockfile
pins `stripe@14.x`; I don't have verified current docs for that major version's subscription
API and don't want to guess at parameter names").

While waiting: write nothing that calls the external API or SDK. Do not scaffold function
signatures "to be filled in later" based on guessed parameters — a plausible-looking stub
invites someone to trust it before it's verified. It's fine to prepare everything that does
not depend on the unverified surface (e.g., the calling code's control flow, tests for your
own logic), but the actual call shape waits for docs.
