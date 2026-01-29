// Configuration for external services
import ballerina/os;

string envMockApiUrl = os:getEnv("MOCK_API_BASE_URL");
string scServiceUrl = os:getEnv("BAL_CONFIG_VAR_BALLERINAX_WSO2_APIM_CATALOG_SERVICEURL");
string mockApiBaseUrl = envMockApiUrl.length() > 0 ? envMockApiUrl : "https://61038a4279ed680017482530.mockapi.io/sample-service";
// configurable int airlineServicePort = 8080;
