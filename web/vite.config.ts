import { copyFileSync } from 'node:fs'
import path from 'node:path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
// GitHub Pages URL: https://<user>.github.io/<repo>/ — keep base in sync with the repo name.
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    {
      // GitHub Pages SPA fallback: serve index.html for unknown deep links.
      name: 'spa-404-fallback',
      closeBundle() {
        const dist = path.resolve(import.meta.dirname, 'dist')
        copyFileSync(path.join(dist, 'index.html'), path.join(dist, '404.html'))
      },
    },
  ],
  base: '/financial-management/',
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, 'src'),
    },
  },
})
