// ============================================================================
// Content-Based Routing – SOAP Integration
//
// Scenario: Sweden unemployment fund information distribution
//   1. Receives a SOAP/XML notification from a sender (unemployment fund)
//   2. Validates the SOAP body against an XSD schema
//   3. Extracts senderName from the SOAP Header and benefitAmount from Body
//   4. Routes to the correct recipient and proxies the response back to caller
//
// Routing table:
//   senderName = "AFA",     any amount           → DNE Calculator Add
//   senderName = "Folksam", amount > threshold   → DNE Calculator Multiply
//   senderName = "Folksam", amount ≤ threshold   → Oorsprong CountryInfo
//   any other sender                             → LearnWebServices Hello
//
// Exposed endpoint:
//   POST http://content-based-routing.ballerina.svc.cluster.local:9095/soap/routing
//
// Sample SOAP request:
//   <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
//                  xmlns:un="http://unemployment.sweden.se/notification">
//     <soap:Header>
//       <un:SenderHeader>
//         <un:senderName>AFA</un:senderName>
//         <un:senderId>AFA-001</un:senderId>
//       </un:SenderHeader>
//     </soap:Header>
//     <soap:Body>
//       <un:BenefitNotification>
//         <un:personalNumber>198501011234</un:personalNumber>
//         <un:benefitAmount>35000.00</un:benefitAmount>
//         <un:benefitType>STANDARD</un:benefitType>
//         <un:periodStart>2026-01-01</un:periodStart>
//         <un:periodEnd>2026-03-31</un:periodEnd>
//         <un:message>Benefit notification for Q1 2026</un:message>
//       </un:BenefitNotification>
//     </soap:Body>
//   </soap:Envelope>
// ============================================================================

import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/data.xmldata;
import ballerina/uuid;
import ballerinax/moesif as _;
// import ballerinax/wso2.controlplane as _;
import ballerinax/wso2.icp as _;
import xlibb/pipeline;


// SOAP and application XML namespaces
xmlns "http://schemas.xmlsoap.org/soap/envelope/" as soap;
xmlns "http://unemployment.sweden.se/notification" as un;

// ============================================================================
// XSD schema embedded as a constant – written to /tmp at startup so
// xmldata:validate() can reference it without filesystem dependencies in K8s.
// ============================================================================
const string XSD_PATH = "/tmp/benefit-notification-schema.xsd";

const string XSD_CONTENT = string `<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
           xmlns:un="http://unemployment.sweden.se/notification"
           targetNamespace="http://unemployment.sweden.se/notification"
           elementFormDefault="qualified">
  <xs:element name="BenefitNotification">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="personalNumber" type="xs:string"/>
        <xs:element name="benefitAmount"  type="xs:decimal"/>
        <xs:element name="benefitType"    type="xs:string"/>
        <xs:element name="periodStart"    type="xs:date"/>
        <xs:element name="periodEnd"      type="xs:date"/>
        <xs:element name="message"        type="xs:string" minOccurs="0"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>`;

// ============================================================================
// Pre-created HTTP clients for routing recipients.
// Base URLs come from ConfigMap via config.bal configurable variables.
//
//   afaClient     → DNE Calculator SOAP        (dneonline.com/calculator.asmx)
//   alfaClient    → LearnWebServices Hello     (apps.learnwebservices.com/services/hello)
//   folksamClient → Oorsprong CountryInfo SOAP (webservices.oorsprong.org)
//   Skandia-Fund-D → short-circuits immediately with ServiceUnavailable (no HTTP call)
// ============================================================================
final http:Client afaClient = check new (afaRecipientUrl);
final http:Client alfaClient = check new (alfaRecipientUrl);
final http:Client folksamClient = check new (folksamRecipientUrl);

// Parsed high-value threshold (set from highValueThresholdStr during init)
decimal highValueThreshold = 50000d;

listener http:Listener soapRoutingListener = check new (9095);

