// Command transform: each PORTABLE command becomes an auto-trigger skill in the reserved
// `cmd-<plugin>-<cmd>` namespace (disjoint from real skill basenames). CC-runtime commands
// (bundle `uninstall`, anything running `claude plugin …`) are skipped, not emitted. The
// trigger description is built by a fixed deterministic template — no LLM — so the output
// is idempotent.
import { readFileSync } from 'node:fs'
import { register } from './registry.mjs'
import { normalizeBody } from './normalize.mjs'
import { parseFrontmatter } from './frontmatter.mjs'
import { splitFrontmatterBlock } from './fsutil.mjs'

register('command', (plugin, ctx) => {
  const writes = []
  for (const cmd of plugin.commands) {
    const raw = readFileSync(cmd.file, 'utf8')
    const { frontmatter } = parseFrontmatter(raw)

    if (isCcRuntimeCommand(cmd.name, raw)) {
      ctx.records.dropped.push({ kind: 'command', plugin: plugin.name, id: `${plugin.name}:${cmd.name}`, reason: 'CC-runtime command (claude plugin / uninstall) — no Codex meaning' })
      continue
    }

    const id = `cmd-${plugin.name}-${cmd.name}`
    const aliasOf = plugin.skills.find((s) => s.name === cmd.name)?.name || null
    const desc = triggerDescription(frontmatter.description || `run the ${plugin.name} ${cmd.name} command`, aliasOf)

    const { body } = splitFrontmatterBlock(raw)
    const norm = normalizeBody(body, (p, n) => ctx.resolveRef(p, n))
    const note = `_This skill wraps the \`/${plugin.name}:${cmd.name}\` command; pass the command's input as the skill's argument (\`$ARGUMENTS\`)._\n\n`
    const content = `---\nname: ${id}\ndescription: ${yamlDq(desc)}\n---\n\n${note}${norm.text}`

    writes.push({ path: `codex/${plugin.name}/skills/${id}/SKILL.md`, content })
    ctx.records.commandSkills.push({
      id,
      plugin: plugin.name,
      cmd: cmd.name,
      aliasOf,
      unresolvedRefs: norm.unresolvedRefs,
    })
  }
  return writes
})

function isCcRuntimeCommand(name, raw) {
  return name === 'uninstall' || /\bclaude plugin\b/.test(raw)
}

function triggerDescription(cmdDesc, aliasOf) {
  const base = `Use when the user asks to ${lowerFirst(cmdDesc.trim())}`
  const withPeriod = /[.!?]$/.test(base) ? base : base + '.'
  return aliasOf ? `${withPeriod} (shorthand for the \`${aliasOf}\` skill.)` : withPeriod
}

function lowerFirst(s) {
  return s.length ? s[0].toLowerCase() + s.slice(1) : s
}

function yamlDq(s) {
  return '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"'
}
