// A contract imports nothing, so the model below restates hooks/board-core.ts's IndexModel.

/**
 * The card index hooks/board.ts last parsed, rewritten at session start, after
 * every tool call and when /task-board opens the pane, from CLI 2.1.291: the
 * active run's, else while the pane is open the newest 00-INDEX.md under
 * taskmaster-docs/tasks/ by mtime, `runActive` false and `phase` the live
 * sentinel's or empty. `mtimeMs` is null with no index or one that cannot be
 * statted, and the model's `specPath` is joined to the same root as the index.
 * With no run and the pane closed, no index found, or the board
 * switched off, every field is null, `runActive` and `hasRedTeam` false and
 * `phase` empty. `hasRedTeam` is otherwise whether /taskmaster:redteam was
 * installed at the rewrite.
 */
export type TaskBoard = {
  indexPath: string | null
  mtimeMs: number | null
  model: TaskBoardModel | { error: string } | null
  runActive: boolean
  phase: string
  hasRedTeam: boolean
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
