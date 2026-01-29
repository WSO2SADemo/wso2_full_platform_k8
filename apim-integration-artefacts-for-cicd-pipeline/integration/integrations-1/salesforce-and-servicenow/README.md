# AI Fulfillment Agent

An intelligent order fulfillment and customer service agent built with Ballerina that automates order returns, customer communications, and incident management across multiple enterprise systems.

## Architecture Overview

The AI Fulfillment Agent operates as a centralized orchestration layer that integrates with multiple enterprise systems to provide automated order fulfillment and customer service capabilities:

![Architecture Diagram](./architecture-diagram.svg)

### Key Components

1. **AI Agent Core**: Intelligent decision-making engine that processes customer requests and orchestrates actions across integrated systems
2. **Salesforce Integration**: Manages customer accounts, orders, and order status updates
3. **ServiceNow Integration**: Creates and tracks incidents for high-value returns requiring manual review
4. **SendGrid Integration**: Handles automated email notifications for order updates and return confirmations
5. **Pinecone Vector Database**: Stores and retrieves policy information for intelligent query responses

### Business Logic Flow

1. **Order Return Processing**:

   - Customer initiates return request
   - Agent validates return eligibility (7-day window, non-returnable items etc.)
   - Orders under $100: Automatic approval and Salesforce status update
   - Orders $100+: ServiceNow incident creation for manual review
   - Email notifications sent via SendGrid

2. **Knowledge Base Queries**:
   - Return policy questions processed through Pinecone vector search
   - AI-powered responses based on stored policy documents

## Prerequisites

Before setting up the AI Fulfillment Agent, you need to configure the following external services:

### 1. Salesforce Setup

