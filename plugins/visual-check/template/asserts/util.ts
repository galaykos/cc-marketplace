// Shared helpers for the four "not broken" assert categories (card 07).

// Matches ANSI SGR color/style escapes (ESC[…m) Playwright injects into messages.
// eslint-disable-next-line no-control-regex
const ANSI = /\x1b\[[0-9;]*m/g;

/** First non-empty, trimmed, ANSI-stripped line of a message — keeps `reasons[]` terse. */
export function firstLine(s: unknown): string {
  const msg =
    s && typeof s === 'object' && 'message' in s
      ? String((s as { message?: unknown }).message ?? '')
      : String(s ?? '');
  return msg.replace(ANSI, '').split('\n').map((l) => l.trim()).filter(Boolean)[0] || 'unknown error';
}
