# Expo / EAS: the advice that INVERTED

> Last verified: 2026-08-02 — https://docs.expo.dev/ — npm:expo@54

This file is deliberately short. It carries only the Expo facts where a competent
answer given from general knowledge is now WRONG — not an idiom list, which is the
shape `rationale/stack-skill-baselines.md` measured at zero delta twice. Read the
installed `expo` version from `package.json` and the lockfile before applying any
of it; every item below is version-conditional by nature.

## `newArchEnabled: false` stopped being a remedy

From SDK 55 the New Architecture is **always enabled and cannot be disabled**. The
standard 2024/2025 answer to "this native library breaks under the New
Architecture" — set `newArchEnabled: false` in `app.json` and rebuild — is now a
no-op. The config key is accepted and does nothing, which is worse than an error:
the build succeeds, the symptom persists, and the obvious next step is to blame
something else.

The real remedies, in order:

1. Check whether the library ships a New Architecture-compatible release. Most
   maintained ones now do; the pinned version in the lockfile is often just old.
2. Check for an interop layer — many old-architecture modules work through the
   compatibility shim without changes.
3. Replace the library. If it is unmaintained and incompatible, that is the
   finding; say so rather than proposing a flag that no longer exists.

Check the installed SDK before advising either way: below 55 the flag still works
and the old advice is still correct.

## `npm install` is the wrong installer in a managed project

`expo install <pkg>` resolves against the SDK's compatibility matrix; `npm install
<pkg>` resolves against latest. In a managed project the second one installs a
version outside the SDK's tested set and the failure surfaces at build time, or
later, as a native crash with no obvious link to the install.

- `npx expo install --check` reports every dependency that is off-matrix.
- `npx expo install --fix` corrects them.
- Run `--check` before diagnosing any build failure in an Expo project; a
  mismatched dependency explains a surprising share of them and costs one command
  to rule out.

## CNG: an `ios/` or `android/` directory changes the rules

With Continuous Native Generation, native directories are BUILD OUTPUT. If they
exist and were generated, `npx expo prebuild --clean` regenerates them and
**overwrites hand edits** — every manual `Info.plist` key, every Gradle tweak,
gone, with no warning that anything was lost.

Native changes therefore go through a **config plugin**, not through the native
files. Before editing anything under `ios/` or `android/`, establish which regime
the project is in:

| Signal | Regime |
|---|---|
| No `ios/`/`android/` in the repo, `expo prebuild` in CI | CNG — edit via config plugins only |
| `ios/`/`android/` committed AND `.gitignore` lists them | CNG, generated locally — same rule |
| `ios/`/`android/` committed and NOT ignored, no prebuild in CI | bare — native files are source, edit them directly |

Getting this wrong in either direction is expensive: hand-editing under CNG loses
the work at the next prebuild, and adding a config plugin to a bare project adds a
layer that never runs.

## EAS Update failures are silent by design

An update published against a `runtimeVersion` that no installed build matches is
simply **never delivered**. No error, no log line, no failed request — the client
asks for updates matching its runtime version and there are none. This is the
entire content of the "my OTA update isn't showing up" loop.

- The publishing channel and the build's channel must match.
- The `runtimeVersion` policy (`sdkVersion`, `appVersion`, `fingerprint`) decides
  compatibility; a native change under `fingerprint` produces a NEW runtime version,
  so old builds correctly stop receiving updates.
- Diagnose with `eas update:list` and compare its runtime version against the
  installed build's, before touching anything else.

## `app.json` vs `app.config.js` precedence

If both exist, `app.config.js`/`app.config.ts` wins and receives the static config
as `({ config })` to spread. A project with both, where someone edited `app.json`
and saw no effect, is a common and confusing state — `npx expo config --type public`
prints what is actually in force, and is the only thing worth trusting.
