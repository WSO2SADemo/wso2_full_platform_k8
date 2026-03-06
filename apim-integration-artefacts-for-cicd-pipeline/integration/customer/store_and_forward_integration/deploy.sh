#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================"
echo "  Deploy Store-and-Forward Integration"
echo "================================================"

echo ""
echo "--- Building Ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/store_and_forward_integration/store_and_forward_integration.yaml" -n "$NAMESPACE"

echo ""
echo "--- Applying custom K8s resources (Service, HPA, Namespace) ---"
kubectl apply -f "$SCRIPT_DIR/store_and_forward_integration-k8s.yaml"

echo ""
echo "--- Creating ballerina-integration-secret if not found ---"
if ! kubectl get secret ballerina-integration-secret -n "$NAMESPACE" > /dev/null 2>&1; then
  kubectl create secret generic ballerina-integration-secret \
    --from-file=keystore.p12=/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/integration/keystore.p12 \
    --from-file=truststore.p12=/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/integration/truststore.p12 \
    -n "$NAMESPACE"
  echo "ballerina-integration-secret created"
else
  echo "ballerina-integration-secret already exists, skipping"
fi

echo ""
echo "--- Applying ConfigMap ---"
kubectl apply -f "$SCRIPT_DIR/config-map-store_and_forward_integration.yaml"

echo ""
echo "--- Patching deployment to mount keystore/truststore ---"
kubectl patch deployment store-and-forward-integration-deployment -n "$NAMESPACE" --patch '
spec:
  template:
    spec:
      volumes:
      - name: keystore-vol
        secret:
          secretName: ballerina-integration-secret
      containers:
      - name: store-and-forward-integration-deployment
        volumeMounts:
        - name: keystore-vol
          mountPath: /home/ballerina/bre/security
          readOnly: true
'

echo ""
echo "--- Restarting deployment to pick up latest config ---"
kubectl rollout restart deployment/store-and-forward-integration-deployment -n "$NAMESPACE"
kubectl rollout status deployment/store-and-forward-integration-deployment -n "$NAMESPACE"

echo ""
echo "================================================"
echo "  Done!"
echo "  Namespace : $NAMESPACE"
echo "  HTTP API  : http://store-and-forward-integration.ballerina.svc.cluster.local:9085"
echo ""
echo "  Endpoints:"
echo "    POST /notifications/send       – queue a notification (returns 202)"
echo "    POST /notifications/retry      – manually retry oldest DLQ message"
echo "    GET  /notifications/dlq-status – list DLQ messages pending manual retry"
echo "================================================"
