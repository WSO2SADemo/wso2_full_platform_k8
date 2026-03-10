import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import https from 'https'

// Dev-only proxy agent: bypass self-signed certs on wso2.com ingresses
const devAgent = new https.Agent({ rejectUnauthorized: false });

const proxyEntry = (target) => ({
  target,
  changeOrigin: true,
  secure: false,
  agent: devAgent,
  configure: (proxy) => {
    proxy.on('error', (err) => console.error(`[proxy error → ${target}]`, err.message));
    proxy.on('proxyReq', (_, req) => console.log(`[proxy →]`, req.method, req.url));
    proxy.on('proxyRes', (res) => console.log(`[proxy ←]`, res.statusCode));
  },
});

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // Token endpoint (avoids CORS on OAuth2 token exchange)
      '/token-proxy': {
        ...proxyEntry('https://cp.wso2.com'),
        rewrite: (path) => path.replace(/^\/token-proxy/, ''),
      },
      // API gateway (avoids CORS on gateway API calls)
      '/gw-proxy': {
        ...proxyEntry('https://gw.wso2.com'),
        rewrite: (path) => path.replace(/^\/gw-proxy/, ''),
      },
      // RabbitMQ Management API via ingress – plain HTTP, no TLS agent
      '/rmq-proxy': {
        target: 'http://rabbitmq.wso2.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/rmq-proxy/, ''),
        configure: (proxy) => {
          proxy.on('error', (err) => console.error('[rmq-proxy error]', err.message));
        },
      },
    },
  },
})
