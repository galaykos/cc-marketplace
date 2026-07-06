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

## Pairs well with

- **react** — the shared hooks and render rules underneath React Native
- **typescript** — the type layer this component review skips
