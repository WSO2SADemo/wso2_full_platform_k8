# OpenAPI Specifications for Insurance Backend Services

## Customer API (Port 8082)

```yaml
openapi: 3.0.0
info:
  title: Insurance Customer API
  description: Customer-facing API for insurance policy and claims management
  version: 1.0.0
  contact:
    name: Insurance Backend Team

servers:
  - url: http://localhost:8082
    description: Local development server

paths:
  /insurance/customer/policy:
    post:
      summary: Get policy details by username
      description: Retrieves insurance policy information for a specific user
      operationId: getPolicy
      tags:
        - Policy
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UsernameRequest'
            examples:
              example1:
                value:
                  username: "john_doe"
      responses:
        '200':
          description: Policy details retrieved successfully
          content:
            application/json:
              schema:
                oneOf:
                  - $ref: '#/components/schemas/PolicyResponse'
                  - $ref: '#/components/schemas/ErrorResponse'
              examples:
                success:
                  value:
                    policyNumber: "POL-HEALTH-001"
                    policyType: "HEALTH"
                    coverageAmount: 100000.00
                    premiumAmount: 120.00
                    startDate: "2024-01-01"
                    endDate: "2025-01-01"
                    status: "ACTIVE"
                error:
                  value:
                    message: "No policy found for username: unknown_user"
                    errorCode: null

  /insurance/customer/claims:
    post:
      summary: Get claims list by username
      description: Retrieves all claims submitted by a specific user
      operationId: getClaims
      tags:
        - Claims
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UsernameRequest'
            examples:
              example1:
                value:
                  username: "john_doe"
      responses:
        '200':
          description: Claims list retrieved successfully
          content:
            application/json:
              schema:
                oneOf:
                  - type: array
                    items:
                      $ref: '#/components/schemas/Claim'
                  - $ref: '#/components/schemas/ErrorResponse'
              examples:
                success:
                  value:
                    - claimId: "CLM-001"
                      claimType: "Hospitalization"
                      amount: 3200.00
                      description: "Emergency appendix surgery"
                      submittedDate: "2024-03-10"
                      status: "APPROVED"
                    - claimId: "CLM-002"
                      claimType: "Outpatient"
                      amount: 450.00
                      description: "Specialist consultation and lab tests"
                      submittedDate: "2024-05-22"
                      status: "PENDING"
                error:
                  value:
                    message: "No policy found for username: unknown_user"
                    errorCode: null

  /insurance/customer/claims/submit:
    post:
      summary: Submit a new claim
      description: Submits a new insurance claim for processing
      operationId: submitClaim
      tags:
        - Claims
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ClaimSubmitRequest'
            examples:
              example1:
                value:
                  username: "john_doe"
                  claimType: "Hospitalization"
                  amount: 5000.00
                  description: "Medical procedure"
      responses:
        '200':
          description: Claim submission response
          content:
            application/json:
              schema:
                oneOf:
                  - $ref: '#/components/schemas/SuccessResponse'
                  - $ref: '#/components/schemas/ErrorResponse'
              examples:
                success:
                  value:
                    message: "Claim CLM-1234567890 submitted successfully and is under review"
                    success: true
                policyNotFound:
                  value:
                    message: "No policy found for username: unknown_user"
                    errorCode: null
                inactivePolicy:
                  value:
                    message: "Cannot submit claim. Policy status is: EXPIRED"
                    errorCode: null

components:
  schemas:
    UsernameRequest:
      type: object
      required:
        - username
      properties:
        username:
          type: string
          description: Username of the policy holder
          example: "john_doe"

    ClaimSubmitRequest:
      type: object
      required:
        - username
        - claimType
        - amount
        - description
      properties:
        username:
          type: string
          description: Username of the policy holder
          example: "john_doe"
        claimType:
          type: string
          description: Type of claim being submitted
          example: "Hospitalization"
        amount:
          type: number
          format: decimal
          description: Claim amount
          example: 5000.00
        description:
          type: string
          description: Description of the claim
          example: "Emergency medical procedure"

    PolicyResponse:
      type: object
      required:
        - policyNumber
        - policyType
        - coverageAmount
        - premiumAmount
        - startDate
        - endDate
        - status
      properties:
        policyNumber:
          type: string
          description: Unique policy identifier
          example: "POL-HEALTH-001"
        policyType:
          type: string
          description: Type of insurance policy
          enum: [HEALTH, LIFE, AUTO, HOME]
          example: "HEALTH"
        coverageAmount:
          type: number
          format: decimal
          description: Total coverage amount
          example: 100000.00
        premiumAmount:
          type: number
          format: decimal
          description: Premium amount
          example: 120.00
        startDate:
          type: string
          format: date
          description: Policy start date
          example: "2024-01-01"
        endDate:
          type: string
          format: date
          description: Policy end date
          example: "2025-01-01"
        status:
          type: string
          description: Current policy status
          enum: [ACTIVE, EXPIRED, SUSPENDED]
          example: "ACTIVE"

    Claim:
      type: object
      required:
        - claimId
        - claimType
        - amount
        - description
        - submittedDate
        - status
      properties:
        claimId:
          type: string
          description: Unique claim identifier
          example: "CLM-001"
        claimType:
          type: string
          description: Type of claim
          example: "Hospitalization"
        amount:
          type: number
          format: decimal
          description: Claim amount
          example: 3200.00
        description:
          type: string
          description: Claim description
          example: "Emergency appendix surgery"
        submittedDate:
          type: string
          format: date
          description: Date claim was submitted
          example: "2024-03-10"
        status:
          type: string
          description: Current claim status
          enum: [PENDING, APPROVED, REJECTED]
          example: "APPROVED"

    SuccessResponse:
      type: object
      required:
        - message
        - success
      properties:
        message:
          type: string
          description: Success message
          example: "Operation completed successfully"
        success:
          type: boolean
          description: Success indicator
          enum: [true]
          example: true

    ErrorResponse:
      type: object
      required:
        - message
      properties:
        message:
          type: string
          description: Error message
          example: "No policy found for username: unknown_user"
        errorCode:
          type: string
          nullable: true
          description: Optional error code
          example: null

tags:
  - name: Policy
    description: Policy management operations
  - name: Claims
    description: Claims management operations
```

