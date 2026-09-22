# Expo / EAS: the advice that INVERTED

> Last verified: 2026-09-22 — https://docs.expo.dev/ — npm:expo@57

This file is deliberately short. It carries only the Expo facts where a competent
answer given from general knowledge is now WRONG — not an idiom list, which is the
shape `rationale/measured-zero-shapes.md` §1 records at zero delta twice (typescript
and javascript, both 0), and which names this file as the shape's narrow survivor. Read the
installed `expo` version from `package.json` and the lockfile before applying any
of it; every item below is version-conditional by nature.

## `newArchEnabled: false` stopped being a remedy

The New Architecture is the default from **SDK 53**, and from **SDK 55** it cannot be
turned off: "SDK 55 and later do not support disabling the New Architecture", and a
`newArchEnabled: false` left in the app config "will be ignored". The standard
2024/2025 answer to "this native library breaks under the New Architecture" — set
`newArchEnabled: false` in `app.json` and rebuild — is now a no-op. The key is gone
from the app config schema yet is ignored rather than rejected, which is worse than
an error: the build succeeds, the symptom persists, and the obvious next step is to
blame something else.

The real remedies, in order:

1. Check whether the library ships a New Architecture-compatible release. Most
   maintained ones now do; the pinned version in the lockfile is often just old.
2. Interop layers have been on by default since RN 0.74 and run many old-architecture
   libraries unchanged — but "the interop is not perfect and some libraries will need
   to be updated", so confirm rather than assume.
3. Replace the library; React Native Directory carries the per-library compatibility
   list. If it is unmaintained and incompatible, that is the finding — say so rather
   than proposing a flag that no longer exists.

To isolate the culprit the docs prescribe removing suspect libraries on a throwaway
branch until the app runs. Check the installed SDK first: **SDK 54 is the last release
with Legacy Architecture support**, so at 54 or below the flag still works and the old
advice is still correct.

## `npm install` is the wrong installer in a managed project

`expo install <pkg>` resolves against the SDK's compatibility matrix; `npm install
<pkg>` resolves against latest. In a managed project the second one installs a
version outside the SDK's tested set and the failure surfaces at build time, or
later, as a native crash with no obvious link to the install.

- `npx expo install --check` — "check which installed packages need to be updated".
- `npx expo install --fix` — "automatically update any invalid package versions".
- Run `--check` before diagnosing any build failure in an Expo project; a
  mismatched dependency explains a surprising share of them and costs one command
  to rule out.

## CNG: from SDK 57 `prebuild` cleans by DEFAULT

With Continuous Native Generation, native directories are BUILD OUTPUT. SDK 57
inverted the muscle memory: `expo prebuild` "now clears and regenerates the native
**android** and **ios** directories by default; pass `--no-clean` to apply changes to
the existing folders instead". `--clean` survives as a compatibility no-op, so typing
it is harmless — the hazard is the opposite habit, a bare `npx expo prebuild` that
used to layer onto existing files and now wipes them. Every manual `Info.plist` key,
every Gradle tweak, gone, with no warning that anything was lost. (The
`workflow/prebuild` and `continuous-native-generation` guides still describe the
pre-57 default; below SDK 57 they are right, at 57+ the changelog is.)

Native changes therefore go through a **config plugin**, not through the native
files. Before editing anything under `ios/` or `android/`, establish which regime
the project is in — new projects gitignore both directories automatically, so an
un-ignored pair is a deliberate signal:

| Signal | Regime |
|---|---|
| No `ios/`/`android/` in the repo, `expo prebuild` in CI | CNG — edit via config plugins only |
| `ios/`/`android/` committed AND `.gitignore` lists them | CNG, generated locally — same rule |
| `ios/`/`android/` committed and NOT ignored, no prebuild in CI | bare — native files are source, edit them directly |

Getting this wrong in either direction is expensive: hand-editing under CNG loses
the work at the next prebuild, and adding a config plugin to a bare project adds a
layer that never runs.

## EAS Update failures are silent by design

Delivery is an exact-match lookup: "the platform of the build and the target platform
of an update must match exactly" and "the runtime version of the build and the target
runtime version of an update must match exactly", with a channel serving whatever its
linked branch holds. An update matching no installed build is therefore never
delivered, and the docs describe no client-side error for that case. This is the
entire content of the "my OTA update isn't showing up" loop.

- The publishing channel and the build's channel must match; channels are fixed at
  build time and point at a branch.
- The `runtimeVersion` policy — the app config accepts `nativeVersion`, `sdkVersion`,
  `appVersion`, `fingerprint` — decides compatibility. `fingerprint` is computed from
  the native project, so an SDK upgrade or added native code produces a NEW runtime
  version and old builds correctly stop receiving updates.
- Diagnose with `eas update:list`, `eas branch:view` and `eas channel:view`, comparing
  the runtime version there against the installed build's, before touching anything else.

## `app.json` vs `app.config.js` precedence

Static config is read from `app.config.json`, falling back to `app.json`; dynamic
config from `app.config.ts` or `app.config.js`, TypeScript winning if both exist.
Where both kinds exist the dynamic one wins and, when it exports a function, receives
the static config as `({ config })` to spread. A project with both, where someone
edited `app.json` and saw no effect, is a common and confusing state — `npx expo
config --type public` prints what is actually embedded in builds and updates, and is
the only thing worth trusting.

## `expo-router` forked React Navigation in SDK 56

From SDK 56 `expo-router` no longer depends on `react-navigation`, so "most code
imported directly from `@react-navigation/*` packages will no longer work out of the
box alongside `expo-router`". A file mixing the two is an SDK 55 shape, not an import
bug to chase symbol by symbol; the migration is a codemod,
`npx expo-codemod sdk-56-expo-router-react-navigation-replace <src-dir>`. React
Navigation on its own remains supported in Expo projects — only the mixture broke.
