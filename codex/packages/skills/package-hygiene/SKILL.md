---
name: package-hygiene
description: Use when editing composer.json or package.json, adding/updating/removing a dependency, bumping versions, resolving lockfile merge conflicts, or acting on audit/vulnerability output — semver constraint strategy, lockfile discipline, composer/npm audit triage, and patch/minor/major upgrade lanes. Whether to add a dependency at all is build-vs-buy; what is installed is stack-scan; reading docs before integration code is api-docs-first.
---

# Package Hygiene (composer + npm)

Dependencies already in the project need maintenance: constraints that mean
what you intend, a lockfile treated as law, audit output triaged instead of
ignored, and upgrades routed into lanes sized to their risk.

## Version-constraint strategy

Semver in one line: `MAJOR.MINOR.PATCH` — major breaks, minor adds, patch
fixes. A constraint declares how much drift you accept between resolutions;
the lockfile decides what is actually installed.

- Default for applications: caret (`^1.2.3`) backed by a committed lockfile.
  The lockfile pins exact versions; the caret only defines the window that
  `update` may move within. Tight pins without a reason just delay patches.
- Exact-pin (`1.2.3`) only with a stated reason in the commit or a manifest
  comment: a known-bad upstream range you must steer around, a
  security-critical package where every bump gets reviewed, or
  reproducibility-critical tooling (formatters, code generators) where a
  patch release changes output.
- Cross-ecosystem tilde trap: composer `~1.2.3` allows patch-only
  (>=1.2.3 <1.3.0), and npm `~1.2.3` behaves the same — but composer `~1.2`
  allows minor updates (>=1.2 <2.0.0), while npm `~1.2` stays within 1.2.x.
  Two-segment tilde means different things in the two files; prefer caret
  and be explicit.
- Pre-1.0 caret is narrower: `^0.3.1` permits only 0.3.x in both
  ecosystems, because 0.x minors are treated as breaking. Expect churn from
  0.x dependencies and review their bumps like majors.

## Lockfile discipline

The manifest states intent; the lockfile states fact. The lockfile is what
you ship.

- Commit it, always (`composer.lock`, `package-lock.json`). Never hand-edit
  it — resolved graphs and integrity hashes are generated artifacts; edit
  the manifest and regenerate.
- CI installs from the lockfile and never resolves fresh: `npm ci` and
  `composer install`. Running `npm install` or `composer update` in CI means
  CI tests a different dependency graph than the one you deploy.
- Merge conflicts in a lockfile are never hand-merged. Resolve the manifest
  conflict normally, check out one side of the lockfile, and regenerate:

      git checkout --theirs package-lock.json && npm install
      git checkout --theirs composer.lock && composer update --lock

  If the branches changed different packages, follow with a scoped
  `composer update vendor/pkg` for the packages your side touched.
- One package manager per repo. Detect it from the lockfile present —
  `package-lock.json` = npm, `yarn.lock` = yarn, `pnpm-lock.yaml` = pnpm —
  and use that one. Two lockfiles in a repo are two competing truths; delete
  the stale one deliberately, never let both drift.

## Audit workflow

Run `composer audit` and `npm audit` (in CI, gate with
`npm audit --audit-level=high` rather than failing on every advisory).
Triage each finding on three axes before touching anything:

- **Severity** — the advisory's rating, as a starting point, not a verdict.
- **Reachability** — is the vulnerable code path exercised by your usage? A
  ReDoS in a dev-only build tool is not a production incident.
- **Direct vs transitive** — direct deps you bump yourself; transitive ones
  need the parent to move, or an explicit override until it does.

Three fix lanes, in order of preference:

1. **Bump within constraint** — `composer update vendor/package` /
   `npm update package`. Cheapest; the constraint already allows the fix.
2. **Documented override/exception** — npm `overrides` in package.json;
   composer: pin the transitive package as a direct requirement or block the
   bad range via `conflict`. Every override carries a comment with the
   advisory ID and its removal condition — an override without an expiry is
   a permanent fork of reality.
3. **Replace the package** — when upstream is abandoned and no fix is
   coming. That decision is a task, not a hotfix.

Never blanket `npm audit fix --force`: it applies semver-major bumps across
the tree — an unreviewed upgrade-everything PR wearing a security hat.

## Upgrade strategy

Survey first: `composer outdated --direct` / `npm outdated`. Route each
package into a lane:

- **Patch** — apply, run the suite, merge. No changelog reading required.
- **Minor** — read the changelog first (new deprecations, changed
  defaults), then apply and run the suite.
- **Major** — its own task with the package's migration/UPGRADE notes in
  hand. One major per PR; budget for code changes, not just a version bump.

Regular small cadence beats big-bang: a weekly patch/minor pass keeps every
diff bisectable. A 40-package bump that breaks something tells you nothing
about which package broke it.

## Anti-patterns

- **Hand-edited lockfile** — integrity hashes and resolved graphs are
  generated; editing them by hand produces a file no tool ever verified.
- **`npm install` in CI** — resolves fresh instead of reproducing the
  lockfile; CI silently tests a graph nobody committed. Use `npm ci`.
- **Mixed package managers** — npm one day, yarn the next; each rewrites
  its own lockfile and the two truths drift apart.
- **Wildcard `*` constraints** — "any future breaking change is fine",
  which nobody actually means.
- **`npm audit fix --force`** — unreviewed major upgrades across the whole
  tree, justified by a severity badge.
- **Upgrade-everything-at-once PRs** — one giant bump, zero bisectability;
  when it breaks, every package is a suspect.
- **Undocumented overrides** — a pinned transitive dep with no advisory ID
  or removal condition outlives the vulnerability it patched.

## Verify Against Current Docs

Audit output formats, CLI flags (`--omit=dev` vs the older `--production`),
and override syntax shift across package-manager major versions. Before
relying on memory for version-sensitive flags or audit JSON shapes, check
what is actually installed —

    npm -v
    composer --version

— then verify against the current docs for that version:
https://docs.npmjs.com and https://getcomposer.org/doc/
