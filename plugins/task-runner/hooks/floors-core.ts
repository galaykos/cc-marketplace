const LADDER = ['haiku', 'sonnet', 'opus', 'fable']

const ENTRY = /^[\w-]+:[\w-]+\s+[\w.-]+$/

// A fenced block is the registry only when every non-blank line in it is an entry; with none such, there are no floors.
export function parseRegistry(md: string): Map<string, string> {
  let block: string[] | null = null
  for (const line of md.split('\n')) {
    if (!line.trimStart().startsWith('```')) {
      block?.push(line.trim())
      continue
    }
    if (block === null) {
      block = []
      continue
    }
    const entries = block.filter((l) => l !== '')
    if (entries.length > 0 && entries.every((l) => ENTRY.test(l))) {
      return new Map(entries.map((l) => l.split(/\s+/) as [string, string]))
    }
    block = null
  }
  return new Map()
}

export function rank(model: string | undefined): number | null {
  const m = model?.toLowerCase() ?? ''
  const i = LADDER.findIndex((family) => m.includes(family))
  return i === -1 ? null : i + 1
}

// undefined leaves the spawn's model as it is.
export function decideModel(i: { explicit?: string; parentModel: string; floor: string }): string | undefined {
  const base = i.explicit ?? i.parentModel
  const have = rank(base)
  const floor = rank(i.floor)
  if (have === null || floor === null) return undefined
  if (i.explicit !== undefined && have >= floor) return undefined
  return have >= floor ? base : i.floor
}
