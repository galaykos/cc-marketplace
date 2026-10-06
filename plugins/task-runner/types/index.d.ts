// A contract imports nothing, so the model below restates hooks/board-core.ts's IndexModel.

/**
 * The active run's card index as hooks/board.ts last parsed it, rewritten at
 * session start and after every tool call from CLI 2.1.291. `mtimeMs` is null
 * with no index or one that cannot be statted; with no active run or the board
 * switched off, every field is null, `runActive` false and `phase` empty.
 */
export type TaskBoard = {
  indexPath: string | null
  mtimeMs: number | null
  model: TaskBoardModel | { error: string } | null
  runActive: boolean
  phase: string
}

export type TaskBoardModel = {
  slug: string
  specPath: string | null
  marker: 'GOAL' | 'GOAL lean' | 'ULTRA' | null
  cards: TaskBoardCard[]
  milestones: { id: string; title: string }[]
}

export type TaskBoardCard = {
  id: string
  title: string
  dependsOn: string[]
  group: string
  status: 'pending' | 'in_progress' | 'done' | 'parked' | 'blocked'
  milestone?: string
}

declare module 'claude-code' {
  interface PluginState {
    'task-runner': { board: TaskBoard }
  }
}
