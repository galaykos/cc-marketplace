// Hook transform: keep SessionStart/UserPromptSubmit/PostToolUse; drop SessionEnd (no
// Codex peer); rewrite every ${CLAUDE_PLUGIN_ROOT} form -> ${PLUGIN_ROOT} in hooks.json
// AND scripts; remap matcher tool names; copy plugin-root data the scripts read; if a
// plugin's hooks reduce to zero events, emit NO hooks.json. Hooks whose scripts inject
// CC-only guidance are flagged degraded (accept-as-risk), not silently shipped faithful.
import { readFileSync } from 'node:fs'
import { register } from './registry.mjs'
import { normalizeShell, classifyPortability } from './normalize.mjs'
import { stableJson } from './serialize.mjs'
import { CC_HOOK_EVENT_SUPPORTED, HOOK_EVENTS, TOOL_MATCHER_MAP } from '../schema.mjs'

register('hook', (plugin, ctx) => {
  if (!plugin.hooks) return []
  const writes = []
  const src = JSON.parse(readFileSync(plugin.hooks.jsonPath, 'utf8'))
  const outHooks = {}
  const kept = []
  const droppedEvents = []

  for (const [event, groups] of Object.entries(src.hooks || {})) {
    const codexEvent = resolveEvent(event)
    if (codexEvent === null) {
      droppedEvents.push(event)
      continue
    }
    const newGroups = []
    for (const g of groups) {
      let matcher = g.matcher
      if (matcher !== undefined) {
        matcher = mapMatcher(matcher)
        if (matcher === '') {
          droppedEvents.push(`${event}[matcher:${g.matcher}]`)
          continue
        }
      }
      const inner = (g.hooks || []).map((h) => ({ ...h, command: normalizeShell(h.command).text }))
      newGroups.push(matcher !== undefined ? { matcher, hooks: inner } : { hooks: inner })
    }
    if (newGroups.length) {
      outHooks[codexEvent] = newGroups
      kept.push(codexEvent)
    }
  }

  // scripts: rewrite ${CLAUDE_PLUGIN_ROOT} in bodies, keep executable; flag degraded guidance
  const degradedReasons = new Set()
  const scriptTexts = []
  for (const script of plugin.hooks.scripts) {
    const abs = `${plugin.dir}/hooks/${script}`
    const rawScript = readFileSync(abs, 'utf8')
    scriptTexts.push(rawScript)
    const rewritten = normalizeShell(rawScript).text
    writes.push({ path: `codex/${plugin.name}/hooks/${script}`, content: rewritten, mode: 0o755 })
    for (const r of classifyPortability(rawScript).reasons) degradedReasons.add(r)
  }

  // copy plugin-root data any script reads (e.g. rules.tsv)
  const copiedData = []
  for (const data of plugin.rootData) {
    if (scriptTexts.some((t) => t.includes(data.name))) {
      writes.push({ path: `codex/${plugin.name}/${data.name}`, copyFrom: data.file })
      copiedData.push(data.name)
    }
  }

  // only emit hooks.json if at least one event survived
  if (kept.length) {
    writes.push({ path: `codex/${plugin.name}/hooks/hooks.json`, content: stableJson({ hooks: outHooks }) })
  }

  ctx.records.hooks.push({
    plugin: plugin.name,
    keptEvents: kept,
    droppedEvents,
    fullyDropped: kept.length === 0,
    degradedReasons: [...degradedReasons].sort(),
    copiedData,
  })
  if (degradedReasons.size) ctx.records.degraded.push({ kind: 'hook', id: plugin.name, plugin: plugin.name, reasons: [...degradedReasons].sort() })
  if (kept.length === 0) ctx.records.dropped.push({ kind: 'hooks', plugin: plugin.name, id: plugin.name, reason: `all hook events unsupported on Codex (${droppedEvents.join(', ')})` })

  return writes
})

function resolveEvent(event) {
  if (event in CC_HOOK_EVENT_SUPPORTED) return CC_HOOK_EVENT_SUPPORTED[event] // may be null (SessionEnd)
  return HOOK_EVENTS.includes(event) ? event : null
}

function mapMatcher(matcher) {
  const mapped = matcher
    .split('|')
    .map((tool) => (tool in TOOL_MATCHER_MAP ? TOOL_MATCHER_MAP[tool] : tool))
    .filter((t) => t != null)
  return [...new Set(mapped)].join('|')
}
