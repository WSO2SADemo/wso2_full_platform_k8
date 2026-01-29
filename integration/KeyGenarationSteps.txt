#!/bin/bash

# ========================================
# TWO KEYSTORES APPROACH (WSO2 Standard) - PKCS12 Version
# 1. dashboard.p12 - Private key + certificate
# 2. client-truststore.p12 - Public certificates for mutual trust
# ========================================

echo "================================================"
echo "Creating Ballerina-Integration Dashboard and Certificate (P12)"
echo "================================================"

# ------------------------------------------------------------------
# Step 1: Generate Gateway KeyStore (PKCS12)
# ------------------------------------------------------------------
# Creates dashboard.p12 with the private key
keytool -genkeypair \
  -alias ballerina \
  -keyalg RSA \
  -keysize 2048 \
  -dname "CN=ballarina-integration.wso2.com, OU=WSO2, O=WSO2, L=Colombo, ST=Western, C=LK" \
  -ext "SAN=DNS:ballarina-integration.wso2.com,DNS:localhost,DNS:*.ballarina-integration.svc.cluster.local" \
  -keystore integration/keystore.p12 \
  -storetype PKCS12 \
  -storepass ballerina \
  -validity 365

# ------------------------------------------------------------------
# Step 2: Export Certificate
# ------------------------------------------------------------------
# Exports the public cert from the P12 keystore
keytool -export \
  -alias ballerina \
  -file integration/ballerina-integration.crt \
  -keystore integration/keystore.p12 \
  -storetype PKCS12 \
  -storepass ballerina

keytool -delete -alias actual-cp-ingress-cert -keystore integration/truststore.p12 -storepass ballerina

keytool -importcert \
  -alias actual-cp-ingress-cert \
  -file /Users/ramindu/wso2/general_demo/is_demo_resources/k8-artefacts-apim-bi-elk/security/new_keys/cp-ingress.crt \
  -keystore integration/truststore.p12 \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

keytool -importcert \
  -alias control-cert \
  -file /Users/ramindu/wso2/general_demo/is_demo_resources/k8-artefacts-apim-bi-elk/security/cp/control-cert.crt \
  -keystore integration/truststore.p12 \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

# ------------------------------------------------------------------
# Step 3: Create Client Truststore (PKCS12)
# ------------------------------------------------------------------
# Note: Keytool creates the file automatically on the first import. 
# There is no explicit "create empty p12" command required.

keytool -importcert \
      -alias dashboard \
      -file icp/dashboard.crt \
      -keystore integration/truststore.p12 \
      -storetype PKCS12 \
      -storepass ballerina \
      -noprompt

# Import local ballerina-integration cert
keytool -importcert \
  -alias ballerina-local \
  -file integration/ballerina-integration.crt \
  -keystore integration/truststore.p12 \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

keytool -export -alias ballerina -file integration/ballerina.crt -keystore integration/keystore.p12 -storepass ballerina

keytool -import -trustcacerts -alias ballerina -file integration/ballerina.crt -keystore integration/truststore.p12 -storepass ballerina -noprompt

echo "================================================"
echo "Deploying to Kubernetes"
echo "================================================"

# Delete old secrets
kubectl delete secret ballerina-integration-secret -n ballerina


kubectl create secret generic ballerina-integration-secret \
  --from-file=ballerinaKeystore.p12=integration/keystore.p12 \
  --from-file=ballerinaTruststore.p12=integration/truststore.p12 \
  -n ballerina