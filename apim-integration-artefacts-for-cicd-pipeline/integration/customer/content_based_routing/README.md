# Content-Based Routing – SOAP Integration

## Overview

Sweden's unemployment insurance funds distribute benefit notifications from a **sender** (unemployment fund) to a **recipient** (processing backend). Sender and recipient are unknown to each other — their only connection is through this integration platform.

This integration:
1. Exposes a **SOAP/XML endpoint** on port 9095
2. **Validates** the incoming XML body against an embedded XSD schema
3. **Routes** the message to the correct external SOAP service based on `senderName` (SOAP Header) and `benefitAmount` (SOAP Body)
4. Executes the forwarding through a **pipeline** with built-in failure handling via RabbitMQ
5. Returns a **SOAP acknowledgement** to the caller

---

## Architecture

### Happy Path

```
  Sender Fund
  (AFA / Folksam /         ┌─────────────────────────────────────────────────────────┐
   Skandia / unknown)       │        content-based-routing  (port 9095)               │
                            │                                                         │
  POST /soap/routing  ───▶  │  Step 1: Extract senderName from SOAP Header           │
                            │  Step 2: Extract BenefitNotification from SOAP Body    │
                            │  Step 3: XSD validate BenefitNotification              │
                            │  Step 4: Parse benefitAmount as decimal                │
                            │  Step 5: determineRoute(senderName, benefitAmount)     │
                            │  Step 6: Build NotificationForwardPayload              │
                            │  Step 7: Execute soapRoutingPipeline                   │
                            └──────────────────────┬──────────────────────────────────┘
                                                   │
                                    ┌──────────────▼──────────────┐
                                    │   xlibb/pipeline             │
                                    │   soap-routing-pipeline      │
                                    │                              │
                                    │   [Processor]                │
                                    │   dummyTransformer           │
                                    │   (pass-through)             │
                                    │                              │
                                    │   [Destination]              │
                                    │   forwardNotification        │
                                    └──────────────┬───────────────┘
                                                   │
              ┌────────────────────┬───────────────┼──────────────────┬──────────────────┐
              │                    │               │                  │                  │
        senderName=AFA       senderName=AFA  senderName=Folksam  senderName=Folksam  any other /
        any amount           high-value       amount ≤ 50 000     amount > 50 000     Skandia
              │              (future)               │                  │
              ▼                                     ▼                  ▼                 ▼
    DNE Calculator              Oorsprong CountryInfo       DNE Calculator      LearnWebServices
    (Add operation)             CapitalCity SE              (Multiply op)       (SayHello)
    dneonline.com/              webservices.oorsprong.org   dneonline.com/      apps.learnwebservices.com
    calculator.asmx                                         calculator.asmx     /services/hello

    Route: AFA-Fund-A           Route: Folksam-Fund-C       Route: Folksam-HighValue   Route: Default
```

### Routing Decision Table

| `senderName` | `benefitAmount` | Route Key | Backend | SOAP Operation |
|---|---|---|---|---|
| `AFA` | any | `AFA-Fund-A` | DNE Online Calculator | `Add` |
| `Folksam` | ≤ 50 000 | `Folksam-Fund-C` | Oorsprong CountryInfo | `CapitalCity` (SE) |
| `Folksam` | > 50 000 | `Folksam-HighValue` | DNE Online Calculator | `Multiply` |
| `Skandia` | any | `Skandia-Fund-D` | *(none – simulated unavailable)* | — |
| *(any other)* | any | `Default` | LearnWebServices | `SayHello` |

---

### Failure Path (Pipeline Error Handling)

When `forwardNotification` fails (e.g. backend returns error, Skandia simulated failure), the pipeline automatically stores the message in RabbitMQ for retry:

```
  forwardNotification
  destination FAILS
        │
        ▼
  ┌─────────────────────────────────────────┐
  │  xlibb/pipeline failure handler         │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────┐
  │  RabbitMQ                        │
  │  Queue: contentbasedrouting.     │
  │          order-failure           │  ◀─── Failed messages land here
  └──────────────┬───────────────────┘
                 │
        (manual or automated replay)
                 │
                 ▼
  ┌──────────────────────────────────┐
  │  RabbitMQ                        │
  │  Queue: contentbasedrouting.     │
  │          order-replay            │  ◀─── Moved here for re-processing
  └──────────────┬───────────────────┘
                 │
        pipeline replays from here
                 │
          ┌──────┴──────┐
          │  succeeds   │  fails again (max retries)
          │             │
          ▼             ▼
      ACCEPTED    contentbasedrouting.
                  order-deadletter     ◀─── Permanently failed messages
```

---

