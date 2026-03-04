import ballerina/ai;

final ai:Wso2ModelProvider insurance_agentModel = check new (serviceUrl = wso2ServiceUrl, accessToken = wso2AccessToken);
final AiInsuranceAgentMcpbasetoolkit aiInsuranceAgentMcpbasetoolkit = check new (insuranceagentmcpURL,
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
final AiInsuraceCustomerMcpbasetoolkit aiInsuraceCustomerMcpbasetoolkit = check new (insurancecustomermcpURL,
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
