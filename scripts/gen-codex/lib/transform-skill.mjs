// Skill transform: copy each plugin skill's WHOLE directory to .agents/skills/<basename>/
// (basenames are globally unique, so name==dir holds and the body stays byte-equal except
// for D6-normalized tokens). references/ and assets/ are copied verbatim.
import { readFileSync } from 'node:fs'
import { register } from './registry.mjs'
import { normalizeBody, classifyPortability } from './normalize.mjs'
import { parseFrontmatter } from './frontmatter.mjs'
import { walkFiles } from './fsutil.mjs'

register('skill', (plugin, ctx) => {
  const writes = []
  for (const skill of plugin.skills) {
    const files = walkFiles(skill.dir)
    let record
    for (const f of files) {
      // bundled UNDER the plugin so `codex plugin add` delivers the skill (verified against
      // codex-cli 0.143.0: install copies the plugin dir only, not repo-level .agents/skills)
      const outPath = `codex/${plugin.name}/skills/${skill.name}/${f.rel}`
      if (f.rel === 'SKILL.md') {
        const raw = readFileSync(f.abs, 'utf8')
        const { frontmatter } = parseFrontmatter(raw)
        // normalize tokens across the WHOLE file (frontmatter description can also carry
        // ${CLAUDE_PLUGIN_ROOT}); structure and the name==dir line are preserved.
        const norm = normalizeBody(raw, (p, n) => ctx.resolveRef(p, n))
        writes.push({ path: outPath, content: norm.text })

        const port = classifyPortability(raw)
        record = {
          skill: skill.name,
          plugin: plugin.name,
          name: frontmatter.name,
          codexId: skill.name,
          files: files.map((x) => x.rel),
          degraded: port.degraded,
          degradeReasons: port.reasons,
          unresolvedRefs: norm.unresolvedRefs,
        }
        ctx.records.skills.push(record)
        if (port.degraded) {
          ctx.records.degraded.push({ kind: 'skill', id: skill.name, plugin: plugin.name, reasons: port.reasons })
        }
      } else {
        // references/ + assets/ + any other bundled file — copy verbatim
        writes.push({ path: outPath, copyFrom: f.abs })
      }
    }
  }
  return writes
})
