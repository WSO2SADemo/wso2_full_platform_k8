// Configuration for external services
import ballerina/os;

string envMockApiUrl = os:getEnv("MOCK_API_BASE_URL");
string s4hanaClientConfigUsername = os:getEnv("s4hanaClientConfigUsername");
string s4hanaClientConfigPassword = os:getEnv("s4hanaClientConfigPassword");
string s4hanaClientConfigHostname = os:getEnv("s4hanaClientConfigHostname");
