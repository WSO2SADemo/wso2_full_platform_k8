#!/bin/bash
set -e

# ========================================
# STEP 3: Deploy APIM Control Plane
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "3. Deploying APIM Control Plane"
echo "================================================"

# Uninstall existing release if any
helm uninstall acp -n apim-cp 2>/dev/null || true

# Install CP
helm install acp "$ROOT_DIR/k8_deployments/am-control-plane/wso2am-acp" \
  -n apim-cp \
  -f "$ROOT_DIR/k8_deployments/am-control-plane/acp-min.yaml"

echo ""
echo "Waiting for CP pod to be ready..."
kubectl rollout status deployment -n apim-cp --timeout=300s || {
  echo "CP not ready yet. Check with: kubectl get pods -n apim-cp"
  echo "Logs: kubectl logs -f -l app=wso2am-acp -n apim-cp"
}

# Patch service to expose additional ports
echo "Patching CP service..."
kubectl patch svc acp-wso2am-acp-service -n apim-cp --patch-file "$ROOT_DIR/k8_deployments/am-control-plane/patch-acp-service.yaml"

echo ""
echo "CP deployed. Verify: kubectl get pods -n apim-cp"
echo "Ingress: kubectl get ingress -n apim-cp"
