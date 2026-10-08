export type Segment = 'context' | 'limits' | 'cost' | 'time' | 'git'

export const DEFAULT_SEGMENTS: readonly Segment[] = ['context', 'limits', 'cost', 'time', 'git']

export type Limit = { kind: string; percentUsed: number; resetsAt?: string }

export type Figures = {
  now: number
  startedAt?: number
  contextPercent?: number
  contextTokens?: number
  window?: number
  limits: readonly Limit[]
  costUsd?: number
  branch?: string
  isDirty?: boolean
}

export type Category = { name: string; tokens: number }

export type Breakdown = { categories: readonly Category[]; maxTokens: number; compactAt?: number }

export type TurnFigures = { outputTokens?: number; costUsd?: number; contextDelta?: number }

const KNOWN = new Set<string>(DEFAULT_SEGMENTS)

const LIMIT_LABELS: Record<string, string> = { five_hour: '5h', seven_day: '7d', spend_limit: 'spend' }

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

export function parseSegments(text: string | undefined): Segment[] {
  if (text === undefined || text.trim() === '') {
    return [...DEFAULT_SEGMENTS]
  }

  const picked = text
    .split(',')
    .map(part => part.trim().toLowerCase())
    .filter((part): part is Segment => KNOWN.has(part))

  return [...new Set(picked)]
}

export function tokens(count: number): string {
  if (count >= 1_000_000) {
    return `${(count / 1_000_000).toFixed(1)}M`
  }

  if (count >= 10_000) {
    return `${Math.round(count / 1000)}k`
  }

  return count >= 1000 ? `${(count / 1000).toFixed(1)}k` : String(Math.round(count))
}

export function money(usd: number): string {
  return `$${usd.toFixed(2)}`
}

export function span(ms: number): string {
  const total = Math.max(0, ms)

  if (total >= DAY) {
    return `${Math.floor(total / DAY)}d${Math.floor((total % DAY) / HOUR)}h`
  }

  if (total >= HOUR) {
    return `${Math.floor(total / HOUR)}h${String(Math.floor((total % HOUR) / MINUTE)).padStart(2, '0')}m`
  }

  return total >= MINUTE ? `${Math.floor(total / MINUTE)}m` : '<1m'
}

export function limitLabel(kind: string): string {
  return LIMIT_LABELS[kind] ?? kind
}

function resetIn(limit: Limit, now: number): string {
  const at = limit.resetsAt === undefined ? NaN : Date.parse(limit.resetsAt)

  return Number.isNaN(at) || at <= now ? '' : ` ↻${span(at - now)}`
}

function limitText(limit: Limit, now: number): string {
  return `${limitLabel(limit.kind)} ${Math.round(limit.percentUsed)}%${resetIn(limit, now)}`
}

function segmentText(segment: Segment, f: Figures): string[] {
  switch (segment) {
    case 'context':
      return f.contextPercent === undefined ? [] : [`ctx ${Math.round(f.contextPercent)}%`]
    case 'limits':
      return f.limits.map(limit => limitText(limit, f.now))
    case 'cost':
      return f.costUsd === undefined ? [] : [money(f.costUsd)]
    case 'time':
      return f.startedAt === undefined ? [] : [span(f.now - f.startedAt)]
    case 'git':
      return f.branch === undefined || f.branch === '' ? [] : [`${f.branch}${f.isDirty ? '*' : ''}`]
  }
}

export function hudLine(segments: readonly Segment[], f: Figures): string {
  return segments.flatMap(segment => segmentText(segment, f)).join(' · ')
}

export function turnLine(t: TurnFigures): string {
  const parts = [
    t.outputTokens === undefined || t.outputTokens <= 0 ? '' : `${tokens(t.outputTokens)} out`,
    t.costUsd === undefined || t.costUsd < 0.005 ? '' : money(t.costUsd),
    t.contextDelta === undefined || t.contextDelta === 0 ? '' : `ctx ${t.contextDelta > 0 ? '+' : ''}${t.contextDelta}%`,
  ]

  return parts.filter(part => part !== '').join(' · ')
}

export function appendTail(tail: string | undefined, text: string): string {
  return tail === undefined || tail === '' ? text : `${tail} · ${text}`
}

export function bar(percent: number, width: number): string {
  const cells = Math.max(1, width)
  const filled = Math.min(cells, Math.max(0, Math.round((percent / 100) * cells)))

  return `${'█'.repeat(filled)}${'░'.repeat(cells - filled)}`
}

export type PaneRow = { text: string; isHeading?: boolean }

function clamp(value: number, low: number, high: number): number {
  return Math.max(low, Math.min(high, value))
}

// Sized for the docked pane's body, 23 columns on a 200-column terminal (measured on 2.1.294).
export function paneRows(f: Figures, breakdown: Breakdown | null, columns: number): PaneRow[] {
  const rows: PaneRow[] = [{ text: 'Context', isHeading: true }]

  if (f.contextPercent === undefined) {
    rows.push({ text: 'no reading yet — it arrives with the first answer' })
  } else {
    const used = f.contextTokens === undefined || f.window === undefined ? '' : `  ${tokens(f.contextTokens)}/${tokens(f.window)}`

    rows.push({ text: `${bar(f.contextPercent, clamp(columns - 14, 4, 30))} ${Math.round(f.contextPercent)}%${used}` })
  }

  if (breakdown !== null) {
    if (breakdown.compactAt !== undefined && breakdown.maxTokens > 0) {
      rows.push({ text: `compacts at ${tokens(breakdown.compactAt)} (${Math.round((breakdown.compactAt / breakdown.maxTokens) * 100)}%)` })
    }

    const nameWidth = clamp(columns - 10, 8, 24)

    for (const category of breakdown.categories.filter(c => c.tokens > 0).slice(0, 8)) {
      rows.push({ text: `  ${category.name.slice(0, nameWidth).padEnd(nameWidth)} ${tokens(category.tokens).padStart(6)}` })
    }
  }

  rows.push({ text: 'Rate limits', isHeading: true })

  if (f.limits.length === 0) {
    rows.push({ text: 'no reading yet' })
  }

  for (const limit of f.limits) {
    rows.push({ text: `${limitLabel(limit.kind)} ${bar(limit.percentUsed, clamp(columns - 18, 4, 30))} ${Math.round(limit.percentUsed)}%${resetIn(limit, f.now)}` })
  }

  rows.push({ text: 'Session', isHeading: true })
  rows.push({
    text: [
      f.costUsd === undefined ? '' : money(f.costUsd),
      f.startedAt === undefined ? '' : span(f.now - f.startedAt),
      f.branch === undefined || f.branch === '' ? '' : `${f.branch}${f.isDirty ? '*' : ''}`,
    ]
      .filter(part => part !== '')
      .join('  '),
  })

  return rows
}
