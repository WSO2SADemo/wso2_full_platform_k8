#!/bin/bash
set -e

# ========================================
# STEP 7: Deploy OpenTelemetry Collector
# Run BEFORE deploying gateways so the OTLP endpoint is ready
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "7. Deploying OpenTelemetry Collector"
echo "================================================"

helm uninstall otel-collector -n apim-gw 2>/dev/null || true

helm install otel-collector "$ROOT_DIR/k8_deployments/otel-collector" \
  -n apim-gw

echo "Waiting for OTel Collector pod to be ready..."
kubectl rollout status deployment/otel-collector -n apim-gw --timeout=120s || {
  echo "OTel Collector not ready yet. Check: kubectl get pods -n apim-gw"
}

echo ""
echo "Deployment complete."
echo "Verify: kubectl get pods -n apim-gw -l app=otel-collector"
echo "Service: kubectl get svc otel-collector -n apim-gw"