function init() returns error? {
    log:printInfo("=== content_based_routing init() START ===");

    // Log raw env vars before any parsing
    log:printInfo("[ENV] afaRecipientUrl      = '" + afaRecipientUrl + "'");
    log:printInfo("[ENV] alfaRecipientUrl     = '" + alfaRecipientUrl + "'");
    log:printInfo("[ENV] folksamRecipientUrl  = '" + folksamRecipientUrl + "'");
    log:printInfo("[ENV] highValueThresholdStr= '" + highValueThresholdStr + "'");
    log:printInfo("[ENV] rabbitmqHost         = '" + rabbitmqHost + "'");
    log:printInfo("[ENV] rabbitmqPort         = '" + rabbitmqPort.toString() + "'");
    log:printInfo("[ENV] rabbitmqUser         = '" + rabbitmqUser + "'");
    log:printInfo("[ENV] rabbitmqPassword     = '" + (rabbitmqPassword.length() > 0 ? "***set***" : "EMPTY") + "'");

    // Parse high-value threshold from config string
    decimal|error threshold = decimal:fromString(highValueThresholdStr);
    if threshold is decimal {
        highValueThreshold = threshold;
        log:printInfo("[INIT] highValueThreshold parsed OK: " + highValueThreshold.toString());
    } else {
        log:printWarn("[INIT] Could not parse highValueThresholdStr '" + highValueThresholdStr + "', using default 50000. Error: " + threshold.message());
    }

    // Write embedded XSD to /tmp so xmldata:validate() can reference it
    log:printInfo("[INIT] Writing XSD to: " + XSD_PATH);
    check io:fileWriteString(XSD_PATH, XSD_CONTENT);
    log:printInfo("[INIT] XSD written OK");

    log:printInfo("=== content_based_routing init() DONE — listening on port 9095 ===");
}

