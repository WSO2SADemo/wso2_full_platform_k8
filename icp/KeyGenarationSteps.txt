#!/bin/bash

# ========================================
# TWO KEYSTORES APPROACH (WSO2 Standard)
# 1. gateway-keystore.jks - Gateway's private key + certificate
# 2. control-keystore.jks - Control Plane's private key + certificate
#
# Each product will have its own client-truststore.jks containing
# the public certificates of the other component for mutual trust
# ========================================

echo "================================================"
echo "Creating ICP Dashboard and Certificate"
echo "================================================"

# Step 1: Generate Gateway KeyStore with private key
keytool -genkeypair \
 -alias wso2carbon \
 -keyalg RSA \
 -keysize 2048 \
 -dname "CN=icp.wso2.com, OU=WSO2, O=WSO2, L=Colombo, ST=Western, C=LK" \
 -ext "SAN=DNS:icp.wso2.com,DNS:localhost,DNS:*.icp.svc.cluster.local" \
 -keystore icp/dashboard.jks \
 -storepass wso2carbon \
 -keypass wso2carbon \
 -validity 365

# Step 2: Export ICP certificate
keytool -export \
 -alias wso2carbon \
 -file icp/dashboard.crt \
 -keystore icp/dashboard.jks \
 -storepass wso2carbon


# Step 7: Move ICP cert to clinet-truststore.jks
keytool -importcert \
 -alias dashboard \
 -file icp/dashboard.crt \
 -keystore icp/client-truststore.jks \
 -storepass wso2carbon \
 -noprompt

 keytool -importcert \
  -alias control-cert \
  -file /Users/ramindu/wso2/general_demo/is_demo_resources/k8-artefacts-apim-bi-elk/integration/ballerina-integration.crt \
  -keystore icp/client-truststore.jks \
  -storetype JKS \
  -storepass wso2carbon \
  -noprompt

echo "================================================"
echo "Deploying to Kubernetes"
echo "================================================"

# Delete old secrets
kubectl delete secret dashboard-secret -n icp --ignore-not-found=true


# Create Gateway secret (keystore + truststore)
echo "Creating secret in apim-gw namespace..."
kubectl create secret generic dashboard-secret \
 --from-file=dashboard.jks=/Users/ramindu/wso2/general_demo/github/k8-artefacts-apim-bi-elk/icp/dashboard.jks \
 --from-file=client-truststore.jks=/Users/ramindu/wso2/general_demo/github/k8-artefacts-apim-bi-elk/icp/client-truststore.jks \
 -n icp

# Restart pods
echo "Restarting deployments..."
kubectl rollout restart deployment -n icp
