#!/bin/bash
set -e

# ========================================
# STEP 8: Deploy APK Kubernetes Gateway + Agent
# Run AFTER deploying the Control Plane (step 5)
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

kubectl get namespace apim-kgw &>/dev/null || kubectl create namespace apim-kgw

echo "================================================"
echo "8a. Deploying APK Kubernetes Gateway"
echo "================================================"

helm upgrade --install kgw \
  "$ROOT_DIR/k8_deployments/apk-gateway/apk-helm-1.3.0-1.tgz" \
  -n apim-kgw \
  -f "$ROOT_DIR/k8_deployments/apk-gateway/apk-min.yaml" || true

# If the release is in a failed state (cert-manager webhook timing race on first install),
# retry the upgrade now that cert-manager is running
KGW_STATUS=$(helm status kgw -n apim-kgw -o json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [[ "$KGW_STATUS" == "failed" ]]; then
  echo "kgw release in failed state — retrying upgrade..."
  helm upgrade kgw \
    "$ROOT_DIR/k8_deployments/apk-gateway/apk-helm-1.3.0-1.tgz" \
    -n apim-kgw \
    -f "$ROOT_DIR/k8_deployments/apk-gateway/apk-min.yaml"
fi

echo ""
echo "================================================"
echo "8b. Deploying APK Agent"
echo "================================================"

helm upgrade --install kgw-agent \
  "$ROOT_DIR/k8_deployments/apk-agent/apim-apk-agent-1.3.1.tgz" \
  -n apim-kgw \
  -f "$ROOT_DIR/k8_deployments/apk-agent/apk-agent-min.yaml"

echo ""
echo "================================================"
echo "Verifying Token Issuers"
echo "================================================"
kubectl get tokenissuer -n apim-kgw
