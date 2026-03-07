// ============================================================================
// Content-Based Routing – SOAP Integration
//
// Scenario: Sweden unemployment fund information distribution
//   1. Receives a SOAP/XML notification from a sender (unemployment fund)
//   2. Validates the SOAP body against an XSD schema
//   3. Extracts senderName from the SOAP Header and benefitAmount from Body
//   4. Routes to the correct recipient based on senderName
//   5. If benefitAmount exceeds threshold, ALSO routes to high-value recipient
//      (store-and-forward service for durable delivery)
//   6. Returns a SOAP acknowledgement to the caller
//
// Routing table:
//   senderName = "AFA"     → fundAClient  (Fund11 – toggleable receiver)
//   senderName = "Alfa"    → fundBClient  (notification mock)
//   senderName = "Folksam" → fundCClient  (notification mock)
//   default                → defaultClient
//   benefitAmount > threshold → ALSO highValueClient (store-and-forward)
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
import ballerina/time;
import ballerinax/moesif as _;


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
//   afaClient        → DNE Online Calculator SOAP  (dneonline.com/calculator.asmx)
//   alfaClient       → DataAccess NumberToWords    (dataaccess.com/numberconversion.wso)
//   folksamClient    → DataAccess NumberToWords    (dataaccess.com/numberconversion.wso)
//   defaultClient    → DNE Online Calculator SOAP  (dneonline.com/calculator.asmx)
//   highValueClient  → Store-and-forward service   (store-and-forward-integration:9085)
// ============================================================================
final http:Client afaClient = check new (afaRecipientUrl);
final http:Client alfaClient = check new (alfaRecipientUrl);
final http:Client folksamClient = check new (folksamRecipientUrl);
final http:Client defaultClient = check new (defaultRecipientUrl);
final http:Client highValueClient = check new (highValueUrl);

// Parsed high-value threshold (set from highValueThresholdStr during init)
decimal highValueThreshold = 50000d;

listener http:Listener soapRoutingListener = check new (9095);

function init() returns error? {
    // Parse high-value threshold from config string
    decimal|error threshold = decimal:fromString(highValueThresholdStr);
    if threshold is decimal {
        highValueThreshold = threshold;
    } else {
        log:printWarn("Could not parse highValueThresholdStr, using default 50000");
    }

    // Write embedded XSD to /tmp so xmldata:validate() can reference it
    check io:fileWriteString(XSD_PATH, XSD_CONTENT);

    log:printInfo("Content-Based Routing SOAP service starting on port 9095");
    log:printInfo("XSD schema written to: " + XSD_PATH);
    log:printInfo("High-value threshold: " + highValueThreshold.toString());
    log:printInfo("AFA recipient (Calculator):        " + afaRecipientUrl);
    log:printInfo("Alfa recipient (NumberToWords):    " + alfaRecipientUrl);
    log:printInfo("Folksam recipient (NumberToWords): " + folksamRecipientUrl);
    log:printInfo("Default recipient (Calculator):    " + defaultRecipientUrl);
    log:printInfo("High-value (store-and-forward):    " + highValueUrl);
}

// ============================================================================
// SOAP Routing Service
// ============================================================================
service /soap on soapRoutingListener {

    // POST /soap/routing
    // Receives a SOAP envelope, validates, routes, returns SOAP ACK
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
        //   Primary route: senderName
        //   Additional:    benefitAmount > highValueThreshold
        // ----------------------------------------------------------------
        RoutingDecision decision = determineRoute(senderName, benefitAmount);
        log:printInfo(string `[${correlationId}] Routing to: ${decision.recipientName}  isHighValue=${decision.isHighValue}`);

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
            routedTo: decision.recipientName
        };

        // ----------------------------------------------------------------
        // Step 7: Forward to primary recipient
        // ----------------------------------------------------------------
        boolean primaryRouted = forwardNotification(decision.recipientName, forwardPayload, correlationId);

        // ----------------------------------------------------------------
        // Step 8: High-value – also forward to store-and-forward service
        // for durable delivery guarantee
        // ----------------------------------------------------------------
        if decision.isHighValue {
            log:printInfo(string `[${correlationId}] HIGH-VALUE: also routing to store-and-forward (${highValueUrl})`);
            _ = forwardHighValue(forwardPayload, correlationId);
        }

        log:printInfo(string `[${correlationId}] === CONTENT-BASED ROUTING END ===`);

        // ----------------------------------------------------------------
        // Step 9: Return SOAP acknowledgement to caller
        // ----------------------------------------------------------------
        return createSoapAck(
            correlationId = correlationId,
            accepted = primaryRouted,
            routedTo = decision.recipientName,
            isHighValue = decision.isHighValue
        );
    }

    resource function get health() returns string {
        return "Content-Based Routing Service is running on port 9095";
    }
}

// ============================================================================
// Routing decision function
// Maps senderName + amount to a recipient
// ============================================================================
function determineRoute(string senderName, decimal benefitAmount) returns RoutingDecision {
    boolean isHighValue = benefitAmount > highValueThreshold;

    string recipientName;
    match senderName {
        "AFA" => {
            recipientName = "AFA-Fund-A";
        }
        "Alfa" => {
            recipientName = "Alfa-Fund-B";
        }
        "Folksam" => {
            recipientName = "Folksam-Fund-C";
        }
        _ => {
            recipientName = string `Default-Recipient (sender=${senderName})`;
        }
    }

    return {
        recipientName: recipientName,
        isHighValue: isHighValue
    };
}

