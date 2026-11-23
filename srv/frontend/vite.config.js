import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

const packageJson = JSON.parse(readFileSync('./package.json', 'utf-8'))

const localeMiddleware = () => ({
  name: 'serve-locales',
  configureServer(server) {
    server.middlewares.use((req, res, next) => {
      // i18next appends ?v=<version>, so match on the path, not the raw URL.
      const path = req.url.split('?')[0];
      if (path.startsWith('/locales/') && path.endsWith('.json')) {
        const lang = path.split('/').pop();
        const localePath = join(__dirname, 'share/locale', lang);
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
    // The commit the image was built from; the Makefile passes it as a docker build arg.
    __GIT_SHA__: JSON.stringify(process.env.GIT_SHA || 'dev'),
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
