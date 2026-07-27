#!/usr/bin/env node
/* registry-source — component registries, read from the source, never from recall.
 *
 * WHY THIS EXISTS AS A TOOL AND NOT AS A RULE.
 *
 * Two skills in this marketplace already say it in plain words —
 * `ui-ux/skills/reui-best-practices` ("never write ReUI API details from
 * memory") and `ui-ux/skills/aceternity-best-practices` ("do not reconstruct
 * the component from memory"). Both are well written. A run breached each of
 * them anyway, in the same session, three times over: it estimated a registry
 * at "~60 components" when the index holds 270, it read a 401 on a paid
 * install endpoint as proof the components were unavailable, and then read the
 * vendor's marketing page as proof the endpoint was open.
 *
 * None of that was disobedience. Recall does not FEEL like breaking a rule —
 * it feels like knowing something, and the moment it would have been checked
 * is the moment it feels least necessary. A prose rule cannot fire there. A
 * tool in the tool list can, because it makes fetching the source cheaper than
 * remembering it, which is the only thing that reliably beats memory.
 *
 * WHY A CACHE AND NOT A LOCAL COPY.
 *
 * The obvious fix — scrape the registries once into a nice file for the model
 * to read — recreates the bug one layer out, and this repo can prove it: the
 * hand-written inventory in `references/aceternity.md` was five days old and
 * said "100+" against an actual 270, and the gate copied into a built project
 * was already older than the plugin that shipped it. A copy written once has
 * no freshness signal, so it gets read as truth forever.
 *
 * So every answer here carries `source`, `fetched_at` and `stale` beside the
 * data. Same file on disk as a scraped copy; opposite epistemics. The cache is
 * a speed and offline concession, never an authority, and when the network is
 * gone it says how old what it is serving is rather than quietly serving it.
 *
 * WHAT IT WILL NOT DO. One registry gates its install API behind a paid
 * licence key. This server does not hold, request, forge or route a licence
 * key, and its ReUI entry points at that project's own MIT repository instead
 * — which is not a workaround but the licence working exactly as written. A
 * paywall on a convenience API is a fact about paying for tooling; the LICENSE
 * file is the fact about the code.
 *
 * Dependency-free on purpose: raw JSON-RPC over stdio, node built-ins only, so
 * the plugin installs with no npm step and cannot rot against an SDK.
 */

