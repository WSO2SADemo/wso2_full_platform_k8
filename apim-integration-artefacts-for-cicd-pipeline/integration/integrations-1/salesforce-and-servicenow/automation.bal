import ballerina/log;
import ballerina/io;
import ballerina/ai;
import xlibb/pdfbox;

public function main() returns error? {
    if !enableDocumentIngestion {
        log:printInfo("Document ingestion is disabled. Skipping document processing.");
        return;
    }
    
    log:printInfo("Document ingestion is enabled. Processing documents...");
    
    do {
        string policyPdfPath =  "./policies/policy.pdf";
        string metadataJsonPath =  "./policies/metadata.json";

        string[] returnPolicyPages = check pdfbox:toTextFromFile(policyPdfPath);
        json metadataResult = check io:fileReadJson(metadataJsonPath);

        string returnPolicy = "";
        foreach string item in returnPolicyPages {
            returnPolicy = returnPolicy + item;
        }

        ai:Metadata metadata = check metadataResult.cloneWithType();
        
        ai:TextDocument document = {
            content: returnPolicy,
            metadata: metadata
        };
        
        ai:Chunk[] chunkDocumentRecursively = check ai:chunkDocumentRecursively(document);
        check aiVectorknowledgebase.ingest(chunkDocumentRecursively);
    } on fail error e {
        log:printError("Error occurred while ingesting document chunks", 'error = e);
        return e;
    }
}
