#!/bin/bash
set -e

# ========================================
# STEP 5: Deploy APIM Gateways (Internal + External)
# Run AFTER CP is up and truststores are updated
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "5a. Deploying Internal Gateway (gw)"
echo "================================================"

helm uninstall gw -n apim-gw 2>/dev/null || true

helm install gw "$ROOT_DIR/k8_deployments/am-gateway/wso2am-universal-gw" \
  -n apim-gw \
  -f "$ROOT_DIR/k8_deployments/am-gateway/gw-min.yaml"

echo "Waiting for internal GW pod to be ready..."
kubectl rollout status deployment -l app=wso2am-universal-gw,release=gw -n apim-gw --timeout=300s || {
  echo "Internal GW not ready yet. Check: kubectl get pods -n apim-gw"
}

echo "================================================"
echo "5b. Deploying External Gateway (extgw)"
echo "================================================"

helm uninstall extgw -n apim-gw 2>/dev/null || true

helm install extgw "$ROOT_DIR/k8_deployments/am-gateway/wso2am-universal-gw" \
  -n apim-gw \
  -f "$ROOT_DIR/k8_deployments/am-gateway/extgw-min.yaml"

echo "Waiting for external GW pod to be ready..."
kubectl rollout status deployment -l app=wso2am-universal-gw,release=extgw -n apim-gw --timeout=300s || {
  echo "External GW not ready yet. Check: kubectl get pods -n apim-gw"
}

echo ""
echo "Both gateways deployed."
echo "Verify: kubectl get pods -n apim-gw"
echo "Ingresses: kubectl get ingress -n apim-gw"
