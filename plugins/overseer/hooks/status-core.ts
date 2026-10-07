export type NextMilestone = { k: number; n: number; id: string; title: string; status: string }

type Milestone = { id: string; title: string; status: string; depends?: unknown[] | null }

function isMilestone(m: unknown): m is Milestone {
  if (typeof m !== 'object' || m === null) return false
  const { id, title, status, depends } = m as Record<string, unknown>
  return typeof id === 'string' && typeof title === 'string' && typeof status === 'string' &&
    (depends == null || Array.isArray(depends))
}

// program.sh's NEXT_FILTER stays the reference; scripts/__tests__/status-core.test.sh runs both on every fixture.
export function nextMilestone(program: unknown): NextMilestone | null {
  const ms: unknown = (program as { milestones?: unknown } | null)?.milestones
  if (!Array.isArray(ms) || !ms.every(isMilestone)) return null
  const done = new Set<unknown>(ms.filter((m) => m.status === 'done').map((m) => m.id))
  const i = ms.findIndex((m) =>
    m.status !== 'done' && m.status !== 'parked' && (m.depends ?? []).every((d) => done.has(d)))
  if (i === -1) return null
  const { id, title, status } = ms[i]
  return { k: i + 1, n: ms.length, id, title, status }
}

export function overseerLine(m: NextMilestone): string {
  return `overseer  milestone ${m.k}/${m.n}  ${m.id} ${m.title} (${m.status})`
}
