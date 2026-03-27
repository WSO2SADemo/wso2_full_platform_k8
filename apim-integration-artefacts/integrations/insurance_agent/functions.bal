import ballerina/ai;

isolated function queryVectorDBInformation(string query) returns string|error {
    ai:QueryMatch[] aiQuerymatch = check aiVectorknowledgebase.retrieve(string `${query}`);
    ai:ChatUserMessage aiChatusermessage = ai:augmentUserQuery(aiQuerymatch, string `${query}`);
    ai:ChatAssistantMessage aiChatassistantmessage = check mistralModelprovider->chat(aiChatusermessage, []);
    return aiChatassistantmessage.content.ensureType();
}
