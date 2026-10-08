import type { Elements, PluginState, RenderElement } from 'claude-code'

import { counts } from './board-core'
import type { Card, IndexModel } from './board-core'

type Board = PluginState['task-runner']['board']

export type BoardKit = {
  ui: Pick<Elements['terminal'], 'Box' | 'Text' | 'Button'>
  columns: number
  fill: (text: string) => Promise<unknown>
}

const MARKS: Record<Card['status'], string> = {
  done: '[x]',
  in_progress: '[>]',
  pending: '[ ]',
  parked: '[-]',
  blocked: '[!]',
  unrecognised: '[?]',
}

function noteOf(board: Board): string {
  if (board.indexPath === null) {
    return board.runActive ? 'plain run — no card index' : 'no card index found'
  }

  return `index unreadable: ${board.indexPath}`
}

function fitted(text: string, width: number): string {
  return text.length <= width ? text.padEnd(width) : `${text.slice(0, width - 1)}…`
}

// Capped at the first unmet card and a count: a long list would size the column and shrink every title.
function statOf(card: Card, done: Set<string>): string {
  const [first, ...rest] = card.dependsOn.filter(id => !done.has(id))

  if (first === undefined) {
    return MARKS[card.status]
  }

  return `${MARKS[card.status]} <${first}${rest.length > 0 ? `+${rest.length}` : ''}`
}

function tableOf(model: IndexModel, columns: number): { text: string; isMilestone: boolean }[] {
  const done = new Set(model.cards.filter(card => card.status === 'done').map(card => card.id))
  const cards = model.cards.map(card => ({ ...card, stat: statOf(card, done) }))
  const groupWidth = Math.max(3, ...cards.map(card => card.group.length + 1))
  const statWidth = Math.max(4, ...cards.map(card => card.stat.length))
  const titleWidth = Math.max(8, columns - (2 + 1 + 1 + groupWidth + 2 + statWidth))

  const line = (id: string, title: string, group: string, stat: string) =>
    `${id.padEnd(2)} ${fitted(title, titleWidth)} ${group.padEnd(groupWidth)}  ${stat}`

  const rowsOf = (milestone: string | undefined) =>
    cards
      .filter(card => card.milestone === milestone)
      .map(card => ({ text: line(card.id, card.title, ` ${card.group}`, card.stat), isMilestone: false }))

  return [
    { text: line('#', 'card', 'grp', 'stat'), isMilestone: false },
    ...rowsOf(undefined),
    ...model.milestones.flatMap(m => [{ text: `Milestone ${m.id} — ${m.title}`, isMilestone: true }, ...rowsOf(m.id)]),
  ]
}

export function boardView(kit: BoardKit, board: Board): RenderElement {
  const { Box, Text, Button } = kit.ui
  const { model, indexPath } = board

  if (model === null || 'error' in model || indexPath === null) {
    return <Text>{noteOf(board)}</Text>
  }

  const c = counts(model)
  const header = ['Task board', model.slug, model.marker ?? '', board.runActive ? '' : 'not running']
  const summary = [board.phase, `${c.done}/${c.total} done`, `${c.parked} parked`, c.unrecognised > 0 ? `${c.unrecognised} unrecognised` : '']
  const specPath = model.specPath

  return (
    <Box flexDirection="column">
      <Text>{header.filter(part => part !== '').join('  ')}</Text>
      <Text>{summary.filter(part => part !== '').join('  ')}</Text>
      <Box flexDirection="row" gap={2}>
        <Button key="run-next" hotkey="r" plain autoFocus onPress={() => kit.fill(`/task-runner:run ${indexPath}`)}>
          Run next
        </Button>
        {board.hasRedTeam && specPath !== null ? (
          <Button key="red-team" hotkey="t" plain onPress={() => kit.fill(`/taskmaster:redteam ${specPath}`)}>
            Red-team
          </Button>
        ) : null}
      </Box>
      {tableOf(model, kit.columns).map(row => (
        <Text bold={row.isMilestone} wrap="truncate-end">
          {row.text}
        </Text>
      ))}
    </Box>
  )
}
