#!/bin/bash
set -e

# ========================================
# STEP 6: Deploy Integration Control Plane (ICP)
# Run AFTER gateways are up (step 5).
# Safe to re-run at any time (idempotent).
#
# This script:
#   a) Installs cert-manager (if not present)
#   b) Deploys ICP resources to the 'icp' namespace (Nginx Ingress, same IP as all other services)
#   c) Extracts the ICP self-signed backend cert for Ballerina truststore
#   d) Imports the ICP cert into the Ballerina truststore
#   e) Recreates ballerina-integration-secret with the updated truststore
#   f) Restarts Ballerina integrations to pick up the new trust
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ICP_K8S_DIR="$ROOT_DIR/k8_deployments/integration-control-plane/kubernetes"
INTEGRATION_DIR="$ROOT_DIR/integration"
BALLERINA_KEYSTORE="$INTEGRATION_DIR/keystore.p12"
BALLERINA_TRUSTSTORE="$INTEGRATION_DIR/truststore.p12"
ICP_BACKEND_CERT_FILE="/tmp/icp-backend-cert.pem"
ICP_IMAGE="ramilu90/wso2icp:2.0.0"

# ── Preflight checks ──────────────────────────────────────────────────────────
if [ ! -f "$BALLERINA_KEYSTORE" ]; then
  echo "ERROR: Ballerina keystore not found at $BALLERINA_KEYSTORE"
  exit 1
fi
if [ ! -f "$BALLERINA_TRUSTSTORE" ]; then
  echo "ERROR: Ballerina truststore not found at $BALLERINA_TRUSTSTORE"
  exit 1
fi

echo "================================================"
echo "6a. Ensuring cert-manager is installed"
echo "================================================"

if kubectl get deployment cert-manager -n cert-manager &>/dev/null; then
  echo "cert-manager already installed, skipping."
else
  echo "Installing cert-manager v1.14.0..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

  echo "Waiting for cert-manager to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
  kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
  kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
  echo "cert-manager is ready."
fi

echo ""
echo "================================================"
echo "6b. Deploying ICP (namespace: icp)"
echo "    Image: $ICP_IMAGE"
echo "    Ingress: icp.wso2.com → Nginx Ingress (HTTPS backend)"
echo "================================================"

kubectl create namespace icp --dry-run=client -o yaml | kubectl apply -f -

# Clean up any old NGINX Gateway Fabric resources from previous deployments
kubectl delete gateway icp-gateway -n icp --ignore-not-found=true
kubectl delete httproute icp-route -n icp --ignore-not-found=true
kubectl delete backendtlspolicy icp-backend-tls -n icp --ignore-not-found=true
kubectl delete configmap icp-backend-ca -n icp --ignore-not-found=true

kubectl apply -f "$ICP_K8S_DIR/icp-config.yaml"
# Patch the deployment image to match ICP_IMAGE (idempotent)
kubectl apply -f "$ICP_K8S_DIR/deployment.yaml"
kubectl set image deployment/icp-deployment icp-container="$ICP_IMAGE" -n icp 2>/dev/null || true
kubectl apply -f "$ICP_K8S_DIR/service.yaml"
kubectl apply -f "$ICP_K8S_DIR/issuer.yaml"
kubectl apply -f "$ICP_K8S_DIR/cert.yaml"
kubectl apply -f "$ICP_K8S_DIR/ingress.yaml"

echo "Waiting for ICP pod to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod -l app=icp -n icp || {
  echo "WARNING: ICP pod not ready within timeout. Check: kubectl get pods -l app=icp -n icp"
  echo "Continuing anyway..."
}

echo "Waiting for icp-cert to be ready..."
kubectl wait --for=condition=ready --timeout=60s certificate/icp-cert -n icp || {
  echo "WARNING: icp-cert not ready. Check: kubectl describe certificate icp-cert -n icp"
}

echo ""
echo "================================================"
echo "6c. Extracting ICP backend cert"
echo "     (for Ballerina integrations calling ICP over HTTPS)"
echo "================================================"

echo "Extracting ICP backend self-signed cert from pod..."
ICP_BACKEND_CERT=$(kubectl exec deployment/icp-deployment -n icp -- sh -c \
  'echo | openssl s_client -connect localhost:9445 2>/dev/null | openssl x509 -outform PEM')

if [ -z "$ICP_BACKEND_CERT" ]; then
  echo "ERROR: Could not extract ICP backend cert. Is the ICP pod running?"
  echo "Check: kubectl get pods -l app=icp -n icp"
  exit 1
fi

echo "$ICP_BACKEND_CERT" > "$ICP_BACKEND_CERT_FILE"
echo "ICP backend cert extracted."

echo ""
echo "================================================"
echo "6d. Importing ICP cert into Ballerina truststore"
echo "     (so integrations can call ICP over HTTPS)"
echo "================================================"

# Remove stale alias then re-import fresh cert
keytool -delete \
  -alias icp-backend \
  -keystore "$BALLERINA_TRUSTSTORE" \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt 2>/dev/null || true

keytool -importcert \
  -alias icp-backend \
  -file "$ICP_BACKEND_CERT_FILE" \
  -keystore "$BALLERINA_TRUSTSTORE" \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

echo "ICP cert imported into Ballerina truststore."

echo ""
echo "================================================"
echo "6e. Recreating ballerina-integration-secret"
echo "================================================"

kubectl delete secret ballerina-integration-secret -n ballerina --ignore-not-found=true
kubectl create secret generic ballerina-integration-secret \
  --from-file=keystore.p12="$BALLERINA_KEYSTORE" \
  --from-file=truststore.p12="$BALLERINA_TRUSTSTORE" \
  --from-file=ballerinaKeystore.p12="$BALLERINA_KEYSTORE" \
  --from-file=ballerinaTruststore.p12="$BALLERINA_TRUSTSTORE" \
  -n ballerina
echo "ballerina-integration-secret recreated."

echo ""
echo "================================================"
echo "6f. Restarting Ballerina integrations"
echo "================================================"

kubectl rollout restart deployment -n ballerina || true
kubectl rollout status deployment -n ballerina --timeout=120s || true

echo ""
echo "================================================"
echo "6g. Verifying deployment"
echo "================================================"

echo ""
kubectl get pods -l app=icp -n icp
echo ""
kubectl get svc,ingress,certificate -n icp

rm -f "$ICP_BACKEND_CERT_FILE"

echo ""
echo "================================================"
echo "ICP deployment complete."
echo ""
echo "Access:   https://icp.wso2.com"
echo "GraphQL:  https://icp.wso2.com/graphql"
echo ""
echo "Troubleshooting:"
echo "  kubectl logs -l app=icp -n icp --tail=100"
echo "  kubectl describe ingress icp-ingress -n icp"
echo "================================================"
