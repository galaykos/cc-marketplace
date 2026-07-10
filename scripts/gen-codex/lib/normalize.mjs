// Normalize CC-only tokens on a COPIED artifact body/script (never the source under
// plugins/). Resolves the "byte-equal vs correct-on-Codex" tension: source files stay
// untouched (so validate.sh incl. its :141 literal-string check passes) while the Codex
// copy is corrected. Shared by the skill, command, agent, and hook transforms.

const PLUG_CMD_REF = /\/([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)/g

/**
 * Rewrite `/plugin:name` cross-references to a Codex skill reference. `resolve(plugin,
 * name)` returns the Codex skill id (or null if it can't be resolved). Unresolved refs
 * are kept literal and reported for the fidelity disclosure.
 * @param {string} text
 * @param {(plugin:string,name:string)=>string|null} resolve
 * @returns {{ text: string, unresolvedRefs: string[] }}
 */
export function normalizeBody(text, resolve) {
  const unresolved = new Set()
  let out = text.replace(PLUG_CMD_REF, (whole, plugin, name) => {
    const id = resolve ? resolve(plugin, name) : null
    if (id) return `the \`${id}\` skill`
    unresolved.add(`/${plugin}:${name}`)
    return whole
  })
  // D6 also rewrites the CC plugin-root variable when it appears in prose/examples
  // (e.g. the authoring-hooks and delegation-contracts skill bodies).
  out = out.split('CLAUDE_PLUGIN_ROOT').join('PLUGIN_ROOT')
  return { text: out, unresolvedRefs: [...unresolved].sort() }
}

/**
 * Rewrite every ${CLAUDE_PLUGIN_ROOT} form — `${CLAUDE_PLUGIN_ROOT}`,
 * `${CLAUDE_PLUGIN_ROOT:-}`, bareword `$CLAUDE_PLUGIN_ROOT` — to the Codex `PLUGIN_ROOT`
 * equivalent. Replacing the variable NAME covers all three brace/modifier forms at once.
 * @param {string} text
 * @returns {{ text: string, remaining: number }}
 */
export function normalizeShell(text) {
  const out = text.split('CLAUDE_PLUGIN_ROOT').join('PLUGIN_ROOT')
  const remaining = (out.match(/CLAUDE_PLUGIN_ROOT/g) || []).length
  return { text: out, remaining }
}

// markers of CC-runtime coupling that normalization CANNOT fix — these feed the
// fidelity disclosure (degraded), not a silent rewrite.
const DEGRADE_MARKERS = [
  { re: /~\/\.claude\/plugins/, reason: 'scans ~/.claude/plugins (no Codex equivalent path)' },
  { re: /~\/\.claude\/projects/, reason: 'reads ~/.claude/projects transcripts (absent on Codex)' },
  { re: /~\/\.claude(?!\/(?:plugins|projects))/, reason: 'reads a ~/.claude path with no Codex peer' },
  { re: /\bWorkflow\b tool|\bagent\(\)|\bAgent dispatch\b|subagents\/workflows/, reason: 'invokes CC-only orchestration primitives (Workflow/agent())' },
]

/**
 * @param {string} text
 * @returns {{ degraded: boolean, reasons: string[] }}
 */
export function classifyPortability(text) {
  const reasons = []
  for (const m of DEGRADE_MARKERS) if (m.re.test(text)) reasons.push(m.reason)
  return { degraded: reasons.length > 0, reasons }
}
