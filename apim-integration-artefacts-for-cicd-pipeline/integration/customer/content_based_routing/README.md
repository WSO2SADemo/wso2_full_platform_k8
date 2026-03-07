# Content-Based Routing – SOAP Integration

## Overview

Sweden's unemployment insurance funds distribute information from a **sender** to one or more **recipients**. Sender and recipient are unknown to each other — their connections are only to the integration platform.

This integration:
1. Exposes a **SOAP/XML endpoint** over HTTP
2. **Validates** the incoming XML body against an XSD schema
3. **Routes** the message to the correct public SOAP service based on content in the SOAP Header (`senderName`) and Body (`benefitAmount`)
4. Returns a **SOAP acknowledgement** to the caller

---

## Architecture

```
                            ┌─────────────────────────────────────────────────────┐
                            │         content-based-routing (port 9095)           │
                            │                                                     │
  Sender (AFA / Alfa /      │  1. Extract senderName from SOAP Header             │
  Folksam / unknown)  ───▶  │  2. XSD validate BenefitNotification body          │
  POST /soap/routing        │  3. Route based on senderName                       │
                            │  4. If amount > 50 000 SEK → also store-and-forward │
                            └──────────────┬──────────────────────────────┬───────┘
                                           │                              │
                     ┌─────────────────────┼──────────────┐              │ (high-value only)
                     │                     │              │               │
              senderName=AFA        senderName=Alfa  senderName=Folksam  ▼
                     │                     │              │  store-and-forward-integration
                     ▼                     ▼              ▼  (RabbitMQ – durable delivery)
          DNE Calculator         DataAccess           DataAccess
          (Add operation)        NumberToWords        NumberToWords
          dneonline.com          dataaccess.com       dataaccess.com
```

---

## Recipient SOAP Services

| Sender | ConfigMap Variable | SOAP Service | Operation |
|---|---|---|---|
| `AFA` | `afaRecipientUrl` | DNE Online Calculator | `Add` (benefitAmount as `intA`) |
| `Alfa` | `alfaRecipientUrl` | DataAccess NumberToWords | `NumberToWords` (benefitAmount) |
| `Folksam` | `folksamRecipientUrl` | DataAccess NumberToWords | `NumberToWords` (benefitAmount) |
| *(default)* | `defaultRecipientUrl` | DNE Online Calculator | `Add` (benefitAmount as `intA`) |

**Additional high-value routing:**

| Condition | Also routed to | ConfigMap Variable |
|---|---|---|
| `benefitAmount > 50 000` | Internal store-and-forward (RabbitMQ) | `highValueUrl` |

---

## Routing Table

| SOAP Header `senderName` | Recipient | Outbound SOAP Service |
|---|---|---|
| `AFA` | AFA-Fund-A | `afaRecipientUrl` → DNE Calculator (`Add`) |
| `Alfa` | Alfa-Fund-B | `alfaRecipientUrl` → DataAccess NumberToWords |
| `Folksam` | Folksam-Fund-C | `folksamRecipientUrl` → DataAccess NumberToWords |
| *(anything else)* | Default | `defaultRecipientUrl` → DNE Calculator (`Add`) |

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

### XSD-validated fields (all required except `message`)

| Field | XSD type | Notes |
|---|---|---|
| `personalNumber` | `xs:string` | Swedish personal number |
| `benefitAmount` | `xs:decimal` | Triggers high-value routing if > 50 000 |
| `benefitType` | `xs:string` | e.g. `STANDARD`, `PARTIAL` |
| `periodStart` | `xs:date` | ISO date `YYYY-MM-DD` |
| `periodEnd` | `xs:date` | ISO date `YYYY-MM-DD` |
| `message` | `xs:string` | Optional free-text |

### Success Response

```xml
HTTP/1.1 200 OK
Content-Type: text/xml

<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <DistributionAcknowledgement>
      <status>ACCEPTED</status>
      <correlationId>a1b2c3d4-...</correlationId>
      <routedTo>AFA-Fund-A</routedTo>
      <message>Message validated and distributed successfully</message>
    </DistributionAcknowledgement>
  </soap:Body>
</soap:Envelope>
```

### Validation Failure Response (HTTP 400)

```xml
HTTP/1.1 400 Bad Request
Content-Type: text/xml

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
> Then use `http://localhost:9095` as base URL.

---

### 1. AFA sender – standard amount (routes to DNE Calculator)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
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
</soap:Envelope>'
```

**Expected:** Routed to `AFA-Fund-A` via DNE Calculator (Add 35000+0). ACK: `routedTo=AFA-Fund-A`.

---

### 2. AFA sender – HIGH-VALUE amount (routes to DNE Calculator + store-and-forward)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>AFA</un:senderName>
      <un:senderId>AFA-002</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>197003151234</un:personalNumber>
      <un:benefitAmount>75000.00</un:benefitAmount>
      <un:benefitType>INCOME_RELATED</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-06-30</un:periodEnd>
      <un:message>High-value benefit – income-related compensation</un:message>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** Routed to `AFA-Fund-A` (DNE Calculator) + **also** queued in store-and-forward (RabbitMQ). ACK contains `[HIGH-VALUE: also sent to store-and-forward]`.

---

### 3. Alfa sender (routes to DataAccess NumberToWords)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>Alfa</un:senderName>
      <un:senderId>ALFA-SE-007</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>199204221234</un:personalNumber>
      <un:benefitAmount>22000.00</un:benefitAmount>
      <un:benefitType>PARTIAL</un:benefitType>
      <un:periodStart>2026-02-01</un:periodStart>
      <un:periodEnd>2026-04-30</un:periodEnd>
      <un:message>Partial benefit notification</un:message>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** Routed to `Alfa-Fund-B` via DataAccess NumberToWords (22000 → "twenty two thousand"). ACK: `routedTo=Alfa-Fund-B`.

---

### 4. Folksam sender (routes to DataAccess NumberToWords)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>Folksam</un:senderName>
      <un:senderId>FOLKSAM-SE-003</un:senderId>
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

**Expected:** Routed to `Folksam-Fund-C` via DataAccess NumberToWords. ACK: `routedTo=Folksam-Fund-C`.

---

### 5. Unknown sender (default routing → DNE Calculator)

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
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

**Expected:** Routed to `Default-Recipient (sender=UnknownFund)` via DNE Calculator.

---

### 6. XSD validation failure – missing required field

```bash
curl -s -X POST http://localhost:9095/soap/routing \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
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
      <!-- benefitAmount missing – required by XSD -->
      <un:benefitType>STANDARD</un:benefitType>
      <un:periodStart>2026-01-01</un:periodStart>
      <un:periodEnd>2026-03-31</un:periodEnd>
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>'
```

**Expected:** HTTP 400 with `<soap:Fault>` — `XSD validation failed`.

---

### 7. Health check

```bash
curl http://localhost:9095/soap/health
```

---
