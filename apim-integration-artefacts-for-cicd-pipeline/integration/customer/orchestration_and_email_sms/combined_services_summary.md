## API Endpoints Summary

### Orchestration Service (Port 9090)

#### POST /api/benefits/register
Complete benefit registration orchestration flow.

**Request:**
```json
{
  "personalNumber": "198001011234",
  "kassaName": "TestKassa",
  "previousMonthlySalary": 35000.00,
  "workCertificates": ["cert1.pdf", "cert2.pdf"]
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Benefit successfully calculated and registered",
  "calculation": {
    "approved": true,
    "dailyAllowance": 910.00,
    "incomeBase": "High",
    "totalDays": 300,
    "message": "Application approved"
  },
  "registration": {
    "success": true,
    "message": "Member registered successfully",
    "registrationId": "REG-123456"
  },
  "finalBenefit": {
    "personalNumber": "198001011234",
    "kassaName": "TestKassa",
    "isMember": true,
    "dailyAllowance": 910.00,
    "incomeBase": "High",
    "remainingDays": 300,
    "registrationDate": "2024-01-15",
    "lastUpdated": "2024-01-15T10:30:00Z"
  }
}
```

### Notification Service (Port 9090)

#### POST /call_service_and_notify/send
Send email and SMS notifications.

**Request:**
```json
{
  "message": "Your benefit application has been approved",
  "data": {
    "applicationId": "APP-123456",
    "amount": 910.00
  },
  "sendEmail": true,
  "sendSms": true
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Notification sent successfully",
  "logId": "LOG-789012",
  "emailSent": true,
  "smsSent": true
}
```

#### GET /call_service_and_notify/health
Health check endpoint.

**Response:**
```
Notification Orchestration Service is running on port 9090
```
