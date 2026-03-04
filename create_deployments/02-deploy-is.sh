#!/bin/bash
set -e

# ========================================
# STEP 2: Deploy WSO2 Identity Server
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "2. Deploying WSO2 Identity Server"
echo "================================================"

# Uninstall existing release if any
helm uninstall wso2is -n iam 2>/dev/null || true

# Install IS
helm install wso2is "$ROOT_DIR/k8_deployments/kubernetes-is" -n iam -f "$ROOT_DIR/k8_deployments/kubernetes-is/values.yaml"

echo ""
echo "Waiting for IS pod to be ready..."
kubectl rollout status deployment/wso2is-identity-server -n iam --timeout=300s || {
  echo "IS not ready yet. Check with: kubectl get pods -n iam"
  echo "Logs: kubectl logs -f deployment/wso2is-identity-server -n iam"
}

# Patch service
echo "Patching IS service..."
kubectl patch svc wso2is-identity-server -n iam --patch-file "$ROOT_DIR/k8_deployments/kubernetes-is/patch-iam-service.yaml"

echo ""
echo "IS deployed. Verify: kubectl get pods -n iam"
echo "Ingress: kubectl get ingress -n iam"
