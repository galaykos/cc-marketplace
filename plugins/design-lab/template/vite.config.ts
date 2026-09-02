import path from 'node:path'
import { defineConfig, type PluginOption } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Dev-only marker endpoint so a runtime can positively identify this server
// (GET /__studio -> 200 "shadcn-studio") before deciding to reuse it.
function studioMarker(): PluginOption {
  return {
    name: 'studio-marker',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use('/__studio', (_req, res) => {
        res.statusCode = 200
        res.end('shadcn-studio')
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), studioMarker()],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  server: {
    host: '127.0.0.1',
    // Own variable, NOT the shared PREVIEW_PORT — otherwise a `PREVIEW_PORT=<n>`
    // override (meant to relocate the shared mockup server) would make this harness
    // bind the same port, and the shared-server reuse/kill logic in taskmaster/ui-ux
    // would then target this Vite dev server by mistake.
    port: Number(process.env.SHADCN_STUDIO_PORT) || 8124,
    strictPort: false,
  },
})