### Component Map

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Kubernetes namespace: ballerina                                      │
  │                                                                      │
  │  ┌─────────────────────────────────────┐                            │
  │  │  content-based-routing (port 9095)  │                            │
  │  │                                     │                            │
  │  │  main.bal    – HTTP service,        │                            │
  │  │               routing logic,        │                            │
  │  │               SOAP builders         │                            │
  │  │  config.bal  – env var wiring       │                            │
  │  │  clients.bal – RabbitMQ stores,     │                            │
  │  │               pipeline definition   │                            │
  │  │  types.bal   – record types         │                            │
  │  └────────────────┬────────────────────┘                            │
  │                   │                                                  │
  │                   ▼                                                  │
  │  ┌────────────────────────────────┐                                 │
  │  │  RabbitMQ (namespace: ballerina│                                 │
  │  │  contentbasedrouting.order-failure                               │
  │  │  contentbasedrouting.order-replay                                │
  │  │  contentbasedrouting.order-deadletter                            │
  │  └────────────────────────────────┘                                 │
  └──────────────────────────────────────────────────────────────────────┘

  External SOAP backends (public internet):
  ┌──────────────────────────────────────────────────────────────────────┐
  │  dneonline.com/calculator.asmx           – AFA-Fund-A, Folksam-HV   │
  │  webservices.oorsprong.org/...           – Folksam-Fund-C            │
  │  apps.learnwebservices.com/services/hello – Default                  │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## SOAP Message Format

### Request

```xml
POST /soap/routing
Content-Type: text/xml

<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>AFA</un:senderName>
      <un:senderId>AFA-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>198501011234</un:personalNumber>
      <un:benefitAmount>35000.00</un:benefitAmount>
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-03-31</un:periodEnd>
      <un:message>Benefit notification for Q1 2026</un:message>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>
```

### XSD-validated fields

| Field | XSD type | Required |
|---|---|---|
| `personalNumber` | `xs:string` | yes |
| `benefitAmount` | `xs:decimal` | yes |
| `benefitType` | `xs:string` | yes |
| `periodStart` | `xs:date` | yes |
| `periodEnd` | `xs:date` | yes |
| `message` | `xs:string` | no |

### Success Response

```xml
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <DistributionAcknowledgement>
      <status>ACCEPTED</status>
      <correlationId>a1b2c3d4-...</correlationId>
      <routedTo>AFA-Fund-A</routedTo>
      <message>Successfully forwarded to AFA-Fund-A</message>
    </DistributionAcknowledgement>
  </soap:Body>
</soap:Envelope>
```

### Validation / Routing Failure Response (HTTP 400)

```xml
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Client</faultcode>
      <faultstring>XSD validation failed: ...</faultstring>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
```

---

## cURL Commands

> **Local access (port-forward):**
> ```bash
> kubectl port-forward svc/content-based-routing 9095:9095 -n ballerina
> ```

### 1. AFA sender (routes to DNE Calculator – Add)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>AFA</un:senderName>
      <un:senderId>AFA-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>198501011234</un:personalNumber>
      <un:benefitAmount>35000.00</un:benefitAmount>
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-03-31</un:periodEnd>
      <un:message>Standard notification</un:message>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** `routedTo=AFA-Fund-A`, status=ACCEPTED

---

### 2. Folksam sender – low amount (routes to Oorsprong CountryInfo)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>Folksam</un:senderName>
      <un:senderId>FOLKSAM-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>198811051234</un:personalNumber>
      <un:benefitAmount>18500.00</un:benefitAmount>
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-03-01</un:periodStart>
      <un:periodEnd>2026-05-31</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** `routedTo=Folksam-Fund-C`, status=ACCEPTED

---

### 3. Folksam sender – high amount > 50 000 (routes to DNE Calculator – Multiply)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>Folksam</un:senderName>
      <un:senderId>FOLKSAM-002</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>197003151234</un:personalNumber>
      <un:benefitAmount>75000.00</un:benefitAmount>
      <un:benefitType>INCOME_RELATED</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-06-30</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** `routedTo=Folksam-HighValue`, status=ACCEPTED

---

### 4. Skandia sender (simulated unavailable – failure path demo)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>Skandia</un:senderName>
      <un:senderId>SKANDIA-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>199204221234</un:personalNumber>
      <un:benefitAmount>22000.00</un:benefitAmount>
      <un:benefitType>PARTIAL</un:benefitType>
      <un:periodStart>2026-02-01</un:periodStart>
      <un:periodEnd>2026-04-30</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** Pipeline failure → message stored in `contentbasedrouting.order-failure` queue

---

### 5. Unknown sender (default route → LearnWebServices)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>UnknownFund</un:senderName>
      <un:senderId>UNK-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>200101011234</un:personalNumber>
      <un:benefitAmount>12000.00</un:benefitAmount>
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-03-31</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** `routedTo=Default`, status=ACCEPTED

---

### 6. XSD validation failure – missing required field

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>AFA</un:senderName>
      <un:senderId>AFA-001</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>198501011234</un:personalNumber>
      <!-- benefitAmount missing – required by XSD -->
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-03-31</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** HTTP 400 with `<soap:Fault>` — XSD validation failed

---

### 7. Health check

```bash
curl http://localhost:9095/soap/health
```
