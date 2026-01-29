import ballerina/os;

configurable string ftpUsername = os:getEnv("ftpUsername");
configurable string ftpPassword = os:getEnv("ftpPassword");
configurable string ftpHost = os:getEnv("ftpHost");
configurable string ftpPortStr = os:getEnv("ftpPort");
configurable string ftpDirectory = os:getEnv("ftpDirectory");
configurable string nfsHost = os:getEnv("nfsHost");
configurable string nfsPortStr = os:getEnv("nfsPort");
configurable string nfsMountPoint = os:getEnv("nfsMountPoint");
configurable string nfsDirectory = os:getEnv("nfsDirectory");