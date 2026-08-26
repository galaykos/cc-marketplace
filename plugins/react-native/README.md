# react-native

React Native best practices: FlatList/FlashList virtualization, typed and shallow
React Navigation, platform-specific code via `Platform.select` and file splits,
native-driver animations, image sizing and caching, minimizing JS-to-native
crossings, and `StyleSheet.create`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install react-native@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/react-native:review [files-or-diff]` | Review screens, lists, and native-bridge code against the skill, pinned to the installed React Native version from the lockfile |

## Example

```bash
/react-native:review src/screens/OrderList.tsx
/react-native:review         # reviews the current diff
```

Advice pins to the installed React Native version, so guidance matches the APIs
your release actually ships.

## Expo / EAS

`skills/react-native-best-practices/references/expo.md` carries the Expo facts
whose standard remediation has **inverted**, and only those — it is deliberately
not a second best-practices body:

- From SDK 55 the New Architecture is always on, so `newArchEnabled: false` is a
  silently accepted no-op rather than the fix it was in 2024/2025.
- `expo install` resolves against the SDK's compatibility matrix; `npm install`
  does not, and the failure surfaces later as a native crash.
- Under CNG, `expo prebuild --clean` overwrites hand edits to `ios/`/`android/` —
  native changes belong in a config plugin.
- An EAS Update published against a mismatched `runtimeVersion` is never
  delivered, with no error anywhere.

`/react-native:review` reads it automatically when `expo` is in the manifest,
`skill-router` routes this skill on `app.config.*` and `eas.json` edits in an Expo
project, and the skill body points at it before advising an Expo app.
