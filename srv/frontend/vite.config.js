import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

const packageJson = JSON.parse(readFileSync('./package.json', 'utf-8'))

const localeMiddleware = () => ({
  name: 'serve-locales',
  configureServer(server) {
    server.middleware.use((req, res, next) => {
      if (req.url.startsWith('/locales/') && req.url.endsWith('.json')) {
        const lang = req.url.split('/').pop().split('?')[0];
        const localePath = join(__dirname, '../../helm/share/locale', lang);
        if (existsSync(localePath)) {
          res.setHeader('Content-Type', 'application/json');
          res.end(readFileSync(localePath));
          return;
        }
      }
      next();
    });
  }
});

export default defineConfig({
  plugins: [react(), localeMiddleware()],
  define: {
    __APP_VERSION__: JSON.stringify(packageJson.version),
    __BUILD_DATE__: JSON.stringify(new Date().toISOString()),
  },
  server: {
    port: 3000,
    host: true,
    proxy: {
      '/auth': 'http://localhost:8080',
      '/ws': {
        target: 'ws://localhost:8080',
        ws: true
      },
      '/players': 'http://localhost:8080'
    }
  }

})
