import ballerina/ai;

final ai:Wso2ModelProvider insurance_agentModel = check new (serviceUrl = wso2ServiceUrl, accessToken = wso2AccessToken);
final AiInsuranceAgentMcpbasetoolkit aiInsuranceAgentMcpbasetoolkit = check new ("https://gw-wso2am-universal-gw-service.apim-gw.svc.cluster.local::8245/insuranceagantmcp/1.0.0/mcp",
    auth = {
        tokenUrl: mcpServerTokenURL,
        clientId: mcpServerClientId,
        clientSecret: mcpServerClientSecret,
        clientConfig: {
            secureSocket: {
                cert: {
                    path: truststorePath,
                    password: truststorePassword
                }
            }
        }
    },
    secureSocket = {
        key: {
            certFile: keystorePath,
            keyFile: keystorePath,
            keyPassword: keystorePassword
        },
        cert: {
            path: truststorePath,
            password: truststorePassword
        }
    }
);
final AiInsuraceCustomerMcpbasetoolkit aiInsuraceCustomerMcpbasetoolkit = check new ("https://gw-wso2am-universal-gw-service.apim-gw.svc.cluster.local::8245/insurancecustomermcp/1.0.0/mcp",
    auth = {
        tokenUrl: mcpServerTokenURL,
        clientId: mcpServerClientId,
        clientSecret: mcpServerClientSecret,
        clientConfig: {
            secureSocket: {
                cert: {
                    path: truststorePath,
                    password: truststorePassword
                }
            }
        }
    },
    secureSocket = {
        key: {
            certFile: keystorePath,
            keyFile: keystorePath,
            keyPassword: keystorePassword
        },
        cert: {
            path: truststorePath,
            password: truststorePassword
        }
    }
);
