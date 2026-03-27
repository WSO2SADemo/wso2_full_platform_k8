#!/bin/bash
set -e

# ========================================
# STEP 9: Fetch ingress certs and update integration/truststore.p12
# Run AFTER IS and CP are deployed and their ingresses are up.
# Ensure cp.wso2.com and is.wso2.com resolve correctly before running.
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$ROOT_DIR/create_deployments/new_keys"
TRUSTSTORE="$ROOT_DIR/integration/truststore.p12"
STOREPASS="ballerina"

echo "================================================"
echo "9a. Fetching ingress certificates"
echo "================================================"

echo "Fetching cert from cp.wso2.com..."
echo | openssl s_client -connect cp.wso2.com:443 -servername cp.wso2.com 2>/dev/null \
  | openssl x509 -outform PEM > "$KEYS_DIR/cp-ingress.crt"

if [ ! -s "$KEYS_DIR/cp-ingress.crt" ]; then
  echo "ERROR: Could not fetch cp.wso2.com cert. Is the CP ingress running?"
  echo "Check: kubectl get ingress -n apim-cp"
  exit 1
fi
echo "CP ingress cert fetched → $KEYS_DIR/cp-ingress.crt"

echo "Fetching cert from is.wso2.com..."
echo | openssl s_client -connect is.wso2.com:443 -servername is.wso2.com 2>/dev/null \
  | openssl x509 -outform PEM > "$KEYS_DIR/is-ingress.crt"

if [ ! -s "$KEYS_DIR/is-ingress.crt" ]; then
  echo "ERROR: Could not fetch is.wso2.com cert. Is the IS ingress running?"
  echo "Check: kubectl get ingress -n iam"
  exit 1
fi
echo "IS ingress cert fetched → $KEYS_DIR/is-ingress.crt"

echo "Fetching cert from gw.wso2.com..."
echo | openssl s_client -connect gw.wso2.com:443 -servername gw.wso2.com 2>/dev/null \
  | openssl x509 -outform PEM > "$KEYS_DIR/gw-ingress.crt"

if [ ! -s "$KEYS_DIR/gw-ingress.crt" ]; then
  echo "ERROR: Could not fetch gw.wso2.com cert. Is the GW ingress running?"
  echo "Check: kubectl get ingress -n apim-gw"
  exit 1
fi
echo "GW ingress cert fetched → $KEYS_DIR/gw-ingress.crt"

echo ""
echo "================================================"
echo "9b. Updating integration/truststore.p12"
echo "================================================"

# Remove old entries if they exist
keytool -delete -alias cp-ingress -keystore "$TRUSTSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true
keytool -delete -alias is-ingress -keystore "$TRUSTSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true
keytool -delete -alias gw-ingress -keystore "$TRUSTSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true

echo "Importing CP ingress cert (alias: cp-ingress)..."
keytool -importcert -alias cp-ingress \
  -file "$KEYS_DIR/cp-ingress.crt" \
  -keystore "$TRUSTSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Importing IS ingress cert (alias: is-ingress)..."
keytool -importcert -alias is-ingress \
  -file "$KEYS_DIR/is-ingress.crt" \
  -keystore "$TRUSTSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Importing GW ingress cert (alias: gw-ingress)..."
keytool -importcert -alias gw-ingress \
  -file "$KEYS_DIR/gw-ingress.crt" \
  -keystore "$TRUSTSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Truststore updated. Current entries:"
keytool -list -keystore "$TRUSTSTORE" -storepass "$STOREPASS" -storetype PKCS12 2>/dev/null \
  | grep "trustedCertEntry" | awk '{print "  •", $1}'

echo ""
echo "================================================"
echo "9c. Updating integration/keystore.p12"
echo "================================================"

KEYSTORE="$ROOT_DIR/integration/keystore.p12"

keytool -delete -alias cp-ingress -keystore "$KEYSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true
keytool -delete -alias is-ingress -keystore "$KEYSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true
keytool -delete -alias gw-ingress -keystore "$KEYSTORE" -storepass "$STOREPASS" -noprompt 2>/dev/null || true

echo "Importing CP ingress cert into keystore (alias: cp-ingress)..."
keytool -importcert -alias cp-ingress \
  -file "$KEYS_DIR/cp-ingress.crt" \
  -keystore "$KEYSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Importing IS ingress cert into keystore (alias: is-ingress)..."
keytool -importcert -alias is-ingress \
  -file "$KEYS_DIR/is-ingress.crt" \
  -keystore "$KEYSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Importing GW ingress cert into keystore (alias: gw-ingress)..."
keytool -importcert -alias gw-ingress \
  -file "$KEYS_DIR/gw-ingress.crt" \
  -keystore "$KEYSTORE" \
  -storetype PKCS12 \
  -storepass "$STOREPASS" \
  -noprompt

echo "Keystore updated. Current entries:"
keytool -list -keystore "$KEYSTORE" -storepass "$STOREPASS" -storetype PKCS12 2>/dev/null \
  | awk '{print "  •", $1}'

echo ""
echo ""
echo "================================================"
echo "9d. Recreating ballerina-integration-secret"
echo "================================================"

KEYSTORE="$ROOT_DIR/integration/keystore.p12"

kubectl delete secret ballerina-integration-secret -n ballerina --ignore-not-found=true

kubectl create secret generic ballerina-integration-secret \
  --from-file=ballerinaKeystore.p12="$KEYSTORE" \
  --from-file=ballerinaTruststore.p12="$TRUSTSTORE" \
  -n ballerina

echo "ballerina-integration-secret recreated in namespace: ballerina"

echo ""
echo ""
echo "================================================"
echo "9e. Restarting Ballerina deployments"
echo "================================================"

kubectl rollout restart deployment -n ballerina
kubectl rollout status deployment -n ballerina --timeout=180s || true

echo ""
echo "Done. Integration truststores updated with cp-ingress and is-ingress certs."
