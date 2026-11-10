export const STATUSES = ['pending', 'in_progress', 'done', 'parked', 'blocked', 'skipped'] as const

export const REASONS = ['evidence', 'misspec', 'needs-user', 'split', 'guard'] as const

export type Change = { card: string; status: string; reason?: string; detail?: string; children?: readonly string[] }

export type Outcome = { index: string; from: string; to: string } | { error: string }

type Row = { line: number; id: string; status: string }

const SEPARATOR = /^\|[ \t:|-]+\|[ \t]*$/

const trimmed = (cell: string) => cell.replace(/^[ \t`*]+|[ \t`*]+$/g, '')

const keyOf = (id: string) => id.replace(/^0+(?=\d)/, '')

const firstWord = (status: string) => (/^[a-z_]+/.exec(status.toLowerCase()) ?? [''])[0]

// One line, and no pipe: either would break the row the status sits in.
const isCellText = (text: string) => !/[|\n\r]/.test(text)

// The first table whose header names a card (or #) column and a status column, as scripts/park-check.sh finds it.
function tableOf(lines: readonly string[]): { status: number; rows: Row[] } | null {
  let columns: { card: number; status: number } | null = null
  const rows: Row[] = []

  for (const [line, text] of lines.entries()) {
    if (!text.startsWith('|')) {
      if (columns !== null) {
        break
      }

      continue
    }

    const cells = text.split('|')

    if (columns === null) {
      const names = cells.map(cell => trimmed(cell).toLowerCase())
      const card = names.findIndex(name => name === 'card' || name === '#')
      const status = names.indexOf('status')

      columns = card > 0 && status > 0 ? { card, status } : null

      continue
    }

    const id = trimmed(cells[columns.card] ?? '')

    if (!SEPARATOR.test(text) && /^\d+$/.test(id)) {
      rows.push({ line, id, status: trimmed(cells[columns.status] ?? '') })
    }
  }

  return columns === null ? null : { status: columns.status, rows }
}

function cellOf(change: Change, rows: readonly Row[], row: Row): { to: string } | { error: string } {
  const detail = (change.detail ?? '').trim()

  if (!isCellText(detail)) {
    return { error: 'detail must be one line with no | in it' }
  }

  if (change.status !== 'parked') {
    return { to: detail === '' ? change.status : `${change.status} — ${detail}` }
  }

  const reason = change.reason ?? ''

  if (!(REASONS as readonly string[]).includes(reason)) {
    return {
      error: `a parked card names its reason: one of ${REASONS.join(', ')}. "Too large" or "infeasible" is a forecast, not a reason: make the card's smallest step and run its verify command first`,
    }
  }

  if (reason !== 'split') {
    return detail === '' ? { error: `parked (${reason}) needs a detail: what was tried and the failing line, the mismatch, the question, or the refusal text` } : { to: `parked (${reason}: ${detail})` }
  }

  const children = (change.children ?? []).map(child => child.trim())

  if (children.length === 0) {
    return { error: 'a split names its child cards in children; append them to the index first' }
  }

  for (const child of children) {
    if (keyOf(child) === keyOf(row.id)) {
      return { error: `card ${row.id} cannot be its own child` }
    }

    if (!rows.some(other => keyOf(other.id) === keyOf(child))) {
      return { error: `child ${child} has no card row; append it to the index first` }
    }
  }

  return { to: `parked (split: ${children.join(' ')})${detail === '' ? '' : ` — ${detail}`}` }
}

// A split parent leaves parked only once every child it names is done.
function openChildren(rows: readonly Row[], row: Row): string[] {
  const [, named = ''] = /^parked\W+split\b([^)]*)/i.exec(row.status) ?? []

  return (named.match(/\d+/g) ?? []).filter(child => {
    const found = rows.find(other => keyOf(other.id) === keyOf(child))

    return found === undefined || firstWord(found.status) !== 'done'
  })
}

export function applyStatus(index: string, change: Change): Outcome {
  if (!(STATUSES as readonly string[]).includes(change.status)) {
    return { error: `status is one of ${STATUSES.join(', ')}` }
  }

  const lines = index.split('\n')
  const table = tableOf(lines)

  if (table === null || table.rows.length === 0) {
    return { error: 'the index has no card table with a status column' }
  }

  const row = table.rows.find(found => keyOf(found.id) === keyOf(change.card.trim()))

  if (row === undefined) {
    return { error: `no card ${change.card} in the index (cards: ${table.rows.map(found => found.id).join(' ')})` }
  }

  const open = change.status === 'parked' ? [] : openChildren(table.rows, row)

  if (open.length > 0) {
    return { error: `card ${row.id} is split and its child ${open.join(', ')} is not done; finish or park the children first` }
  }

  const cell = cellOf(change, table.rows, row)

  if ('error' in cell) {
    return cell
  }

  const cells = (lines[row.line] ?? '').split('|')

  cells[table.status] = ` ${cell.to} `
  lines[row.line] = cells.join('|')

  return { index: lines.join('\n'), from: row.status, to: cell.to }
}
