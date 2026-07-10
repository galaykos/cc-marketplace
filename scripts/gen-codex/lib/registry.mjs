// Transform registry. Each transform is `(plugin, ctx) => Write[]` where a Write is
// `{ path, content }` (text file) or `{ path, copyFrom }` (byte copy, for assets/data).
// Transforms may also push structured records into `ctx.records` for the manifest
// transform (card 08). gen.mjs runs registered transforms in registration order.

/** @typedef {{ path: string, content?: string, copyFrom?: string, mode?: number }} Write */

const transforms = []

/** @param {string} name @param {(plugin:any, ctx:any)=>Write[]} fn */
export function register(name, fn) {
  transforms.push({ name, fn })
}

export function getTransforms() {
  return transforms
}

/** Fresh shared context for one generator run. */
export function makeContext(plugins) {
  const bySkillBasename = new Map()
  const commandsByPlugin = new Map()
  for (const p of plugins) {
    for (const s of p.skills) bySkillBasename.set(s.name, p.name)
    commandsByPlugin.set(p.name, new Set(p.commands.map((c) => c.name)))
  }
  return {
    plugins,
    // records collected by transforms, consumed by the manifest transform
    records: {
      skills: [],
      commandSkills: [],
      agents: [],
      hooks: [],
      dropped: [],
      degraded: [],
    },
    // resolve a bare skill basename to its Codex skill id (== basename, since basenames
    // are globally unique) and owning plugin, or null if unknown.
    resolveSkill(basename) {
      const owner = bySkillBasename.get(basename)
      return owner ? { id: basename, owner } : null
    },
    // resolve a `/plugin:name` cross-reference to its Codex skill id:
    //  - a command of that plugin -> `cmd-<plugin>-<name>` (card 05 namespace)
    //  - else a skill by that basename -> the basename
    //  - else null (unresolved; recorded for the disclosure)
    resolveRef(plugin, name) {
      const cmds = commandsByPlugin.get(plugin)
      if (cmds && cmds.has(name)) return `cmd-${plugin}-${name}`
      const s = bySkillBasename.get(name)
      if (s) return name
      return null
    },
  }
}
