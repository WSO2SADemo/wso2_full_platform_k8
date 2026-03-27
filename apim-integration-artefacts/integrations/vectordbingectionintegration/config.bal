import ballerina/os;
configurable string pineConeKey = os:getEnv("pineConeKey");
configurable string pineconeURL = os:getEnv("pineconeURL");
configurable string openAIKey = os:getEnv("openAIKey");