# Orchestration Service API Documentation

## Overview

The Orchestration Service provides a unified API for coordinating benefit registration between the Cash Registry and OAS (Online Application System) services. This service handles the complete workflow of calculating unemployment benefits, registering them in the OAS system, and verifying the registration.

**Base URL:** `http://<host>:9090/api`

---

## Endpoints

### POST /benefits/register

Orchestrates the complete benefit registration process including calculation, registration, and verification.

#### Request

**Content-Type:** `application/json`

**Request Body:**

```json
{
  "personalNumber": "string",
  "kassaName": "string",
  "previousMonthlySalary": "decimal",
  "workCertificates": ["string"]
}
```

**Field Descriptions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `personalNumber` | string | Yes | Personal identification number of the applicant |
| `kassaName` | string | Yes | Name of the unemployment insurance fund (kassa) |
| `previousMonthlySalary` | decimal | Yes | Previous monthly salary in SEK |
| `workCertificates` | string[] | Yes | Array of work certificate identifiers or URLs |

#### Response

**Success Response (200 OK):**

```json
{
  "success": true,
  "message": "Benefit successfully calculated and registered",
  "calculation": {
    "approved": true,
    "dailyAllowance": "decimal",
    "incomeBase": "string",
    "totalDays": "integer",
    "message": "string"
  },
  "registration": {
    "success": true,
    "message": "string",
    "registrationId": "string"
  },
  "finalBenefit": {
    "personalNumber": "string",
    "kassaName": "string",
    "isMember": true,
    "dailyAllowance": "decimal",
    "incomeBase": "string",
    "remainingDays": "integer",
    "registrationDate": "string",
    "lastUpdated": "string"
  }
}
```

**Error Response - Application Not Approved (400 Bad Request):**

```json
{
  "success": false,
  "message": "string",
  "calculation": {
    "approved": false,
    "dailyAllowance": "decimal",
    "incomeBase": "string",
    "totalDays": "integer",
    "message": "string"
  },
  "registration": null,
  "finalBenefit": null
}
```

**Error Response - Internal Server Error (500):**

```json
{
  "success": false,
  "message": "string",
  "calculation": null,
  "registration": null,
  "finalBenefit": null
}
```

**Possible error messages:**
- `"Failed to calculate benefit at Cash Registry"`
- `"Failed to register benefit in OAS"`
- `"Failed to verify registration in OAS"`

---

## Data Models

### OrchestrationRequest
```ballerina
record {|
    string personalNumber;
    string kassaName;
    decimal previousMonthlySalary;
    string[] workCertificates;
|}
```

### OrchestrationResponse
```ballerina
record {|
    boolean success;
    string message;
    BenefitCalculationResponse? calculation;
    RegistrationResponse? registration;
    MemberBenefit? finalBenefit;
|}
```

### BenefitCalculationResponse
```ballerina
record {|
    boolean approved;           // Whether the application was approved
    decimal dailyAllowance;     // Calculated daily allowance in SEK
    string incomeBase;          // Income base used for calculation
    int totalDays;              // Total days of benefit eligibility
    string message;             // Status or rejection message
|}
```

### RegistrationResponse
```ballerina
record {|
    boolean success;            // Registration success status
    string message;             // Registration status message
    string registrationId?;     // Optional registration ID
|}
```

### MemberBenefit
```ballerina
record {|
    string personalNumber;      // Member's personal number
    string kassaName;           // Unemployment fund name
    boolean isMember;           // Active membership status
    decimal dailyAllowance;     // Daily benefit amount in SEK
    string incomeBase;          // Income base classification
    int remainingDays;          // Remaining benefit days
    string registrationDate;    // Registration timestamp
    string lastUpdated;         // Last update timestamp
|}
```

---

## Workflow

The orchestration service executes the following three-step workflow:

1. **Benefit Calculation** - Submits application to Cash Registry service at `POST /applications`
2. **OAS Registration** - Registers approved benefits to Cash Registry at `POST /register/{personalNumber}` with kassa name
3. **Verification** - Verifies registration by looking up member in OAS at `GET /members/{personalNumber}`

---

## Configuration

The service requires the following environment variables:

| Variable | Description |
|----------|-------------|
| `cashRegistryUrl` | Base URL for the Cash Registry service |
| `oasUrl` | Base URL for the OAS service |

---

## Error Handling

The service implements comprehensive error handling at each step:

- **Calculation Failure**: Returns 500 Internal Server Error with calculation error details
- **Not Approved**: Returns 400 Bad Request with rejection reason
- **Registration Failure**: Returns 500 Internal Server Error with partial success data
- **Verification Failure**: Returns 500 Internal Server Error with calculation and registration data

All errors are logged with detailed information for debugging purposes.

---

## Example Usage

### Successful Registration Request

```bash
curl -X POST http://localhost:9090/api/benefits/register \
  -H "Content-Type: application/json" \
  -d '{
    "personalNumber": "199001011234",
    "kassaName": "Akademikernas erkända arbetslöshetskassa",
    "previousMonthlySalary": 35000,
    "workCertificates": ["cert-12345", "cert-67890"]
  }'
```

### Successful Response

```json
{
  "success": true,
  "message": "Benefit successfully calculated and registered",
  "calculation": {
    "approved": true,
    "dailyAllowance": 910.0,
    "incomeBase": "High",
    "totalDays": 300,
    "message": "Application approved"
  },
  "registration": {
    "success": true,
    "message": "Successfully registered to OAS",
    "registrationId": "REG-2026-001234"
  },
  "finalBenefit": {
    "personalNumber": "199001011234",
    "kassaName": "Akademikernas erkända arbetslöshetskassa",
    "isMember": true,
    "dailyAllowance": 910.0,
    "incomeBase": "High",
    "remainingDays": 300,
    "registrationDate": "2026-01-31T10:30:00Z",
    "lastUpdated": "2026-01-31T10:30:00Z"
  }
}
```

---

## Notes

- All monetary values are in Swedish Kronor (SEK)
- The service runs on port **9090**
- Logging is enabled at INFO level for all orchestration steps
- The service uses Ballerina HTTP client for backend communication
- Integration with WSO2 APIM Catalog and Moesif analytics
