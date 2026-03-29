import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_')

  const wso2K8Base   = env.VITE_WSO2_K8_BASE   || 'https://kgw.wso2.com:9095'
  const envoyBase    = env.VITE_ENVOY_BASE      || 'https://envoygw.wso2.com:8443'
  const universalBase = env.VITE_UNIVERSAL_BASE || 'https://gw.wso2.com'
  const azureBase    = env.VITE_AZURE_BASE      || 'https://apimserviceramindus.azure-api.net'

  return {
    plugins: [react()],
    server: {
      port: 3001,
      proxy: {
        '/api/devportal': {
          target: 'http://localhost:3002',
          changeOrigin: false,
        },
        '/proxy/wso2k8': {
          target: wso2K8Base,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/proxy\/wso2k8/, '')
        },
        '/proxy/envoy': {
          target: envoyBase,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/proxy\/envoy/, '')
        },
        '/proxy/universal': {
          target: universalBase,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/proxy\/universal/, '')
        },
        '/proxy/azure': {
          target: azureBase,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/proxy\/azure/, '')
        },
        '/api/migrate': {
          target: 'http://localhost:3002',
          changeOrigin: false,
        },
      }
    }
  }
})
