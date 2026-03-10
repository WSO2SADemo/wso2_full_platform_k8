export const CFG = {
  clientId:     '94kkgjvcSfF0RuIp_4VqlvUjzQ0a',
  clientSecret: 'PtN9GQfEKqvGrxKVYUoDKoa0PaUa',
  authUrl:      'http://cp.wso2.com/oauth2/authorize',
  tokenUrl:     'https://cp.wso2.com/oauth2/token',

  // Must exactly match the Callback URL registered in the WSO2 APIM application.
  // Check: Dev Portal → Applications → <app> → OAuth2 Keys → Callback URL
  callbackUrl:  'http://localhost:5173',

  // In dev, route gateway calls through /gw-proxy to avoid CORS.
  // In production, call gw.wso2.com directly.
  cbrBase:  import.meta.env.DEV ? '/gw-proxy/content-basedroutingsoapintegration/1.0.0'  : 'https://gw.wso2.com/content-basedroutingsoapintegration/1.0.0',
  sfBase:   import.meta.env.DEV ? '/gw-proxy/store-and-forwardnotification/1.0.2'         : 'https://gw.wso2.com/store-and-forwardnotification/1.0.2',
  mockBase: import.meta.env.DEV ? '/gw-proxy/customernotificationbackendsmock/1.0.0'      : 'https://gw.wso2.com/customernotificationbackendsmock/1.0.0',
  // TODO: update the APIM context path once the parallel orchestration API is published
  psoBase:  import.meta.env.DEV ? '/gw-proxy/unemploymentfundorchestration/1.0.0'        : 'https://gw.wso2.com/unemploymentfundorchestration/1.0.0',
};
