// Agent transform: each subagent .md -> a Codex ~/.codex/agents/<name>.toml (emitted
// into codex/agents/, placed out-of-band by install-agents.sh — card 11). Corrections
// folded from red-team: OMIT the CC model slug (invalid on Codex), map effort via the
// verified enum, preserve a Read/Grep/Glob-only agent's read-only contract as
// sandbox_mode="read-only" (security), and resolve bestpractices-skill refs to real ids.
import { readFileSync } from 'node:fs'
import { register } from './registry.mjs'
import { normalizeBody } from './normalize.mjs'
import { parseFrontmatter } from './frontmatter.mjs'
import { splitFrontmatterBlock } from './fsutil.mjs'
import { toml } from './serialize.mjs'
import { AGENT_TOML, EFFORT_MAP } from '../schema.mjs'

const READ_ONLY_TOOLSET = ['Glob', 'Grep', 'Read']

register('agent', (plugin, ctx) => {
  const writes = []
  for (const agent of plugin.agents) {
    const raw = readFileSync(agent.file, 'utf8')
    const { frontmatter } = parseFrontmatter(raw)
    const { body } = splitFrontmatterBlock(raw)
    const instructions = normalizeBody(body, (p, n) => ctx.resolveRef(p, n)).text

    // effort -> model_reasoning_effort (verified enum; identity map, no clamp needed)
    let effort
    if (frontmatter.effort) {
      effort = EFFORT_MAP[frontmatter.effort]
      if (!effort || !AGENT_TOML.reasoningEffortEnum.includes(effort)) {
        throw new Error(`agent ${agent.name}: effort "${frontmatter.effort}" has no valid Codex model_reasoning_effort`)
      }
    }

    // read-only contract preserved as sandbox_mode (security); else a permissions note
    const toolset = (frontmatter.tools || '').split(',').map((s) => s.trim()).filter(Boolean).sort()
    const readOnly = toolset.length > 0 && sameSet(toolset, READ_ONLY_TOOLSET)
    let devInstructions = instructions
    if (!readOnly && frontmatter.tools) {
      devInstructions += `\n\n---\nPermissions note: in Claude Code this agent was scoped to tools: ${frontmatter.tools}. Codex governs capability via sandbox_mode/permissions; grant the equivalent access.`
    }

    // bestpractices-skill -> [skills.config]; resolve each to its (globally-unique) id
    const requiredCoInstalls = []
    let skillsConfig
    if (frontmatter['bestpractices-skill']) {
      const ids = []
      for (const bare of frontmatter['bestpractices-skill'].split(',').map((s) => s.trim()).filter(Boolean)) {
        const resolved = ctx.resolveSkill(bare)
        if (!resolved) throw new Error(`agent ${agent.name}: bestpractices-skill "${bare}" resolves to no skill`)
        ids.push(resolved.id)
        if (resolved.owner !== plugin.name) requiredCoInstalls.push({ skill: resolved.id, ownerPlugin: resolved.owner })
      }
      skillsConfig = { skills: ids }
    }

    const obj = {
      name: frontmatter.name,
      description: frontmatter.description,
      developer_instructions: devInstructions,
      // model: OMITTED by design (AGENT_TOML.omitModel) — CC slugs are invalid Codex ids
    }
    if (effort) obj.model_reasoning_effort = effort
    if (readOnly) obj.sandbox_mode = 'read-only'
    if (skillsConfig) obj['skills.config'] = skillsConfig

    writes.push({ path: `codex/agents/${agent.name}.toml`, content: toml(obj) })
    ctx.records.agents.push({
      agent: agent.name,
      plugin: plugin.name,
      effort: effort || null,
      readOnly,
      modelOmitted: true,
      requiredCoInstalls,
    })
  }
  return writes
})

function sameSet(a, b) {
  return a.length === b.length && a.every((x, i) => x === b[i])
}
