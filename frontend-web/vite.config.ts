import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:5298',
        changeOrigin: true,
        secure: false,
      },
      '/hubs': {
        target: 'http://localhost:5298',
        ws: true,
        changeOrigin: true,
      },
    },
  },
})
