#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "--- Building ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo "--- Applying generated deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/insurance_backend/insurance_backend.yaml" -n "$NAMESPACE"

echo "--- Applying services and HPA ---"
kubectl apply -f "$SCRIPT_DIR/insurance_backend-k8s.yaml"

echo "--- Setting maxReplicas to 1 ---"
kubectl patch hpa insurance-backend-hpa -n "$NAMESPACE" --patch '{"spec":{"maxReplicas":1}}'

echo "--- Applying config map ---"
kubectl apply -f "$SCRIPT_DIR/config-map-insurance_backend.yaml"

echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/insurance-backend-deployment -n "$NAMESPACE"
kubectl rollout status deployment/insurance-backend-deployment -n "$NAMESPACE"

echo "--- Done ---"
echo "All resources applied to namespace: $NAMESPACE"
