export type Status = 'pending' | 'in_progress' | 'done' | 'parked' | 'blocked'

export type Card = { id: string; title: string; dependsOn: string[]; group: string; status: Status; milestone?: string }

export type IndexModel = {
  slug: string
  specPath: string | null
  marker: 'GOAL' | 'GOAL lean' | 'ULTRA' | null
  cards: Card[]
  milestones: { id: string; title: string }[]
}

const CARD_ROW = /^\s*\|\s*\d\d\s*\|/

const CARD_HEADER = /^\s*\|\s*card\s*\|/i

const MILESTONE = /^###\s+Milestone\s+(\S+)\s+—\s+(.+?)\s*$/

const SPEC = /taskmaster-docs\/specs\/[^\s/]+?\.md/

// `skipped` is closed in hooks/announce.sh, and parked is the only closed status that is not done.
const STATUSES: [RegExp, Status][] = [
  [/^done/, 'done'],
  [/^(parked|skipped)/, 'parked'],
  [/^in[ _-]?progress/, 'in_progress'],
  [/^blocked/, 'blocked'],
]

const cellsOf = (row: string) => row.split('|').map((c) => c.trim())

// The cell hooks/announce.sh and hooks/suggest.ts count, not the header's: the last, or the one before a trailing pipe.
function statusOf(cells: string[]): Status {
  const s = (cells.at(-1) || cells.at(-2) || '').toLowerCase()
  return STATUSES.find(([re]) => re.test(s))?.[1] ?? 'pending'
}

export function parseIndex(md: string, slug: string): IndexModel | { error: string } {
  const lines = md.split('\n').filter((l) => !l.startsWith('>'))
  const header = lines.find((l) => CARD_HEADER.test(l))
  if (header === undefined) return { error: 'no card table' }

  const cols = cellsOf(header.toLowerCase())
  const cell = (cells: string[], name: string) => {
    const i = cols.indexOf(name)
    return i === -1 ? '' : (cells[i] ?? '')
  }

  const milestones: { id: string; title: string }[] = []
  const milestoneOf = new Map<string, string>()
  let current: string | null = null
  for (const line of lines) {
    if (line.startsWith('#')) {
      const [, id = '', title = ''] = MILESTONE.exec(line) ?? []
      current = id === '' ? null : id
      if (current !== null) milestones.push({ id, title })
    } else if (current !== null && line.startsWith('Cards:')) {
      for (const id of line.slice('Cards:'.length).split(/[\s,]+/)) if (id) milestoneOf.set(id, current)
    }
  }

  // Every card-shaped row, as hooks/announce.sh and hooks/suggest.ts count them; the header only places the columns.
  const cards = lines
    .filter((l) => CARD_ROW.test(l))
    .map((row): Card => {
      const cells = cellsOf(row)
      const id = cells[1] ?? ''
      return {
        id,
        title: cell(cells, 'title'),
        dependsOn: cell(cells, 'depends-on').match(/\b\d\d\b/g) ?? [],
        group: cell(cells, 'parallel group'),
        status: statusOf(cells),
        milestone: milestoneOf.get(id),
      }
    })
  if (cards.length === 0) return { error: 'no card table' }

  const has = (prefix: string) => lines.some((l) => l.startsWith(prefix))
  const marker = has('Goal: true (boost=off)') ? 'GOAL lean' : has('Goal: true') ? 'GOAL' : has('Ultra: true') ? 'ULTRA' : null

  return { slug, specPath: SPEC.exec(lines.join('\n'))?.[0] ?? null, marker, cards, milestones }
}

export function counts(m: IndexModel): { total: number; done: number; parked: number; inProgress: boolean } {
  const count = (s: Status) => m.cards.filter((c) => c.status === s).length
  return {
    total: m.cards.length,
    done: count('done'),
    parked: count('parked'),
    inProgress: m.cards.some((c) => c.status === 'in_progress'),
  }
}

export function statusLine(m: IndexModel, phase: string): string {
  const c = counts(m)
  return [
    'task-runner',
    phase,
    `card ${c.done + (c.inProgress ? 1 : 0)}/${c.total}`,
    c.parked > 0 ? `${c.parked} parked` : '',
    m.marker === null ? '' : m.marker === 'ULTRA' ? 'ultra' : 'goal',
  ]
    .filter((part) => part !== '')
    .join('  ')
}
