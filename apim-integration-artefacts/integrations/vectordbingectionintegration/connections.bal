import ballerina/ai;
import ballerinax/ai.openai;
import ballerinax/ai.pinecone;

final pinecone:VectorStore pineconeVectorstore = check new (string `${pineconeUrl}`, string `${pineconeKey}`);
final ai:Wso2EmbeddingProvider aiWso2embeddingprovider = check ai:getDefaultEmbeddingProvider();
final ai:VectorKnowledgeBase aiVectorknowledgebase = new (pineconeVectorstore, openaiEmbeddingprovider);
final ai:TextDataLoader aiTextdataloader = check new ("./resources/HealthGuard-Insurance-Policy.md");
final openai:EmbeddingProvider openaiEmbeddingprovider = check new (string `${openAIKey}`, "text-embedding-3-small");
