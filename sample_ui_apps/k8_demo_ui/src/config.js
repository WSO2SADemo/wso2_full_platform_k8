const config = {
  // Auth
  isBaseUrl:      import.meta.env.VITE_IS_BASE_URL      || 'https://is.wso2.com',
  isClientId:     import.meta.env.VITE_IS_CLIENT_ID     || 'wQ0k7VuhwKxaO5Y68fTcffFd9u8a',
  isClientSecret: import.meta.env.VITE_IS_CLIENT_SECRET || 'qHJy4bqtYkaw0R4K36oGm3z1CTwaJ5TsxMyLJZK49MIa',

  // Gateway base URLs — routed through Vite dev proxy to avoid CORS
  apimBase:      '/api/devportal',
  wso2K8Base:    '/proxy/wso2k8',
  envoyBase:     '/proxy/envoy',
  universalBase: '/proxy/universal',
  azureBase:     '/proxy/azure',

  // Azure APIM Client Credentials
  azureTenantId:       import.meta.env.VITE_AZURE_TENANT_ID       || '',
  azureClientId:       import.meta.env.VITE_AZURE_CLIENT_ID       || '',
  azureClientSecret:   import.meta.env.VITE_AZURE_CLIENT_SECRET   || '',
  azureScope:          import.meta.env.VITE_AZURE_SCOPE           || '',

  // Azure APIM Subscription Key
  azureSubscriptionKey: import.meta.env.VITE_AZURE_SUBSCRIPTION_KEY || '',
};

export default config;
