#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="0.3.0"

echo "================================================"
echo "  Deploy medical_backends"
echo "================================================"

echo ""
echo "--- Building Ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo ""
echo "--- Docker login ---"
docker login

echo ""
echo "--- Build linux/amd64 image & push (cross-platform for AKS) ---"
docker buildx build \
  --platform linux/amd64 \
  -t "ramilu90/medical_backends:${IMAGE_TAG}" \
  --push \
  "$SCRIPT_DIR/target/docker/medical_backends/"

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
echo "    GET  /patients                          – list all patients"
echo "    GET  /patients/{patientId}              – get patient (P001–P004)"
echo "    GET  /appointments/patient/{patientId}  – list appointments"
echo "    POST /appointments                      – book appointment"
echo "    GET  /prescriptions/patient/{id}/active – active prescriptions"
echo "    GET  /labs/patient/{patientId}/abnormal – abnormal lab results"
echo ""
echo "  medical-provider-services – port 9205"
echo "    GET  /pharmacy/medications              – list medications"
echo "    POST /pharmacy/dispense                 – dispense prescription"
echo "    GET  /doctors                           – list doctors"
echo "    GET  /doctors/hospitals                 – list hospitals"
echo "    GET  /insurance/{patientId}             – get coverage"
echo "================================================"
