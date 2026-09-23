> Last verified: 2026-08-02 — https://vite.dev/releases — npm:vite@8
> Last verified: 2026-08-12 — https://reactnative.dev/blog — npm:react-native@0.82
> Last verified: 2026-09-01 — https://example.dev — npm:@scope/vite@3.1

A package coordinate is not a marketplace reference. `$bm` excludes `/@.-` but not
`:`, so every line above matched `(^|$bm)($moved)@` until 2026-09-22 and failed the
two shipped skills whose whole job is naming those packages.
