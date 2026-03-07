# OpenAPI Specification for Unemployment Fund Orchestration API

```yaml
openapi: 3.0.0
info:
  title: Unemployment Fund Orchestration API
  description: |
    Scatter-gather orchestration service that queries 10 unemployment fund backends in parallel
    and returns an aggregated response with valid results, errors, and blank responses.
  version: 1.0.0
  contact:
    name: API Support

servers:
  - url: http://localhost:9090
    description: Local development server

paths:
  /unemployment/lookup:
    post:
      summary: Lookup member across all unemployment funds
      description: |
        Performs a parallel lookup across 10 unemployment fund backends for a given person ID.
        Returns an aggregated response containing valid member information, errors, and blank responses.
        
        The service has a 3-second SLA with per-fund timeout of 2.9 seconds.
      operationId: lookupMember
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/MemberLookupRequest'
            examples:
              validRequest:
                summary: Valid person ID lookup
                value:
                  personId: "199001011234"
      responses:
        '200':
          description: Aggregated response from all funds
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AggregatedResponse'
              examples:
                mixedResults:
                  summary: Mixed results with valid, errors, and blank responses
                  value:
                    personId: "199001011234"
                    totalFundsQueried: 10
                    summary:
                      validCount: 5
                      errorCount: 3
                      blankCount: 2
                    validResponses:
                      - fund: "AEA"
                        personId: "199001011234"
                        status: "ACTIVE"
                        registeredSince: "2020-01-15"
                        memberType: "FULL"
                      - fund: "Unionen"
                        personId: "199001011234"
                        status: "ACTIVE"
                        registeredSince: "2019-06-01"
                        memberType: "FULL"
                    errors:
                      - fund: "Vision"
                        errorType: "TIMEOUT"
                        message: "Request timeout after 2.9 seconds"
                      - fund: "SEKO"
                        errorType: "SERVICE_ERROR"
                        message: "HTTP 503 - Service unavailable"
                    blankResponses:
                      - fund: "Fastighets"
                        message: "Person not registered in this fund"
        '500':
          description: Internal server error
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
                    example: "Internal server error occurred"

components:
  schemas:
    MemberLookupRequest:
      type: object
      required:
        - personId
      properties:
        personId:
          type: string
          description: Swedish personal identity number (personnummer)
          example: "199001011234"
          pattern: '^\d{10,12}$'

    AggregatedResponse:
      type: object
      required:
        - personId
        - totalFundsQueried
        - summary
        - validResponses
        - errors
        - blankResponses
      properties:
        personId:
          type: string
          description: The person ID that was queried
          example: "199001011234"
        totalFundsQueried:
          type: integer
          description: Total number of funds queried (always 10)
          example: 10
        summary:
          $ref: '#/components/schemas/ResponseSummary'
        validResponses:
          type: array
          description: Successful member lookups from funds
          items:
            $ref: '#/components/schemas/MemberInfo'
        errors:
          type: array
          description: Errors encountered during fund lookups
          items:
            $ref: '#/components/schemas/FundError'
        blankResponses:
          type: array
          description: Funds that returned empty or no data
          items:
            $ref: '#/components/schemas/BlankResponse'

    ResponseSummary:
      type: object
      required:
        - validCount
        - errorCount
        - blankCount
      properties:
        validCount:
          type: integer
          description: Number of funds that returned valid member data
          example: 5
        errorCount:
          type: integer
          description: Number of funds that returned errors or timed out
          example: 3
        blankCount:
          type: integer
          description: Number of funds that returned blank/empty responses
          example: 2

    MemberInfo:
      type: object
      required:
        - fund
        - personId
        - status
        - registeredSince
        - memberType
      properties:
        fund:
          type: string
          description: Name of the unemployment fund
          example: "AEA"
        personId:
          type: string
          description: Person's identity number
          example: "199001011234"
        status:
          type: string
          description: Membership status
          enum:
            - ACTIVE
            - INACTIVE
            - SUSPENDED
          example: "ACTIVE"
        registeredSince:
          type: string
          format: date
          description: Date when the person registered with this fund
          example: "2020-01-15"
        memberType:
          type: string
          description: Type of membership
          enum:
            - FULL
            - PARTIAL
            - STUDENT
          example: "FULL"

    FundError:
      type: object
      required:
        - fund
        - errorType
        - message
      properties:
        fund:
          type: string
          description: Name of the unemployment fund
          example: "Vision"
        errorType:
          type: string
          description: Type of error encountered
          enum:
            - TIMEOUT
            - SERVICE_ERROR
            - PARSE_ERROR
          example: "TIMEOUT"
        message:
          type: string
          description: Detailed error message
          example: "Request timeout after 2.9 seconds"

    BlankResponse:
      type: object
      required:
        - fund
        - message
      properties:
        fund:
          type: string
          description: Name of the unemployment fund
          example: "Fastighets"
        message:
          type: string
          description: Reason for blank response
          example: "Person not registered in this fund"
```

## Summary

The OpenAPI specification documents:

- **Endpoint**: `POST /unemployment/lookup`
- **Request**: `MemberLookupRequest` with personId field
- **Response**: `AggregatedResponse` containing:
  - Summary counts (valid, error, blank)
  - Array of valid member information
  - Array of errors (timeouts, service errors)
  - Array of blank responses
- **All data types**: MemberInfo, FundError, BlankResponse, ResponseSummary

You can use this specification with tools like Swagger UI, Postman, or API documentation generators.