// ============================================================================
// SOAP Routing Service
// ============================================================================
service /soap on soapRoutingListener {

    // POST /soap/routing
    // Receives a SOAP envelope, validates, routes, proxies recipient response back
    resource function post routing(@http:Payload xml soapRequest)
            returns xml|http:BadRequest|http:InternalServerError {

        string correlationId = uuid:createType1AsString();
        log:printInfo(string `[${correlationId}] === CONTENT-BASED ROUTING START ===`);

        // ----------------------------------------------------------------
        // Step 1: Extract SOAP Header – senderName drives routing decision
        // ----------------------------------------------------------------
        xml soapHeader = soapRequest/<soap:Header>;
        xml senderHeaderEl = soapHeader/<un:SenderHeader>;
        string senderName = (senderHeaderEl/<un:senderName>/*).toString();
        string senderId = (senderHeaderEl/<un:senderId>/*).toString();

        if senderName == "" {
            log:printError(string `[${correlationId}] Missing senderName in SOAP Header`);
            return <http:BadRequest>{
                body: createSoapFault("Missing <un:senderName> in SOAP Header")
            };
        }

        log:printInfo(string `[${correlationId}] Sender: ${senderName} (id=${senderId})`);

        // ----------------------------------------------------------------
        // Step 2: Extract SOAP Body – BenefitNotification element
        // ----------------------------------------------------------------
        xml soapBody = soapRequest/<soap:Body>;
        xml notificationEl = soapBody/<un:BenefitNotification>;

        if notificationEl.length() == 0 {
            log:printError(string `[${correlationId}] Missing BenefitNotification in SOAP Body`);
            return <http:BadRequest>{
                body: createSoapFault("Missing <un:BenefitNotification> element in SOAP Body")
            };
        }

        // ----------------------------------------------------------------
        // Step 3: XSD Validation
        // ----------------------------------------------------------------
        log:printInfo(string `[${correlationId}] Validating against XSD schema`);
        error? xsdResult = xmldata:validate(notificationEl, XSD_PATH);
        if xsdResult is error {
            log:printError(string `[${correlationId}] XSD validation FAILED: ${xsdResult.message()}`);
            return <http:BadRequest>{
                body: createSoapFault(string `XSD validation failed: ${xsdResult.message()}`)
            };
        }
        log:printInfo(string `[${correlationId}] XSD validation PASSED`);

        // ----------------------------------------------------------------
        // Step 4: Extract notification fields from body
        // ----------------------------------------------------------------
        string personalNumber = (notificationEl/<un:personalNumber>/*).toString();
        string benefitAmountStr = (notificationEl/<un:benefitAmount>/*).toString();
        string benefitType = (notificationEl/<un:benefitType>/*).toString();
        string periodStart = (notificationEl/<un:periodStart>/*).toString();
        string periodEnd = (notificationEl/<un:periodEnd>/*).toString();
        string message = (notificationEl/<un:message>/*).toString();

        decimal|error benefitAmount = decimal:fromString(benefitAmountStr);
        if benefitAmount is error {
            log:printError(string `[${correlationId}] Invalid benefitAmount value: ${benefitAmountStr}`);
            return <http:BadRequest>{
                body: createSoapFault(string `Invalid <un:benefitAmount> value: ${benefitAmountStr}`)
            };
        }

        log:printInfo(string `[${correlationId}] personalNumber=${personalNumber} benefitAmount=${benefitAmount} benefitType=${benefitType}`);

        // ----------------------------------------------------------------
        // Step 5: Content-based routing decision
        // ----------------------------------------------------------------
        string recipientName = determineRoute(senderName, benefitAmount);
        log:printInfo(string `[${correlationId}] Routing to: ${recipientName}`);

        // ----------------------------------------------------------------
        // Step 6: Build forward payload
        // ----------------------------------------------------------------
        NotificationForwardPayload forwardPayload = {
            personalNumber: personalNumber,
            senderName: senderName,
            senderId: senderId,
            benefitAmount: benefitAmount,
            benefitType: benefitType,
            periodStart: periodStart,
            periodEnd: periodEnd,
            message: message,
            correlationId: correlationId,
            routedTo: recipientName
        };

        // ----------------------------------------------------------------
        // Step 7: Forward to recipient and proxy response back to caller
        // ----------------------------------------------------------------
        NotificationContext notificationContext = {
            forwardPayload: forwardPayload,
            recipientName: recipientName,
            correlationId: correlationId
        };

        do {
            pipeline:ExecutionSuccess execute = check soapRoutingPipeline.execute(notificationContext);
            NotificationStatusContext notificationStatusContext = check execute.destinationResults["forwardNotification"].cloneWithType();
            
            // Convert status context to SOAP acknowledgement XML
            xml acknowledgement = buildAcknowledgementSoap(
                status = notificationStatusContext.success == "true" ? "ACCEPTED" : "REJECTED",
                correlationId = correlationId,
                routedTo = recipientName,
                message = notificationStatusContext.message
            );
            
            return acknowledgement;
        } on fail error err {
            //1st destination itself failed
            log:printError(string `[${correlationId}] ── ORDER PIPELINE FAILED at Step # – ${err.message()}`);
            return <http:InternalServerError>{body: {
                    'error: string `${err.message()}`,
                    correlationId: correlationId,
                    failedStep: "unknown"
                }};
        }
    }

    resource function get health() returns string {
        return "Content-Based Routing Service is running on port 9095";
    }
}

// ============================================================================
// Routing decision
//   AFA            → AFA-Fund-A         (Calculator Add)
//   Folksam, high  → Folksam-HighValue  (Calculator Multiply)
//   Folksam, low   → Folksam-Fund-C     (CountryInfo)
//   any other      → Default            (LearnWebServices)
// ============================================================================
function determineRoute(string senderName, decimal benefitAmount) returns string {
    match senderName {
        "AFA" => {
            return "AFA-Fund-A";
        }
        "Folksam" => {
            return benefitAmount > highValueThreshold ? "Folksam-HighValue" : "Folksam-Fund-C";
        }
        "Skandia" => {
            return "Skandia-Fund-D";
        }
        _ => {
            return "Default";
        }
    }
}

@pipeline:TransformerConfig {
    id: "dummyTransformer"
}
isolated function dummyTransformer(pipeline:MessageContext ctx) returns NotificationContext|error {
    NotificationContext message = check ctx.getContentWithType();
    return message;
}

// ============================================================================
// Forward notification to recipient via SOAP; proxy XML response back.
//   AFA-Fund-A      → afaClient,     DNE Calculator Add     (text/xml)
//   Folksam-HighValue → afaClient,   DNE Calculator Multiply(text/xml)
//   Folksam-Fund-C  → folksamClient, Oorsprong CountryInfo  (application/soap+xml)
//   Default         → alfaClient,    LearnWebServices Hello (text/xml)
// ============================================================================
@pipeline:DestinationConfig {
    id: "forwardNotification"
}
isolated function forwardNotification(pipeline:MessageContext ctx) returns NotificationStatusContext|error {

    http:Client recipientClient;
    xml soapEnvelope;
    string soapAction;
    string contentType = "text/xml;charset=UTF-8";

    NotificationContext notificationContext = check ctx.getContentWithType();
    string recipientName = notificationContext.recipientName;
    NotificationForwardPayload payload = notificationContext.forwardPayload;
    string correlationId = notificationContext.correlationId;

    match recipientName {
        "AFA-Fund-A" => {
            recipientClient = afaClient;
            soapEnvelope = buildCalculatorSoap(payload, "Add");
            soapAction = "http://tempuri.org/Add";
        }
        "Folksam-HighValue" => {
            recipientClient = afaClient;
            soapEnvelope = buildCalculatorSoap(payload, "Multiply");
            soapAction = "http://tempuri.org/Multiply";
        }
        "Folksam-Fund-C" => {
            recipientClient = folksamClient;
            soapEnvelope = buildCountryInfoSoap();
            soapAction = "";
            contentType = "application/soap+xml;charset=UTF-8";
        }
        "Skandia-Fund-D" => {
            return error(string `simulated Error returned for ${recipientName} to demonstrate failure handling`);
        }
        _ => {
            recipientClient = alfaClient;
            soapEnvelope = buildLearnWebServicesSoap(payload);
            soapAction = "";
        }
    }

    http:Request req = new;
    req.setXmlPayload(soapEnvelope);
    req.setHeader("Content-Type", contentType);
    if soapAction != "" {
        req.setHeader("SOAPAction", "\"" + soapAction + "\"");
    }

    NotificationStatusContext statusContext = {
        success: "true",
        message: ""
    };
    http:Response|http:ClientError result = recipientClient->post("", req);
    if (result is http:ClientError ) {
        log:printError(string `[${correlationId}] Failed to forward to ${recipientName}: ${result.message()}`);
        return error(string `[${correlationId}] Failed to forward to ${recipientName}: ${result.message()} Message replay enabled for this error.`);
    } else if (result.statusCode >= 400) {
        log:printError(string `[${correlationId}] Recipient ${recipientName} returned HTTP ${result.statusCode}`);
        return error(string `[${correlationId}] Recipient returned HTTP ${result.statusCode} Message replay enabled for this error.`);
    } else {
        log:printInfo(string `[${correlationId}] Successfully forwarded to ${recipientName}`);
        statusContext.success = "true";
        statusContext.message = check result.getTextPayload();
    }
    return check statusContext;
}

// ============================================================================
// SOAP envelope builders
// ============================================================================

// DNE Online Calculator – Add or Multiply operation
// Endpoint: http://www.dneonline.com/calculator.asmx
isolated function buildCalculatorSoap(NotificationForwardPayload payload, string operation) returns xml {
    decimal benefitAmount = payload.benefitAmount;
    int amount = <int>benefitAmount;
    if operation == "Multiply" {
        return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                  xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <Multiply xmlns="http://tempuri.org/">
      <intA>${amount}</intA>
      <intB>1</intB>
    </Multiply>
  </soap:Body>
</soap:Envelope>`;
    }
    return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <Add xmlns="http://tempuri.org/">
      <intA>${amount}</intA>
      <intB>0</intB>
    </Add>
  </soap:Body>
</soap:Envelope>`;
}

// LearnWebServices Hello – SayHello operation
// Endpoint: https://apps.learnwebservices.com/services/hello
isolated function buildLearnWebServicesSoap(NotificationForwardPayload payload) returns xml {
    return xml `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Header/>
  <soapenv:Body>
    <HelloRequest xmlns="http://learnwebservices.com/services/hello">
      <Name>${payload.senderName}</Name>
    </HelloRequest>
  </soapenv:Body>
</soapenv:Envelope>`;
}

// Oorsprong CountryInfo – CapitalCity operation (SOAP 1.2)
// Endpoint: http://webservices.oorsprong.org/websamples.countryinfo/CountryInfoService.wso
isolated function buildCountryInfoSoap() returns xml {
    return xml `<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <CapitalCity xmlns="http://www.oorsprong.org/websamples.countryinfo">
      <sCountryISOCode>SE</sCountryISOCode>
    </CapitalCity>
  </soap12:Body>
</soap12:Envelope>`;
}

function createSoapFault(string faultString) returns xml {
    return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
            <soap:Fault>
                <faultcode>soap:Client</faultcode>
                <faultstring>${faultString}</faultstring>
            </soap:Fault>
        </soap:Body>
    </soap:Envelope>`;
}

// Build SOAP acknowledgement response
isolated function buildAcknowledgementSoap(string status, string correlationId, string routedTo, string message) returns xml {
    return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <DistributionAcknowledgement>
      <status>${status}</status>
      <correlationId>${correlationId}</correlationId>
      <routedTo>${routedTo}</routedTo>
      <message>${message}</message>
    </DistributionAcknowledgement>
  </soap:Body>
</soap:Envelope>`;
}