---

## Agent API (Port 8083)

```yaml
openapi: 3.0.0
info:
  title: Insurance Agent API
  description: Agent-facing API for managing insurance policies
  version: 1.0.0
  contact:
    name: Insurance Backend Team

servers:
  - url: http://localhost:8083
    description: Local development server

paths:
  /insurance/agent/policies:
    get:
      summary: List all policies
      description: Retrieves a list of all insurance policies in the system
      operationId: listPolicies
      tags:
        - Policy Management
      responses:
        '200':
          description: List of all policies
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/InsurancePolicy'
              examples:
                success:
                  value:
                    - username: "john_doe"
                      policyNumber: "POL-HEALTH-001"
                      policyType: "HEALTH"
                      coverageAmount: 100000.00
                      premiumAmount: 120.00
                      startDate: "2024-01-01"
                      endDate: "2025-01-01"
                      status: "ACTIVE"
                    - username: "emma_premier"
                      policyNumber: "POL-HEALTH-002"
                      policyType: "HEALTH"
                      coverageAmount: 500000.00
                      premiumAmount: 350.00
                      startDate: "2024-01-01"
                      endDate: "2025-01-01"
                      status: "ACTIVE"

  /insurance/agent/policy/update:
    post:
      summary: Update policy status
      description: Updates the status of an insurance policy
      operationId: updatePolicyStatus
      tags:
        - Policy Management
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PolicyUpdateRequest'
            examples:
              example1:
                value:
                  policyNumber: "POL-HEALTH-001"
                  status: "SUSPENDED"
      responses:
        '200':
          description: Policy update response
          content:
            application/json:
              schema:
                oneOf:
                  - $ref: '#/components/schemas/SuccessResponse'
                  - $ref: '#/components/schemas/ErrorResponse'
              examples:
                success:
                  value:
                    message: "Policy POL-HEALTH-001 updated to status: SUSPENDED"
                    success: true
                notFound:
                  value:
                    message: "Policy not found: POL-UNKNOWN-999"
                    errorCode: null

components:
  schemas:
    InsurancePolicy:
      type: object
      required:
        - username
        - policyNumber
        - policyType
        - coverageAmount
        - premiumAmount
        - startDate
        - endDate
        - status
      properties:
        username:
          type: string
          description: Username of the policy holder
          example: "john_doe"
        policyNumber:
          type: string
          description: Unique policy identifier
          example: "POL-HEALTH-001"
        policyType:
          type: string
          description: Type of insurance policy
          enum: [HEALTH, LIFE, AUTO, HOME]
          example: "HEALTH"
        coverageAmount:
          type: number
          format: decimal
          description: Total coverage amount
          example: 100000.00
        premiumAmount:
          type: number
          format: decimal
          description: Premium amount
          example: 120.00
        startDate:
          type: string
          format: date
          description: Policy start date
          example: "2024-01-01"
        endDate:
          type: string
          format: date
          description: Policy end date
          example: "2025-01-01"
        status:
          type: string
          description: Current policy status
          enum: [ACTIVE, EXPIRED, SUSPENDED]
          example: "ACTIVE"

    PolicyUpdateRequest:
      type: object
      required:
        - policyNumber
        - status
      properties:
        policyNumber:
          type: string
          description: Policy number to update
          example: "POL-HEALTH-001"
        status:
          type: string
          description: New policy status
          enum: [ACTIVE, EXPIRED, SUSPENDED]
          example: "SUSPENDED"

    SuccessResponse:
      type: object
      required:
        - message
        - success
      properties:
        message:
          type: string
          description: Success message
          example: "Operation completed successfully"
        success:
          type: boolean
          description: Success indicator
          enum: [true]
          example: true

    ErrorResponse:
      type: object
      required:
        - message
      properties:
        message:
          type: string
          description: Error message
          example: "Policy not found"
        errorCode:
          type: string
          nullable: true
          description: Optional error code
          example: null

tags:
  - name: Policy Management
    description: Operations for managing insurance policies
```

