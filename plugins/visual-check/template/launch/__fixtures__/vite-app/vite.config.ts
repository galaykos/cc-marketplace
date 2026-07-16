import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Fixture config for launch detection (card 11). Not executed by the detector —
// only read as text for the `@vitejs/plugin-react` signal and the server port.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
});
