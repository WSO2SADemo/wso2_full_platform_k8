#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================"
echo "  Deploy service_ochastration_backends"
echo "================================================"

echo ""
echo "--- Building Ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/service_ochastration_backends/service_ochastration_backends.yaml" -n "$NAMESPACE"

echo ""
echo "--- Creating ballerina-integration-secret if not found ---"
if ! kubectl get secret ballerina-integration-secret -n "$NAMESPACE" > /dev/null 2>&1; then
  kubectl create secret generic ballerina-integration-secret \
    --from-file=ballerinaKeystore.p12=/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/integration/keystore.p12 \
    --from-file=ballerinaTruststore.p12=/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/integration/truststore.p12 \
    -n "$NAMESPACE"
  echo "ballerina-integration-secret created"
else
  echo "ballerina-integration-secret already exists, skipping"
fi

echo ""
echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/service-ochastration-backends-deployment -n "$NAMESPACE"
kubectl rollout status deployment/service-ochastration-backends-deployment -n "$NAMESPACE"

echo ""
echo "================================================"
echo "  Done! Namespace: $NAMESPACE"
echo ""
echo "  Fund services (lookup): ports 9091-9100"
echo "  Fund 7 & 8 : HIGH LATENCY (3.5s / 4.0s) – trigger client timeout"
echo "  Fund 9     : always HTTP 500 (error)"
echo "  Fund 10    : always empty 200 (blank)"
echo "  Fund 11    : Notification Receiver – port 9101"
echo "    POST /notifications            – receive notification from store-and-forward"
echo "    POST /notifications/admin/toggle  – toggle online/offline (simulate outage)"
echo "    GET  /notifications/admin/status  – check availability"
echo "================================================"
