export const LIMITS = { deadlineMs: 5000, cap: 10, backoffFailures: 3, backoffMs: 600000, promptChars: 4000, totalChars: 8000 } as const

export type Gate = { escalations: number; failures: number; backoffUntil: number | null }

/** FNV-1a 32-bit over the text's UTF-8 bytes, as 8 lowercase hex digits. */
export function textHash(text: string): string {
  let h = 0x811c9dc5
  for (const byte of new TextEncoder().encode(text)) h = Math.imul(h ^ byte, 0x01000193)
  return (h >>> 0).toString(16).padStart(8, '0')
}

export function isEligible(p: { text: string; origin: string; attachments: number; passed: readonly string[]; muted: boolean }): boolean {
  if (p.muted || p.origin !== 'composer' || p.attachments !== 0 || /^\s*[/!#]/.test(p.text)) return false
  return isLongEnough(p.text) && (p.passed.length === 0 || !p.passed.includes(textHash(p.text)))
}

// Stops at the 4th token or the 16th non-space character: the check runs while Enter is held, on prompts of any size.
function isLongEnough(text: string): boolean {
  let tokens = 0
  let chars = 0
  let inToken = false
  for (const ch of text) {
    if (/\s/.test(ch)) {
      inToken = false
      continue
    }
    chars += 1
    if (!inToken) tokens += 1
    inToken = true
    if (tokens >= 4 || chars >= 16) return true
  }
  return false
}

export function canEscalate(g: Gate): boolean {
  return g.escalations < LIMITS.cap
}

export function isBackingOff(g: Gate, now: number): boolean {
  return g.backoffUntil !== null && now < g.backoffUntil
}

export function afterJudge(g: Gate, outcome: 'ok' | 'failed', escalated: boolean, now: number): Gate {
  const escalations = g.escalations + (escalated ? 1 : 0)
  if (outcome === 'ok') return { escalations, failures: 0, backoffUntil: g.backoffUntil }
  const failures = g.failures + 1
  if (failures < LIMITS.backoffFailures) return { escalations, failures, backoffUntil: g.backoffUntil }
  return { escalations, failures: 0, backoffUntil: now + LIMITS.backoffMs }
}