1. **Create a Salesforce Developer Account**:

   - Go to [Salesforce Developer](https://developer.salesforce.com/)
   - Sign up for a free developer account

2. **Create an External Client App**:

   - Navigate to Setup → Apps → App Manager
   - Click "New External Client App"
   - Fill in the required details:
     - New External Client App Name: `AI Fulfillment Agent`
     - API Name: `ai_fulfillment_agent`
     - Contact Email: Your email
     - Enable OAuth Settings: ✓
     - Callback URL: Use a placeholder like `https://localhost/callback`
     - OAuth Scopes:
       - Manage user data via APIs (api)
       - Perform requests at any time (refresh_token, offline_access)
       - Access unique user identifiers (openid)
     - In the `Flow Enablement` section under `OAuth Settings`, enable Client Credentials Flow.
     - Create the External Client App.
     - Go to OAuth Policies section and enable `Client Credentials Flow` in the `OAuth Flows and External Client App Enhancements` subsection. Provide the salesforce username and click on save.

3. **Obtain Credentials**:

   - Consumer Key (Client ID)
   - Consumer Secret (Client Secret)
   - Token URL: `https://your-instance.salesforce.com/services/oauth2/token`

4. **Set Up Test Data**:

   - Create sample Account records
   - Create sample Product records
   - Create sample Order records with various amounts (some under $100, some over)

5. **Configure Order Object**:
   - Navigate to Setup → Object Manager → Order → Fields & Relationships
   - Edit the "Contract Number" field and make it optional (uncheck "Required")
   - For the Status field, add a new picklist value "Returned"
   - Save the changes to enable the agent to update order status to "Returned"

### 2. ServiceNow Setup

1. **Get ServiceNow Developer Instance**:

   - Go to [ServiceNow Developer](https://developer.servicenow.com/)
   - Click on the "Sign up and Start Building" button.
   - Fill in the required registration details (name, email, etc.) and complete the sign-up process.
   - After you've created and verified your account, log in to the ServiceNow Developer Site.
   - On your dashboard, look for the "Request Instance" button in the dashboard.
   - It will take a few minutes to provision your instance. Once it's ready, a dialog will appear with your instance URL and the admin login details. Make sure to copy the admin password and save it in a secure location.

2. **Create Integration User**:

   - Navigate to User Administration → Users
   - Create a new user with appropriate roles:
     - `itil`
     - `itil_admin`

3. **Configure REST API Access**:
   - Ensure REST API is enabled
   - Note your instance URL: `https://your-instance.service-now.com`

### 3. SendGrid Setup

1. **Create SendGrid Account**:

   - Go to [SendGrid](https://sendgrid.com/)
   - Sign up for a free account

2. **Generate API Key**:

   - Navigate to Settings → API Keys
   - Create new API key with "Full Access" permissions
   - Store the API key securely

3. **Verify Sender Email**:
   - Go to Settings → Sender Authentication
   - Verify your sender email address

### 4. Pinecone Setup

1. **Create Pinecone Account**:

   - Go to [Pinecone](https://www.pinecone.io/)
   - Sign up for a free account

2. **Create Index**:

   - Create a new index with:
     - Dimensions: 1536 (for OpenAI embeddings)
     - Metric: cosine
     - Name: `fulfillment-policies`

3. **Get API Credentials**:
   - API Key from the Pinecone console
   - Index URL from your index details

## Installation & Setup

### 1. Prerequisites

- [Ballerina Swan Lake](https://ballerina.io/downloads/) (Latest version)
- Ballerina Integrator VS Code plugin
- Java 21 or later
- Git

### 2. Clone the Repository

```bash
git clone https://github.com/wso2-enterprise/presales-pocs.git
cd presales-pocs/BI/BI-fullfillment-agent
```

### 3. Configure Environment

Create a `Config.toml` file in the project root with your service credentials:

```toml
# Salesforce Configuration
salesforceBaseUrl = "https://your-instance.salesforce.com"
salesforceClientId = "your_salesforce_consumer_key"
salesforceClientSecret = "your_salesforce_consumer_secret"
salesforceTokenUrl = "https://your-instance.salesforce.com/services/oauth2/token"

# ServiceNow Configuration
servicenowBaseUrl = "https://your-instance.service-now.com"
servicenowUsername = "your_servicenow_username"
servicenowPassword = "your_servicenow_password"

# Pinecone Configuration
pineconeVectorStoreUrl = "https://your-index-url.pinecone.io"
pineconeApiKey = "your_pinecone_api_key"

# SendGrid Configuration
sendgridApiToken = "your_sendgrid_api_key"
sendGridSenderEmail = "your_verified_sender@example.com"
```

### 4. Load Policy Documents (Optional)

If you want to use the knowledge base functionality, upload your return policy documents to Pinecone:

1. Place your policy PDF in the `policies/` directory
2. The system will automatically process and index the documents

## Running the Application

- Open the Ballerina Integrator VS Code plugin.
- All the components in the project like Agents, automation will be listed in the left side pane.
- Click on the `AI Agent Services - /fullfillmentAgent` and click on the `Chat` button to the run the Agent.

### Example Interactions

1. **Order Return Request**:

   ```
   User: "I need to return order #ORD-12345 for account ACME Corp"
   Agent: "I'll process your return request. Let me check the order details..."
   ```

2. **Policy Inquiry**:

   ```
   User: "What is your return policy?"
   Agent: "According to our return policy, items can be returned within 7 days..."
   ```

3. **Order Status Check**:
   ```
   User: "What orders does ACME Corp have?"
   Agent: "Here are the orders for ACME Corp: [order details]"
   ```

## Features

- **Automated Return Processing**: Intelligent decision-making for return approvals
- **Multi-System Integration**: Seamless coordination between Salesforce, ServiceNow, and SendGrid
- **Knowledge Base Queries**: AI-powered responses using vector search
- **Email Notifications**: Automated customer communications
- **Incident Management**: Automatic ServiceNow ticket creation for complex cases
- **Order Validation**: Return eligibility checking with business rules

## Configuration Options

The agent's behavior can be customized through various configuration parameters:

- **Return Window**: Default 7 days (configurable in business logic)
- **Auto-Approval Threshold**: $100 (configurable in business logic)
- **Email Templates**: Customizable through SendGrid
- **System Prompts**: Adjustable AI agent instructions

## Troubleshooting

### Common Issues

1. **Authentication Failures**:

   - Verify all API credentials in `Config.toml`
   - Check service endpoint URLs
   - Ensure proper OAuth scopes for Salesforce

2. **Connection Timeouts**:

   - Verify network connectivity to external services
   - Check firewall settings
   - Validate service endpoint availability

3. **Data Not Found**:
   - Ensure test data exists in Salesforce
   - Verify account and order IDs are correct
   - Check Salesforce user permissions

### Logs

Application logs are available in the console output and can help diagnose issues with external service integrations.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is part of the WSO2 Enterprise presales POCs repository.

## Support

For support and questions, please contact the WSO2 Enterprise team or create an issue in the repository.
