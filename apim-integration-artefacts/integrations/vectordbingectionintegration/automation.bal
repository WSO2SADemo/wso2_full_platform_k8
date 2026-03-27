import ballerina/ai;
import ballerina/log;

public function main() returns error? {
    do {
        ai:Document[]|ai:Document aiDocumentAiDocument = check aiTextdataloader.load();
        check aiVectorknowledgebase.ingest(aiDocumentAiDocument);
    } on fail error e {
        log:printError("Error occurred", 'error = e);
        return e;
    }
}
