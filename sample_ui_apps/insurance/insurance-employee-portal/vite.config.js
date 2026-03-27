import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  const chatApiBase = env.VITE_CHAT_API_BASE || 'https://gw.wso2.com/insuranceagentchatapi/1.0.0/insurance_agent'
  const chatApiUrl = new URL(chatApiBase)
  const chatTarget = `${chatApiUrl.protocol}//${chatApiUrl.host}`
  const chatPath = chatApiUrl.pathname

  const oboChatApiBase = env.VITE_OBO_CHAT_API_BASE || 'https://gw.wso2.com/insuranceagentchatapi/1.0.0/insurance_obo'
  const oboChatApiUrl = new URL(oboChatApiBase)
  const oboChatPath = oboChatApiUrl.pathname

  return {
    plugins: [react()],
    server: {
      port: 3003,
      proxy: {
        '/api/chat': {
          target: chatTarget,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/api\/chat/, chatPath)
        },
        '/api/obo_chat': {
          target: chatTarget,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/api\/obo_chat/, oboChatPath)
        }
      }
    }
  }
})
