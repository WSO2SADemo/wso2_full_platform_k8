import ballerina/os;

configurable string ftpUsername = os:getEnv("ftpUsername");
configurable string ftpPassword = os:getEnv("ftpPassword");
configurable string ftpHost = os:getEnv("ftpHost");
configurable int ftpPort = 21;
configurable string ftpDirectory = os:getEnv("ftpDirectory");
configurable string nfsHost = os:getEnv("nfsHost");
configurable int nfsPort = 2049;
configurable string nfsMountPoint = os:getEnv("nfsMountPoint");
configurable string nfsDirectory = os:getEnv("nfsDirectory");

// MySQL Database Configuration
configurable string mysqlHost = os:getEnv("mysqlHost");
configurable int mysqlPort = 3306;
configurable string mysqlUser = os:getEnv("mysqlUser");
configurable string mysqlPassword = os:getEnv("mysqlPassword");
configurable string mysqlDatabase = os:getEnv("mysqlDatabase");

// HTTP Service Configuration
configurable int httpPort = 9080;

// Kafka Configuration
configurable string kafkaBootstrapServers = os:getEnv("kafkaBootstrapServers");
configurable string kafkaGroupId = os:getEnv("kafkaGroupId");
configurable string kafkaTopic = os:getEnv("kafkaTopic");

// WebSocket Configuration
configurable int websocketPort = 9081;