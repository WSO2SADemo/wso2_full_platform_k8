import ballerina/ai;
import ballerinax/ai.mistral;
import ballerinax/ai.openai;
import ballerinax/ai.pinecone;

final AiInsuranceAgentMcpbasetoolkit aiInsuranceAgentMcpbasetoolkit = check new (insuranceagentmcpURL,
    auth = {
        baseAuthUrl: mcpServerTokenURL,
        clientId: agentAppClientId,
        redirectUri: redirectUri,
        isPkceEnabled: true,
        scopes: ["ordinary_employee_agent_scope", "privilege_employee_agent_scope"],
        secureSocket: {cert: {path: truststorePath, password: truststorePassword}}
    },
    secureSocket = {cert: {path: truststorePath, password: truststorePassword}, verifyHostName: false}
);

final AiInsuraceCustomerMcpbasetoolkit aiInsuraceCustomerMcpbasetoolkit = check new (insurancecustomermcpURL,
    auth = {
        baseAuthUrl: mcpServerTokenURL,
        clientId: agentAppClientId,
        clientSecret: agentAppClientSecret,
        redirectUri: redirectUri,
        isPkceEnabled: true,
        scopes: ["ordinary_customer_agent_scope", "privilege_customer_agent_scope"],
        secureSocket: {cert: {path: truststorePath, password: truststorePassword}}
        // secureSocket: {cert: "/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/create_deployments/new_keys/wso2carbon.crt"}
    },
    secureSocket = {cert: {path: truststorePath, password: truststorePassword}, verifyHostName: false}
// secureSocket = {cert: "/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/create_deployments/new_keys/wso2carbon.crt", verifyHostName: false}
);
final mistral:ModelProvider mistralModelprovider = check new (mistralAccessToken, "mistral-large-latest", string `${wso2gwURL}`,
    secureSocket = {cert: {path: truststorePath, password: truststorePassword}, verifyHostName: false}
);
final pinecone:VectorStore pineconeVectorstore = check new (string `${pineconeURL}`, string `${pineConeKey}`);

final ai:VectorKnowledgeBase aiVectorknowledgebase = new (pineconeVectorstore, openaiEmbeddingprovider);
final openai:EmbeddingProvider openaiEmbeddingprovider = check new (string `${openAIKey}`, "text-embedding-3-small");
