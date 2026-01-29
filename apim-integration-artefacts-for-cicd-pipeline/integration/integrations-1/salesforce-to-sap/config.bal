// Configuration for external services
import ballerina/os;

string envMockApiUrl = os:getEnv("MOCK_API_BASE_URL");
string s4hanaClientConfigUsername = os:getEnv("s4hanaClientConfigUsername");
string s4hanaClientConfigPassword = os:getEnv("s4hanaClientConfigPassword");
string sfListenerConfigPassword = os:getEnv("sfListenerConfigPassword");
string sfListenerConfigUsername = os:getEnv("sfListenerConfigUsername");
string sfClientConfigClientId = os:getEnv("sfClientConfigClientId");
string sfClientConfigClientSecret = os:getEnv("sfClientConfigClientSecret");
string sfClientConfigRefreshToken = os:getEnv("sfClientConfigRefreshToken");
string sfClientConfigRefreshUrl = os:getEnv("sfClientConfigRefreshUrl");
string sfClientConfigBaseUrl = os:getEnv("sfClientConfigBaseUrl");
string s4hanaClientConfigHostname = os:getEnv("s4hanaClientConfigHostname");
