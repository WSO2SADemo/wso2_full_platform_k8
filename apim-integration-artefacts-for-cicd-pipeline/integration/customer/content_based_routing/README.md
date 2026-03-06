# Content-Based Routing – SOAP Integration

## Overview

Sweden's unemployment insurance funds distribute information from a **sender** to one or more **recipients**. Sender and recipient are unknown to each other — their connections are only to the integration platform.

This integration:
1. Exposes a **SOAP/XML endpoint** over HTTP
2. **Validates** the incoming XML body against an XSD schema
3. **Routes** the message to the correct fund recipient based on content in the SOAP Header (`senderName`) and Body (`benefitAmount`)
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
                            └──────────────┬────────────────────────────────┬──────┘
                                           │                                │
                     ┌─────────────────────┼──────────────┐                │ (high-value only)
                     │                     │              │                 │
              senderName=AFA        senderName=Alfa  senderName=Folksam    ▼
                     │                     │              │    store-and-forward-integration
                     ▼                     ▼              ▼    (RabbitMQ – durable delivery)
          Fund11 receiver        mock-backends     mock-backends
          (toggleable online/    /notification/    /notification/
           offline – resilience) servicecall       servicecall
          port 9101              port 9096          port 9096
```

---

## Routing Table

| SOAP Header `senderName` | Recipient | Backend URL |
|---|---|---|
| `AFA` | AFA-Fund-A | `service-ochastration-backends:9101/notifications` |
| `Alfa` | Alfa-Fund-B | `mock-backends:9096/notification/servicecall` |
| `Folksam` | Folksam-Fund-C | `mock-backends:9096/notification/servicecall` |
| *(anything else)* | Default | `mock-backends:9096/notification/servicecall` |

**Additional routing (content-based):**

| Condition | Also routed to |
|---|---|
| `benefitAmount > 50 000` | `store-and-forward-integration:9085/notifications/send` (RabbitMQ-backed, retry on failure) |

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

### 1. AFA sender – standard amount (routes to Fund11)

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

**Expected:** Routed to `AFA-Fund-A` (Fund11, port 9101). `routedTo=AFA-Fund-A` in ACK.

---

### 2. AFA sender – HIGH-VALUE amount (routes to Fund11 + store-and-forward)

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

**Expected:** Routed to `AFA-Fund-A` + **also** queued in store-and-forward (RabbitMQ). ACK contains `[HIGH-VALUE: also sent to store-and-forward]`.

---

### 3. Alfa sender (routes to notification mock backend)

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

**Expected:** Routed to `Alfa-Fund-B` (notification mock, port 9096). `routedTo=Alfa-Fund-B`.

---

### 4. Folksam sender (routes to notification mock backend)

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

**Expected:** Routed to `Folksam-Fund-C`.

---

### 5. Unknown sender (default routing)

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

**Expected:** Routed to `Default-Recipient (sender=UnknownFund)`.

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

### 7. Resilience demo – toggle Fund11 offline then retry AFA

```bash
# 1. Toggle Fund11 (AFA recipient) offline
curl -X POST http://localhost:9101/notifications/admin/toggle

# 2. Check status
curl http://localhost:9101/notifications/admin/status

# 3. Send AFA notification – Fund11 is offline, forward will fail
#    (use cURL from scenario 1 above)

# 4. Toggle Fund11 back online
curl -X POST http://localhost:9101/notifications/admin/toggle
```

> Note: For port 9101, port-forward `svc/service-ochastration-backends` on port 9101.

---

### 8. Health check

```bash
curl http://localhost:9095/soap/health
```

---

