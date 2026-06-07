import { defineConfig } from 'vite'

// base './' so the embedded asset paths resolve inside the Wails webview.
export default defineConfig({
  base: './',
  build: {
    target: 'es2020',
    emptyOutDir: true,
    chunkSizeWarningLimit: 1500
  }
})