---

## Usage Instructions

### Customer API Endpoints

**Base URL:** `http://localhost:8082`

1. **Get Policy Details**
   - **Endpoint:** `POST /insurance/customer/policy`
   - **Request Body:**
     ```json
     {
       "username": "john_doe"
     }
     ```

2. **Get Claims**
   - **Endpoint:** `POST /insurance/customer/claims`
   - **Request Body:**
     ```json
     {
       "username": "john_doe"
     }
     ```

3. **Submit Claim**
   - **Endpoint:** `POST /insurance/customer/claims/submit`
   - **Request Body:**
     ```json
     {
       "username": "john_doe",
       "claimType": "Hospitalization",
       "amount": 5000.00,
       "description": "Emergency medical procedure"
     }
     ```

### Agent API Endpoints

**Base URL:** `http://localhost:8083`

1. **List All Policies**
   - **Endpoint:** `GET /insurance/agent/policies`

2. **Update Policy Status**
   - **Endpoint:** `POST /insurance/agent/policy/update`
   - **Request Body:**
     ```json
     {
       "policyNumber": "POL-HEALTH-001",
       "status": "SUSPENDED"
     }
     ```

### Testing with cURL

```bash
# Get policy details
curl -X POST http://localhost:8082/insurance/customer/policy \
  -H "Content-Type: application/json" \
  -d '{"username": "john_doe"}'

# Get claims
curl -X POST http://localhost:8082/insurance/customer/claims \
  -H "Content-Type: application/json" \
  -d '{"username": "john_doe"}'

# Submit claim
curl -X POST http://localhost:8082/insurance/customer/claims/submit \
  -H "Content-Type: application/json" \
  -d '{"username": "john_doe", "claimType": "Hospitalization", "amount": 5000.00, "description": "Emergency procedure"}'

# List all policies
curl -X GET http://localhost:8083/insurance/agent/policies

# Update policy status
curl -X POST http://localhost:8083/insurance/agent/policy/update \
  -H "Content-Type: application/json" \
  -d '{"policyNumber": "POL-HEALTH-001", "status": "SUSPENDED"}'
```
