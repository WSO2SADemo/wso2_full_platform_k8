#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "--- Building ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo "--- Applying generated deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/bank_backend/bank_backend.yaml" -n "$NAMESPACE"

echo "--- Applying services, namespace and HPA ---"
kubectl apply -f "$SCRIPT_DIR/bank_backend-k8s.yaml"

echo "--- Applying secrets ---"
kubectl apply -f "$SCRIPT_DIR/ballerina-bank-backend-secrets.yaml"

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

echo "--- Applying config map ---"
kubectl apply -f "$SCRIPT_DIR/config-map-bank_backend.yaml"

echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/bank-backend-deployment -n "$NAMESPACE"
kubectl rollout status deployment/bank-backend-deployment -n "$NAMESPACE"

echo "--- Done ---"
echo "All resources applied to namespace: $NAMESPACE"
