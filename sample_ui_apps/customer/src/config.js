export const CFG = {
  clientId:     'fY4gowtuQ0DKv01Uf8wQb0_0gOga',
  clientSecret: 'tuCh3w2bCTDy1fCLRlmw3o2BiPca',
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
  psoBase:  import.meta.env.DEV ? '/gw-proxy/unemploymentfundorchestrationapi/1.0.0'      : 'https://gw.wso2.com/unemploymentfundorchestrationapi/1.0.0',

  // Order Pipeline – Service Orchestration (error_handling_integration, port 9086)
  opBase:          import.meta.env.DEV ? '/gw-proxy/purchaseserviceorchestrationpipeline/1.0.0'    : 'https://gw.wso2.com/purchaseserviceorchestrationpipeline/1.0.0',
  // Order Pipeline – individual mock backend APIs (one APIM API per service)
  opCustomerBase:  import.meta.env.DEV ? '/gw-proxy/customerprofileservice/1.0.0'                  : 'https://gw.wso2.com/customerprofileservice/1.0.0',
  opPricingBase:   import.meta.env.DEV ? '/gw-proxy/pricingservice/1.0.0'                          : 'https://gw.wso2.com/pricingservice/1.0.0',
  opPurchaseBase:  import.meta.env.DEV ? '/gw-proxy/purchaseservice/1.0.0'                         : 'https://gw.wso2.com/purchaseservice/1.0.0',

  // RabbitMQ Management API – ingress at rabbitmq.wso2.com (must be in /etc/hosts)
  // Dev: proxied via Vite to avoid CORS. Prod: direct in-cluster URL.
  rmqBase: import.meta.env.DEV ? '/rmq-proxy' : 'http://rabbitmq.wso2.com',
  rmqUser: 'wso2-rmq-admin',
  rmqPass: 'R@bbitMQ#W$O2!2024Secure',
};