import { readFileSync, writeFileSync, mkdirSync, statSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'

/* Registries this server can reach WITHOUT credentials. Every URL here was
   verified answering 200 on the day this file was written; a registry that
   needs a key does not belong in this table at all, because a half-working
   entry teaches the model the registry is broken rather than that it is paid. */
const REGISTRIES = {
  aceternity: {
    index: 'https://ui.aceternity.com/registry.json',
    item: (n) => `https://ui.aceternity.com/registry/${n}.json`,
    note: 'motion-heavy marketing/landing blocks; several pull a WebGL runtime',
  },
  shadcn: {
    index: 'https://ui.shadcn.com/r/index.json',
    item: (n) => `https://ui.shadcn.com/r/styles/new-york/${n}.json`,
    note: 'the base primitive set most other registries build on',
  },
  magicui: {
    index: 'https://magicui.design/r/registry.json',
    item: (n) => `https://magicui.design/r/${n}.json`,
    note: 'animated marketing components, shadcn-compatible',
  },
  /* NO `reui` ENTRY — AND THE REMOVAL IS THE POINT.
   *
   * One shipped here pointing at a GitHub contents path. A survey pass ran it
   * and got three items back: `{dir:1, file:2}`. It was listing a DIRECTORY,
   * not components, and would have reported that registry as holding 3 things.
   *
   * The comment directly above this table already forbade exactly that — "a
   * half-working entry teaches the model the registry is broken rather than
   * that it is paid" — and the entry was added anyway, in the same file, in the
   * same commit. Writing a rule does not enforce it; that is the whole reason
   * this plugin exists rather than another paragraph telling a model to check.
   *
   * ReUI is served by its OWN MCP server, declared beside this one in the
   * plugin's `.mcp.json` and authenticated by a browser sign-in the user
   * completes. That server answers with a typed breakdown — components,
   * examples, blocks, icons — which is strictly better than anything a
   * credential-free scrape could produce. Two paths to one registry, one of
   * them lossy, is how a build ends up quoting the wrong number with a source
   * attached. */
}

const CACHE_DIR = join(homedir(), '.cache', 'claude-registry-source')
const TTL_MS = 24 * 60 * 60 * 1000

/* Dependencies that put a 3D/particle runtime in the bundle. Flagged because a
   registry index is the only place a build can learn what a block COSTS before
   installing it — craft-layer's ambition floors count motion capabilities, and
   a casually-picked block can supply one nobody chose. */
const HEAVY_DEP = /^(?:three|three-globe|cobe|@react-three\/|@tsparticles\/|simplex-noise)/

function cachePath(key) {
  return join(CACHE_DIR, `${key}.json`)
}

function readCache(key) {
  const p = cachePath(key)
  if (!existsSync(p)) return null
  try {
    const raw = JSON.parse(readFileSync(p, 'utf8'))
    return { ...raw, age_ms: Date.now() - new Date(raw.fetched_at).getTime() }
  } catch { return null }
}

function writeCache(key, source, data) {
  try {
    mkdirSync(CACHE_DIR, { recursive: true })
    const rec = { source, fetched_at: new Date().toISOString(), data }
    writeFileSync(cachePath(key), JSON.stringify(rec))
    return { ...rec, age_ms: 0 }
  } catch {
    return { source, fetched_at: new Date().toISOString(), data, age_ms: 0 }
  }
}

/** Fetch with the cache in front, and NEVER silently. The return always says
    where the bytes came from and how old they are — a cache hit and a live
    fetch are different epistemic states and the caller must be able to tell. */
async function fetchCached(key, url, { refresh = false } = {}) {
  const cached = readCache(key)
  if (!refresh && cached && cached.age_ms < TTL_MS) {
    return { ...cached, from: 'cache', stale: false }
  }
  try {
    const res = await fetch(url, {
      headers: { accept: 'application/json', 'user-agent': 'claude-registry-source' },
      signal: AbortSignal.timeout(20000),
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const data = await res.json()
    return { ...writeCache(key, url, data), from: 'network', stale: false }
  } catch (e) {
    if (cached) {
      return {
        ...cached,
        from: 'cache',
        stale: true,
        warning: `live fetch of ${url} failed (${e.message}); serving cache from `
          + `${cached.fetched_at} — ${Math.round(cached.age_ms / 3600000)}h old. Treat as possibly outdated.`,
      }
    }
    throw new Error(`${url} unreachable (${e.message}) and nothing cached. Do NOT answer from memory — say it is unreachable.`)
  }
}

/** Three registries, three index shapes, one normaliser. Kept to what a build
    decision actually turns on — name, kind, deps, and whether it is heavy —
    because the raw indexes total ~200KB and the point is to be readable. */
function normalise(payload) {
  const items = Array.isArray(payload) ? payload : (payload?.items ?? [])
  return items.map((i) => {
    const deps = [...(i.dependencies ?? []), ...(i.registryDependencies ?? [])]
    const heavy = deps.filter((d) => HEAVY_DEP.test(d))
    return {
      name: i.name,
      kind: String(i.type ?? '').replace('registry:', '') || undefined,
      deps: deps.length ? deps : undefined,
      heavy: heavy.length ? heavy : undefined,
    }
  })
}

const provenance = (r) => ({
  source: r.source,
  fetched_at: r.fetched_at,
  from: r.from,
  stale: r.stale,
  ...(r.warning ? { warning: r.warning } : {}),
})

/* ------------------------------------------------------------------- tools */

async function registryList({ registry, refresh }) {
  const names = registry ? [registry] : Object.keys(REGISTRIES)
  const out = {}
  for (const n of names) {
    const cfg = REGISTRIES[n]
    if (!cfg) { out[n] = { error: `unknown registry; known: ${Object.keys(REGISTRIES).join(', ')}` }; continue }
    try {
      const r = await fetchCached(`${n}-index`, cfg.index, { refresh })
      const items = normalise(r.data)
      out[n] = {
        ...provenance(r),
        note: cfg.note,
        count: items.length,
        heavy_count: items.filter((i) => i.heavy).length,
        components: items,
      }
    } catch (e) {
      out[n] = { error: e.message, note: cfg.note }
    }
  }
  return out
}

async function registrySearch({ query, registry, refresh }) {
  const q = String(query ?? '').toLowerCase().trim()
  if (!q) return { error: 'query is required' }
  const listed = await registryList({ registry, refresh })
  const hits = []
  for (const [n, r] of Object.entries(listed)) {
    if (r.error) continue
    for (const c of r.components ?? []) {
      const hay = `${c.name} ${c.kind ?? ''} ${(c.deps ?? []).join(' ')}`.toLowerCase()
      if (hay.includes(q)) hits.push({ registry: n, ...c })
    }
  }
  return {
    query: q,
    matches: hits.length,
    searched: Object.fromEntries(Object.entries(listed).map(([n, r]) => [n, provenance(r)])),
    results: hits,
  }
}

async function registryGet({ registry, name, refresh }) {
  const cfg = REGISTRIES[registry]
  if (!cfg) return { error: `unknown registry; known: ${Object.keys(REGISTRIES).join(', ')}` }
  if (!name) return { error: 'name is required' }
  if (!cfg.item) {
    return {
      error: `${registry} has no per-component JSON endpoint this server may use`,
      guidance: cfg.note,
      ...(cfg.github ? { read_source_at: `https://github.com/${cfg.github}` } : {}),
    }
  }
  const r = await fetchCached(`${registry}-${name}`, cfg.item(name), { refresh })
  const d = r.data ?? {}
  return {
    ...provenance(r),
    name: d.name ?? name,
    kind: String(d.type ?? '').replace('registry:', '') || undefined,
    dependencies: d.dependencies,
    registryDependencies: d.registryDependencies,
    heavy: (d.dependencies ?? []).filter((x) => HEAVY_DEP.test(x)),
    files: (d.files ?? []).map((f) => (typeof f === 'string' ? f : f.path ?? f.target)),
    install: `npx shadcn@latest add ${cfg.item(name)}`,
    file_contents: (d.files ?? []).map((f) => (typeof f === 'string' ? null : f.content)).filter(Boolean),
  }
}

const TOOLS = [
  {
    name: 'registry_list',
    description:
      'List every component in the free component registries (aceternity, shadcn, magicui, reui), read live from '
      + 'their published index and cached for 24h. Returns name, kind, dependencies, and a `heavy` flag for anything '
      + 'pulling a 3D/particle runtime — plus source URL, fetch date and a stale flag on every answer. Use this BEFORE '
      + 'picking a component or estimating what a registry contains; never state a component count or catalogue from memory.',
    inputSchema: {
      type: 'object',
      properties: {
        registry: { type: 'string', description: 'aceternity | shadcn | magicui | reui. Omit for all.' },
        refresh: { type: 'boolean', description: 'Bypass the 24h cache and refetch.' },
      },
    },
  },
  {
    name: 'registry_search',
    description:
      'Search all configured component registries by name, kind or dependency — e.g. "parallax", "bento", "scroll", '
      + '"three". Returns matching components with their registry, deps and heaviness. Use when looking for a component '
      + 'that does something, rather than recalling one that might exist.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Substring matched against name, kind and dependencies.' },
        registry: { type: 'string', description: 'Restrict to one registry. Omit for all.' },
        refresh: { type: 'boolean' },
      },
      required: ['query'],
    },
  },
  {
    name: 'registry_get',
    description:
      'Fetch one component\'s real registry entry: exact dependencies, file list, source contents and install command. '
      + 'Use before asserting any component\'s props, imports or dependencies — those change in place in copy-paste '
      + 'registries and a remembered snippet diverges silently.',
    inputSchema: {
      type: 'object',
      properties: {
        registry: { type: 'string', description: 'aceternity | shadcn | magicui' },
        name: { type: 'string', description: 'Component name as it appears in the index.' },
        refresh: { type: 'boolean' },
      },
      required: ['registry', 'name'],
    },
  },
]

