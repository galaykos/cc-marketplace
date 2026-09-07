# 文言 — the classical-Chinese word layer

An alternative **word layer** for the same shape contract. The budgets, the
work-done skeleton, the cut list and the scope guard in `../SKILL.md` are
unchanged — only how a sentence is written changes. Levels: `wenyan-lite`,
`wenyan-full`, `wenyan-ultra`, set the same way as the latin levels.

Why it compresses harder: classical Chinese carries a clause in 4–8 characters
where English needs 40–60, and one character often does the work of a word.
Expect 80–90% character reduction at `wenyan-full` against the same content in
English prose — which is why the line budgets still bind: a 6-line budget in
文言 holds far more content, and that is the point, not licence to write more
lines.

| Level | How to write |
| --- | --- |
| `wenyan-lite` | Semi-classical. Drop filler and hedging, keep grammatical structure, classical register |
| `wenyan-full` | Fully 文言文. Classical sentence patterns, verb before object, subject usually omitted, classical particles (之 / 乃 / 為 / 其) |
| `wenyan-ultra` | Extreme abbreviation, classical feel retained. One clause where a sentence would do |

## Never translated

Identifiers stay in their original script, always. Code symbols, function names,
API names, file paths, error strings, CLI flags, package names, numbers and
versions are copied verbatim into the 文言 sentence — a translated symbol is a
wrong symbol, and this is the one rule that outranks register consistency.

## Examples

"Why does this React component re-render?"

- `wenyan-lite` — 組件頻重繪，以每繪新生對象參照故。以 `useMemo` 包之。
- `wenyan-full` — 物出新參照，致重繪。`useMemo` 包之。
- `wenyan-ultra` — 新參照→重繪。`useMemo` 包。

"Explain database connection pooling."

- `wenyan-full` — 池者，reuse 既開之 connection 也。不每 req 新開，故省 handshake。
- `wenyan-ultra` — 池 reuse conn。省 handshake → 快。

A work-done report keeps the skeleton, verdict line first:

```
Done. spec/ 七十文件 — 70 files, 16,800 lines.
| 路徑 | 行 |   (table, free)
所見：
- `Status.php:170` 僅驗 apRate → 四規之閘不行，存 pending 而無 reason
Skipped: none.
```

The verdict opens in latin and the counts are repeated as digits — see the
fallback rule below, which this example would otherwise be the first to break.

## Falls back to the latin layer

Any content the classical register cannot carry precisely — a security warning,
a destructive-action confirmation, a step the user must type — is written in the
latin layer at the same level's budget. Ambiguity is a defect; register is a
preference.

**Verdicts and gate acknowledgements are always latin**, at every wenyan level.
Not for readability: hooks in this marketplace grep the assistant's own words in
English. `scripts/done-gate.sh` blocks a turn unless a failing gate is acknowledged
with words like `fail`, `failing`, `blocked` — an honest 敗 never matches, so the
honest turn is the one that gets blocked. `code-architecture/hooks/evidence-gate.sh`
fires on claims like `done`, `fixed`, `verified` — a 成 never matches, so the gate
silently disarms itself for the whole session. Write the verdict line, the
completion claim, and any acknowledgement of a red check in English; the rest of
the message stays 文言.
