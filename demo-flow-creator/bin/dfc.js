#!/usr/bin/env node
// demo-flow-creator CLI dispatcher.
// Commands: capture | scaffold | serve
// Command modules are lazy-imported so `dfc` / `dfc --help` work before `npm install`.

function parseArgs(argv) {
  const args = { _: [] }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a.startsWith('--')) {
      const key = a.slice(2)
      const next = argv[i + 1]
      if (next === undefined || next.startsWith('--')) {
        args[key] = true
      } else {
        args[key] = next
        i++
      }
    } else {
      args._.push(a)
    }
  }
  return args
}

const USAGE = `demo-flow-creator — local demo-flow generator

Usage:
  dfc capture  --url <url> [--out <dir>] [--wait <ms>] [--headless] [--append]
                                              Headed capture. You clear any gate, then it dumps the flow.
                                              --append adds the current page as another stage (multi-step).
  dfc scaffold [--in <dir>]                   Generate the local Express replica + SQLite store.
  dfc serve    [--in <dir>] [--port <n>]      Run the replica on localhost.
  dfc drive    [--in <dir>] [--data <file>]   Agentically walk the whole flow via the JSON API.

Notes:
  - capture opens a REAL browser window. Clear any anti-bot challenge yourself, reach the
    exact page/flow you want, then press ENTER in the terminal. No headless bypass.
  - --wait <ms> runs non-interactively (load, wait, extract) for GATE-FREE pages / CI only.
    It does not bypass anything; a gated page will simply be blocked. --headless pairs with it.
  - Everything after capture is fully local. Signups write to <dir>/store.sqlite, never the origin.
`

async function main() {
  const [, , cmd, ...rest] = process.argv
  const args = parseArgs(rest)
  const dir = args.out || args.in || 'captured'

  switch (cmd) {
    case 'capture': {
      if (!args.url) {
        console.error('capture needs --url <url>\n')
        console.error(USAGE)
        process.exit(1)
      }
      const { capture } = await import('../src/capture.js')
      await capture({
        url: args.url,
        outDir: dir,
        waitMs: args.wait !== undefined ? Number(args.wait) || 0 : null,
        headless: args.headless === true,
        append: args.append === true,
      })
      break
    }
    case 'scaffold': {
      const { scaffold } = await import('../src/scaffold.js')
      await scaffold({ inDir: dir })
      break
    }
    case 'serve': {
      const { serve } = await import('../src/serve.js')
      await serve({ inDir: dir, port: Number(args.port) || 3000 })
      break
    }
    case 'drive': {
      const { drive } = await import('../src/drive.js')
      await drive({ inDir: dir, dataFile: typeof args.data === 'string' ? args.data : null })
      break
    }
    default:
      console.log(USAGE)
      process.exit(cmd ? 1 : 0)
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
