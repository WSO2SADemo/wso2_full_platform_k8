#!/bin/bash
set -e

# ========================================
# STEP 4: Fetch ingress certs and update truststores
# Run AFTER IS and CP are deployed and their ingresses are up
# This fetches the live TLS certs from the ingresses and
# adds them to the client-truststore so GW can trust them.
# ========================================

# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!

# make sure you have updated the /etc/hosts or CoreDNS to point cp.wso2.com and is.wso2.com to the ingress IP before running this step

# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$ROOT_DIR/create_deployments/new_keys"

echo "================================================"
echo "4a. Fetching ingress certificates"
echo "================================================"

# Fetch CP ingress cert
echo "Fetching cert from cp.wso2.com..."
echo | openssl s_client -connect cp.wso2.com:443 -servername cp.wso2.com 2>/dev/null | openssl x509 -outform PEM > "$KEYS_DIR/cp-ingress.crt"

if [ ! -s "$KEYS_DIR/cp-ingress.crt" ]; then
  echo "ERROR: Could not fetch cp.wso2.com cert. Is the CP ingress running?"
  echo "Check: kubectl get ingress -n apim-cp"
  exit 1
fi
echo "CP ingress cert fetched."

# Fetch IS ingress cert
echo "Fetching cert from is.wso2.com..."
echo | openssl s_client -connect is.wso2.com:443 -servername is.wso2.com 2>/dev/null | openssl x509 -outform PEM > "$KEYS_DIR/is-ingress.crt"

if [ ! -s "$KEYS_DIR/is-ingress.crt" ]; then
  echo "ERROR: Could not fetch is.wso2.com cert. Is the IS ingress running?"
  echo "Check: kubectl get ingress -n iam"
  exit 1
fi
echo "IS ingress cert fetched."

echo "================================================"
echo "4b. Importing ingress certs into truststores"
echo "================================================"

# Export public cert from wso2carbon.jks and import into client-truststore.jks
echo "Exporting public cert from wso2carbon.jks..."
keytool -export -alias wso2carbon -keystore "$KEYS_DIR/wso2carbon.jks" -storepass wso2carbon -file "$KEYS_DIR/wso2carbon-gw.crt" -rfc

keytool -delete -alias gateway_certificate_alias -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt 2>/dev/null || true

echo "Importing wso2carbon cert as gateway_certificate_alias..."
keytool -importcert -alias gateway_certificate_alias -file "$KEYS_DIR/wso2carbon-gw.crt" \
  -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt

# Remove old ingress certs if they exist
keytool -delete -alias cp-ingress -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt 2>/dev/null || true
keytool -delete -alias is-ingress -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt 2>/dev/null || true

# Import new ingress certs
echo "Importing CP ingress cert..."
keytool -importcert -alias cp-ingress -file "$KEYS_DIR/cp-ingress.crt" \
  -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt

echo "Importing IS ingress cert..."
keytool -importcert -alias is-ingress -file "$KEYS_DIR/is-ingress.crt" \
  -keystore "$KEYS_DIR/client-truststore.jks" -storepass wso2carbon -noprompt

# Regenerate PKCS12 truststore (for IS)
rm -f "$KEYS_DIR/client-truststore.p12"
keytool -importkeystore \
  -srckeystore "$KEYS_DIR/client-truststore.jks" \
  -srcstoretype JKS \
  -srcstorepass wso2carbon \
  -destkeystore "$KEYS_DIR/client-truststore.p12" \
  -deststoretype PKCS12 \
  -deststorepass wso2carbon

echo "================================================"
echo "4c. Recreating K8s secrets with updated truststores"
echo "================================================"

# Recreate secrets with the updated truststore
kubectl delete secret apim-keystore-secret -n apim-gw --ignore-not-found=true
kubectl delete secret apim-keystore-secret -n apim-cp --ignore-not-found=true
kubectl delete secret wso2is-keystore-secret -n iam --ignore-not-found=true

kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks="$KEYS_DIR/wso2carbon.jks" \
  --from-file=client-truststore.jks="$KEYS_DIR/client-truststore.jks" \
  -n apim-gw

kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks="$KEYS_DIR/wso2carbon.jks" \
  --from-file=client-truststore.jks="$KEYS_DIR/client-truststore.jks" \
  -n apim-cp

kubectl create secret generic wso2is-keystore-secret \
  --from-file=wso2carbon.p12="$KEYS_DIR/wso2carbon.p12" \
  --from-file=client-truststore.p12="$KEYS_DIR/client-truststore.p12" \
  -n iam

kubectl annotate ingress acp-wso2am-acp-ingress nginx.ingress.kubernetes.io/proxy-body-size="10m" -n apim-cp


echo "================================================"
echo "4d. RESTART IS and CP to pick up new truststores MANUALLY !!!!!!!!"
echo "================================================"

# kubectl rollout restart deployment -n iam
# kubectl rollout restart deployment -n apim-cp

# echo "Waiting for IS to be ready..."
# kubectl rollout status deployment/wso2is-identity-server -n iam --timeout=300s || true

# echo "Waiting for CP to be ready..."
# kubectl rollout status deployment -n apim-cp --timeout=300s || true

# echo ""
# echo "Truststores updated. IS and CP restarted."