// ============================================================================
// Forward notification to primary recipient via SOAP
// Routes to a public SOAP service based on recipientName:
//   AFA-Fund-A    → DNE Calculator (Add)      – fundAUrl
//   Alfa-Fund-B   → DataAccess NumberToWords  – fundBUrl
//   Folksam-Fund-C→ DataAccess NumberToWords  – fundCUrl
//   default       → DNE Calculator (Add)      – defaultRecipientUrl
// Returns true on HTTP 2xx from recipient
// ============================================================================
function forwardNotification(string recipientName, NotificationForwardPayload payload, string correlationId) returns boolean {

    http:Client recipientClient;
    xml soapEnvelope;
    string soapAction;

    match recipientName {
        "AFA-Fund-A" => {
            recipientClient = afaClient;
            soapEnvelope = buildCalculatorSoap(payload);
            soapAction = "http://tempuri.org/Add";
        }
        "Alfa-Fund-B" => {
            recipientClient = alfaClient;
            soapEnvelope = buildNumberToWordsSoap(payload);
            soapAction = "";
        }
        "Folksam-Fund-C" => {
            recipientClient = folksamClient;
            soapEnvelope = buildNumberToWordsSoap(payload);
            soapAction = "";
        }
        _ => {
            recipientClient = defaultClient;
            soapEnvelope = buildCalculatorSoap(payload);
            soapAction = "http://tempuri.org/Add";
        }
    }

    http:Request req = new;
    req.setXmlPayload(soapEnvelope);
    req.setHeader("Content-Type", "text/xml;charset=UTF-8");
    if soapAction != "" {
        req.setHeader("SOAPAction", "\"" + soapAction + "\"");
    }

    http:Response|http:ClientError result = recipientClient->post("", req);
    if result is http:ClientError {
        log:printError(string `[${correlationId}] Failed to forward to ${recipientName}: ${result.message()}`);
        return false;
    }

    log:printInfo(string `[${correlationId}] Forwarded to ${recipientName} – HTTP ${result.statusCode}`);
    return result.statusCode < 400;
}

// ============================================================================
// SOAP envelope builders for public recipient services
// ============================================================================

// DNE Online Calculator – Add operation
// Sends benefitAmount as intA, intB=0; recipient echoes the validated amount.
// Used for: AFA-Fund-A, default
// Endpoint: http://www.dneonline.com/calculator.asmx
function buildCalculatorSoap(NotificationForwardPayload payload) returns xml {
    int amount = <int>payload.benefitAmount;
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

// DataAccess NumberToWords – converts benefitAmount to its English word form.
// Used for: Alfa-Fund-B, Folksam-Fund-C
// Endpoint: https://www.dataaccess.com/webservicesserver/numberconversion.wso
function buildNumberToWordsSoap(NotificationForwardPayload payload) returns xml {
    int amount = <int>payload.benefitAmount;
    return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="https://www.dataaccess.com/webservicesserver/">
      <ubiNum>${amount}</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>`;
}

// ============================================================================
// Forward high-value notification to store-and-forward service
// Wraps in StoreForwardMessage for durable delivery
// ============================================================================
function forwardHighValue(NotificationForwardPayload payload, string correlationId) returns boolean {

    time:Utc now = time:utcNow();
    string createdAt = time:utcToString(now);

    StoreForwardMessage sfMessage = {
        messageId: correlationId,
        recipient: string `HIGH-VALUE-AUDIT:${payload.routedTo}`,
        payload: {
            "personalNumber": payload.personalNumber,
            "senderName": payload.senderName,
            "benefitAmount": payload.benefitAmount,
            "benefitType": payload.benefitType,
            "correlationId": correlationId,
            "routedTo": payload.routedTo
        },
        retryCount: 0,
        createdAt: createdAt
    };

    http:Response|http:ClientError result = highValueClient->post("/notifications/send", sfMessage);
    if result is http:ClientError {
        log:printError(string `[${correlationId}] High-value forward failed: ${result.message()}`);
        return false;
    }

    log:printInfo(string `[${correlationId}] High-value forwarded to store-and-forward – HTTP ${result.statusCode}`);
    return true;
}

// ============================================================================
// SOAP response builders
// ============================================================================
function createSoapAck(string correlationId, boolean accepted, string routedTo, boolean isHighValue) returns xml {
    string highValueNote = isHighValue ? " [HIGH-VALUE: also sent to store-and-forward]" : "";
    string status = accepted ? "ACCEPTED" : "FORWARDING_FAILED";
    return xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
            <DistributionAcknowledgement>
                <status>${status}</status>
                <correlationId>${correlationId}</correlationId>
                <routedTo>${routedTo}${highValueNote}</routedTo>
                <message>Message validated and distributed successfully</message>
            </DistributionAcknowledgement>
        </soap:Body>
    </soap:Envelope>`;
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
