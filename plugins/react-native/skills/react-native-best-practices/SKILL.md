---
name: react-native-best-practices
description: Use when writing or reviewing React Native code — FlatList/FlashList performance, navigation patterns, platform-specific code, native driver animations, image handling.
---

## List virtualization: keyExtractor, getItemLayout, stable renderItem

`FlatList` only renders what's near the viewport, but needs stable identity and layout info to do
it well. A missing `keyExtractor` falls back to index-based keys, breaking item identity across
inserts/removals. `getItemLayout` lets it skip an async measurement pass and jump straight to any
offset — but it's only valid when every row is a fixed, known height; using it with variable
heights produces wrong scroll positions and overlapping items. An inline arrow `renderItem` is
re-created every render, defeating `React.memo` on the row component.

```jsx
// Bad: index key, inline renderItem, no layout hint
<FlatList data={items} renderItem={({ item }) => <Row item={item} />} />
// Good: stable key, fixed-height layout hint, stable renderItem reference
const ITEM_HEIGHT = 72;
const renderItem = useCallback(({ item }) => <Row item={item} />, []);
<FlatList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={renderItem}
  getItemLayout={(_, i) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * i, index: i })}
/>
```

For long or frequently-updated lists (chat/feed screens), use `@shopify/flash-list`, a near
drop-in replacement that recycles views instead of mounting/unmounting them.

## React Navigation: typed params, shallow nesting

Type each navigator's param list and pass it through `NativeStackScreenProps` (or the equivalent)
so `route.params` and `navigate(...)` calls are checked at compile time — untyped params let a
renamed/removed param silently become `undefined` at runtime instead of a build error.

```tsx
// Bad: untyped params, typo not caught until runtime
navigation.navigate('Profile', { userid: user.id });
// Good: typed param list catches the typo at compile time
type RootStackParamList = { Profile: { userId: string } };
type Props = NativeStackScreenProps<RootStackParamList, 'Profile'>;
navigation.navigate('Profile', { userId: user.id });
```

Avoid deep navigator nesting (stack-in-tab-in-drawer-in-stack) — each layer complicates `goBack()`
and needs its own deep-link segment. Prefer top-level navigators switched by app state, nested one
or two levels at most.

## Platform-specific code: Platform.select and file splits

Use `Platform.OS === 'ios'` for small one-off branches. Use `Platform.select` when several values
differ together. Use `.ios.tsx`/`.android.tsx` file splits once a component's implementation
diverges enough that branching in one file hurts readability.

```jsx
// Bad: scattered inline branches for a whole style object
const shadow = Platform.OS === 'ios'
  ? { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.2, shadowRadius: 4 }
  : { elevation: 4 };
// Good: one declarative call, same shape either way
const shadow = Platform.select({
  ios: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.2, shadowRadius: 4 },
  android: { elevation: 4 },
});
```

Don't let `.ios.tsx`/`.android.tsx` pairs drift in exported API — Metro picks one per platform at
build time, so a shape mismatch is a runtime error on only one platform, not a type error.

## Animated/Reanimated: useNativeDriver's limited scope

`useNativeDriver: true` runs an animation on the native UI thread instead of JS, so it stays smooth
even when JS is busy — true on the New Architecture too (the only option since RN 0.82: JSI replaces the
async bridge, but JS-thread congestion still janks). It only supports non-layout properties:
`transform` (translate/scale/rotate) and `opacity`, not `width`, `height`, `top`, `left`, `flex`,
or margin/padding, since those require re-running layout. Requesting it for a layout property
throws at runtime (e.g. "Style property 'width' is not supported") instead of animating.

```jsx
// Bad: width is a layout property — not eligible for the native driver
Animated.timing(widthAnim, { toValue: 200, useNativeDriver: true }).start();
// Good: get a "resize" effect via transform/scale instead
Animated.timing(scaleAnim, { toValue: 1.2, useNativeDriver: true }).start();
```

For gesture-driven animation, prefer `react-native-reanimated`, which runs the whole animation on
the UI thread via worklets.

## Image sizing and caching

Give images explicit `width`/`height` (or an aspect-ratio-constrained container) rather than
sizing to content — an unsized remote image collapses to 0x0 until the response arrives, shifting
layout. Set `resizeMode` deliberately instead of relying on the default.

```jsx
// Bad: no dimensions — layout jumps once the image loads
<Image source={{ uri: avatarUrl }} />
// Good: reserved space, explicit fit behavior
<Image source={{ uri: avatarUrl }} style={{ width: 48, height: 48 }} resizeMode="cover" />
```

React Native's built-in `Image` has limited disk-cache control. For screens with many remote
images, use `expo-image` so images cache to disk instead of refetching; `react-native-fast-image`
offers the same idea but is no longer actively maintained, so prefer `expo-image` for new code.

## Minimize JS-to-native crossings

Every JS-to-native call has overhead. Batch state updates instead of issuing one per frame, and let
native handle continuous, high-frequency values (scroll position, gesture deltas) instead of
routing them through JS state. "Bridge" here means the Old Architecture/interop layer; on the New
Architecture (default since 0.76, the only option since 0.82) it's the synchronous JSI, not the
async bridge — but per-frame JS work still congests the JS thread and still janks either way.

```jsx
// Bad: a JS state update — and a JS/native crossing — on every scroll frame
<ScrollView onScroll={(e) => setScrollY(e.nativeEvent.contentOffset.y)} scrollEventThrottle={1} />
// Good: drive UI from a shared value updated on the native side
const scrollY = useSharedValue(0);
const handler = useAnimatedScrollHandler((e) => { scrollY.value = e.contentOffset.y; });
<Animated.ScrollView onScroll={handler} scrollEventThrottle={16} />
```

## StyleSheet.create over inline style objects

Prefer `StyleSheet.create` for static styles: it's defined once at module scope instead of
allocating a new object literal every render, and it validates style keys in development.

```jsx
// Bad: new object every render
<View style={{ flex: 1, padding: 16 }} />
// Good: created once, referenced by id
const styles = StyleSheet.create({ container: { flex: 1, padding: 16 } });
<View style={styles.container} />
```

## Common mistakes

- Missing `keyExtractor` on `FlatList`, or using `getItemLayout` with variable-height rows.
- Passing an inline arrow function as `renderItem`, defeating row memoization.
- Deeply nested navigators that break deep linking and `goBack()` predictability.
- Untyped navigation params, turning renamed/removed params into runtime `undefined`.
- Requesting `useNativeDriver: true` for layout properties (width, height, margin, flex).
- Rendering unsized remote images, causing layout shift while they load.
- Driving per-frame JS state updates (e.g. raw scroll position) instead of native/shared values.
- Inline style objects recreated every render instead of `StyleSheet.create`.
- Letting `.ios.tsx`/`.android.tsx` file pairs drift in exported prop shape.

## Verify Against Current Docs

React Native's list components, the new architecture (Fabric/JSI), and Reanimated APIs change
across versions faster than most native platform APIs. Before relying on memory for
version-sensitive behavior, check the current docs: https://reactnative.dev
