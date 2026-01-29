// Configuration for OAS and Cash Registry services
import ballerina/os;

// OAS Service Configuration
configurable int oasServicePort = 9092;

// Cash Registry Service Configuration
configurable int cashRegistryServicePort = 9091;

// Sample A-kassa names
public const string UNIONENS_AKASSA = "Unionens A-kassa";
public const string AKADEMIKERNAS_AKASSA = "Akademikernas A-kassa";
public const string ALFA_KASSA = "Alfa-kassan";
public const string Sveriges_AKASSA = "Sveriges A-kassa";

string scServiceUrl = os:getEnv("BAL_CONFIG_VAR_BALLERINAX_WSO2_APIM_CATALOG_SERVICEURL");
