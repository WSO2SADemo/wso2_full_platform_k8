#!/bin/bash
set -e

# ========================================
# STEP 1: Create Secrets (keystores, app secrets)
# Run AFTER key_gen.sh has generated keystores
# but BEFORE deploying IS/CP/GW
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$ROOT_DIR/create_deployments/new_keys"

echo "================================================"
echo "1a. Creating keystore secrets"
echo "================================================"

# Delete existing secrets (if any)
kubectl delete secret apim-keystore-secret -n apim-gw --ignore-not-found=true
kubectl delete secret apim-keystore-secret -n apim-cp --ignore-not-found=true
kubectl delete secret wso2is-keystore-secret -n iam --ignore-not-found=true
kubectl delete secret is-tls -n iam --ignore-not-found=true

# Create APIM keystore secrets (JKS format)
echo "Creating apim-keystore-secret in apim-gw..."
kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks="$KEYS_DIR/wso2carbon.jks" \
  --from-file=client-truststore.jks="$KEYS_DIR/client-truststore.jks" \
  -n apim-gw

echo "Creating apim-keystore-secret in apim-cp..."
kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks="$KEYS_DIR/wso2carbon.jks" \
  --from-file=client-truststore.jks="$KEYS_DIR/client-truststore.jks" \
  -n apim-cp

# Create IS keystore secret (PKCS12 format)
echo "Creating wso2is-keystore-secret in iam..."
kubectl create secret generic wso2is-keystore-secret \
  --from-file=wso2carbon.p12="$KEYS_DIR/wso2carbon.p12" \
  --from-file=client-truststore.p12="$KEYS_DIR/client-truststore.p12" \
  -n iam

# Create IS TLS secret for ingress
echo "Creating is-tls in iam..."
openssl pkcs12 -in "$KEYS_DIR/wso2carbon.p12" -nocerts -out /tmp/wso2carbon.key -nodes -passin pass:wso2carbon 2>/dev/null
openssl pkcs12 -in "$KEYS_DIR/wso2carbon.p12" -nokeys -out /tmp/wso2carbon.crt -nodes -passin pass:wso2carbon 2>/dev/null
kubectl create secret tls is-tls --cert=/tmp/wso2carbon.crt --key=/tmp/wso2carbon.key -n iam
rm -f /tmp/wso2carbon.key /tmp/wso2carbon.crt

echo "================================================"
echo "1b. Creating app secrets"
echo "================================================"

# IS secrets (SMTP credentials)
kubectl delete secret is-secrets -n iam --ignore-not-found=true
kubectl apply -f "$ROOT_DIR/k8_deployments/kubernetes-is/is-secrets.yaml" -n iam

# APIM secrets (Moesif key)
kubectl apply -f "$ROOT_DIR/k8_deployments/am-control-plane/apim-secrets.yaml"

echo "================================================"
echo "1c. Creating ConfigMaps"
echo "================================================"

# CoreDNS custom config (maps wso2 hostnames to nginx ingress ClusterIP)
kubectl apply -f "$ROOT_DIR/k8_deployments/am-control-plane/coredns-custom.yaml"
kubectl rollout restart deployment coredns -n kube-system

# IS config map (is-values)
kubectl apply -f "$ROOT_DIR/k8_deployments/kubernetes-is/is-config-map.yaml" -n iam

echo ""
echo "All secrets and configmaps created."
