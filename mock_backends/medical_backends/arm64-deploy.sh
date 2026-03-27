#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="0.3.0"
IMAGE="ramilu90/medical_backends:${IMAGE_TAG}"

echo "================================================"
echo "  Deploy medical_backends (arm64)"
echo "================================================"

echo ""
echo "--- Building Ballerina project ---"
cd "$SCRIPT_DIR"
/Users/ramindu/Downloads/ballerina-2201.13.2/bin/bal clean
/Users/ramindu/Downloads/ballerina-2201.13.2/bin/bal build

echo ""
echo "--- Docker login ---"
docker login

echo ""
echo "--- Build arm64 image & push ---"
docker build \
  -t "$IMAGE" \
  "$SCRIPT_DIR/target/docker/medical_backends/"

docker push "$IMAGE"

echo ""
echo "--- Applying Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/medical-backends-k8s.yaml" -n "$NAMESPACE"

echo ""
echo "--- Patching Deployment (replicas) ---"
DEPLOYMENT="medical-backends"
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --patch "
spec:
  replicas: 1
"

echo ""
echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/$DEPLOYMENT -n "$NAMESPACE"
kubectl rollout status deployment/$DEPLOYMENT -n "$NAMESPACE" --timeout=120s

echo ""
echo "================================================"
echo "  Done! Namespace: $NAMESPACE"
echo ""
echo "  Medical Backend Services:"
echo "  medical-patient-services – port 9201"
echo "    GET  /patients, /appointments, /prescriptions, /labs"
echo "  medical-provider-services – port 9205"
echo "    GET  /pharmacy/medications, /doctors, /doctors/hospitals, /insurance/{patientId}"
echo "================================================"