const HANDLERS = { registry_list: registryList, registry_search: registrySearch, registry_get: registryGet }

/* --------------------------------------------------------- JSON-RPC / stdio */

const send = (msg) => process.stdout.write(`${JSON.stringify(msg)}\n`)

async function handle(req) {
  const { id, method, params } = req
  if (method === 'initialize') {
    return {
      jsonrpc: '2.0',
      id,
      result: {
        protocolVersion: params?.protocolVersion ?? '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'registry-source', version: '0.1.0' },
      },
    }
  }
  if (method === 'tools/list') return { jsonrpc: '2.0', id, result: { tools: TOOLS } }
  if (method === 'tools/call') {
    const fn = HANDLERS[params?.name]
    if (!fn) return { jsonrpc: '2.0', id, error: { code: -32601, message: `unknown tool ${params?.name}` } }
    try {
      const result = await fn(params.arguments ?? {})
      return { jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] } }
    } catch (e) {
      /* Surfaced as tool content rather than swallowed: "unreachable" is a
         real answer this server owes, and the one it must never replace with
         a plausible reconstruction. */
      return {
        jsonrpc: '2.0',
        id,
        result: { content: [{ type: 'text', text: JSON.stringify({ error: e.message }, null, 2) }], isError: true },
      }
    }
  }
  if (method?.startsWith('notifications/')) return null
  return { jsonrpc: '2.0', id, error: { code: -32601, message: `unknown method ${method}` } }
}

let buf = ''
process.stdin.setEncoding('utf8')
process.stdin.on('data', async (chunk) => {
  buf += chunk
  let nl
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl).trim()
    buf = buf.slice(nl + 1)
    if (!line) continue
    let req
    try { req = JSON.parse(line) } catch { continue }
    const res = await handle(req)
    if (res) send(res)
  }
})
