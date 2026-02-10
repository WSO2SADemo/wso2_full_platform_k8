import ballerina/http;

// HTTP listener for receiving SAP-MDM requests
listener http:Listener sapMdmListener = new (servicePort);

// HTTP client for VIES SOAP service
final http:Client viesClient = check new (viesServiceUrl, {timeout: 30});
