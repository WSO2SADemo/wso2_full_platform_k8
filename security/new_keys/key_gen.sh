#!/bin/bash

# ========================================
# SHARED KEYSTORE APPROACH (The Fix)
# Both CP and Gateway share the SAME 'wso2carbon.jks'
# This ensures Tokens signed by CP can be verified by Gateway.
# ========================================

# Clean up old files
# rm -f wso2carbon.jks client-truststore.jks cp-ingress.crt

echo "================================================"
echo "1. Generating Shared Keystore (wso2carbon.jks)"
echo "================================================"

rm -f wso2carbon.jks client-truststore.jks cp-ingress.crt wso2carbon.crt

# Path to your existing truststore (with Moesif certs)
EXISTING_TRUSTSTORE_PATH="/Users/ramindu/wso2/general_demo/is_demo_resources/k8-artefacts-apim-bi-elk/security/new_keys/client-truststore-pack.jks"

# Generate ONE KeyStore for BOTH components
keytool -genkeypair \
 -alias wso2carbon \
 -keyalg RSA \
 -keysize 2048 \
 -dname "CN=*.wso2.com, OU=WSO2, O=WSO2, L=Colombo, ST=Western, C=LK" \
 -ext "SAN=DNS:extgw.wso2.com,DNS:gw.wso2.com,DNS:cp.wso2.com,DNS:localhost,DNS:acp-wso2am-acp-service.apim-cp.svc.cluster.local,DNS:acp-wso2am-acp-1-service.apim-cp.svc.cluster.local,DNS:extgw-wso2am-universal-gw-service.apim-gw.svc.cluster.local,DNS:gw-wso2am-universal-gw-service.apim-gw.svc.cluster.local,DNS:*.apim-cp.svc.cluster.local,DNS:*.apim-gw.svc.cluster.local" \
 -keystore wso2carbon.jks \
 -storepass wso2carbon \
 -keypass wso2carbon \
 -validity 365

echo "================================================"
echo "2. Preparing Truststore (From existing Pack)"
echo "================================================"

if [ -f "$EXISTING_TRUSTSTORE_PATH" ]; then
    echo "Found existing truststore at: $EXISTING_TRUSTSTORE_PATH"
    echo "Copying to local workspace..."
    cp "$EXISTING_TRUSTSTORE_PATH" client-truststore.jks
else
    echo "❌ ERROR: Could not find truststore at $EXISTING_TRUSTSTORE_PATH"
    exit 1
fi

echo "================================================"
echo "2. Creating Truststore"
echo "================================================"

# 1. Export the public cert from the NEW shared keystore
keytool -export \
 -alias wso2carbon \
 -file wso2carbon.crt \
 -keystore wso2carbon.jks \
 -storepass wso2carbon

# 2. DELETE the old 'wso2carbon' alias from the copied truststore
# (This is the missing step!)
keytool -delete \
 -alias wso2carbon \
 -keystore client-truststore.jks \
 -storepass wso2carbon \
 -noprompt 2>/dev/null || true

# 3. Import the NEW wso2carbon cert
keytool -importcert \
 -alias wso2carbon \
 -file wso2carbon.crt \
 -keystore client-truststore.jks \
 -storepass wso2carbon \
 -noprompt

echo "================================================"
echo "3. Fetching Ingress Certificate (For Network Trust)"
echo "================================================"

# This is needed so Gateway can talk to CP API (HTTPS) without SSL errors
# We fetch the cert from the live K8s ingress
echo | openssl s_client -connect cp.wso2.com:443 -servername cp.wso2.com 2>/dev/null | openssl x509 -outform PEM > cp-ingress.crt

if [ -s cp-ingress.crt ]; then
    echo "Importing CP Ingress Cert..."
    keytool -importcert -alias cp-ingress -file cp-ingress.crt -keystore client-truststore.jks -storepass wso2carbon -noprompt
else
    echo "⚠️  Warning: Could not fetch cp.wso2.com cert. Ensure the ingress is running."
fi

echo "================================================"
echo "4. Deploying to Kubernetes"
echo "================================================"

# Delete old secrets
kubectl delete secret apim-keystore-secret -n apim-cp --ignore-not-found=true
kubectl delete secret apim-keystore-secret -n apim-gw --ignore-not-found=true

# --- CRITICAL FIX IN COMMANDS BELOW ---
# We map the local file 'wso2carbon.jks' to the key 'wso2carbon.jks'
# The Pod expects the file to be named 'wso2carbon.jks', not 'gateway-keystore.jks'

# 1. Create Gateway Secret
echo "Creating secret in apim-gw..."
kubectl create secret generic apim-keystore-secret \
 --from-file=wso2carbon.jks=wso2carbon.jks \
 --from-file=client-truststore.jks=client-truststore.jks \
 -n apim-gw

# 2. Create Control Plane Secret (Identical)
echo "Creating secret in apim-cp..."
kubectl create secret generic apim-keystore-secret \
 --from-file=wso2carbon.jks=wso2carbon.jks \
 --from-file=client-truststore.jks=client-truststore.jks \
 -n apim-cp

# Restart pods
echo "Restarting deployments..."
kubectl rollout restart deployment -n apim-cp
kubectl rollout restart deployment -n apim-gw

echo "✓ Done! Both components now share the same 'wso2carbon.jks'."