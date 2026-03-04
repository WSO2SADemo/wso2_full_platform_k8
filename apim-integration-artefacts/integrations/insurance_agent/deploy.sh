#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "--- Building ballerina project ---"
cd "$SCRIPT_DIR"
bal clean
bal build

echo "--- Applying generated deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/insurance_agent/insurance_agent.yaml" -n "$NAMESPACE"

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

echo "--- Applying secrets ---"
kubectl apply -f "$SCRIPT_DIR/ballerina-insurance-agent-secrets.yaml"

echo "--- Applying config map ---"
kubectl apply -f "$SCRIPT_DIR/config-map-insurance_agent.yaml"

echo "--- Patching deployment to mount keystore/truststore ---"
kubectl patch deployment insurance-agent-deployment -n "$NAMESPACE" --patch '
spec:
  template:
    spec:
      volumes:
      - name: keystore-vol
        secret:
          secretName: ballerina-integration-secret
      containers:
      - name: insurance-agent-deployment
        volumeMounts:
        - name: keystore-vol
          mountPath: /home/ballerina/bre/security
          readOnly: true
'

echo "--- Setting maxReplicas to 1 ---"
kubectl patch hpa insurance-agent -n "$NAMESPACE" --patch '{"spec":{"maxReplicas":1}}'

echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/insurance-agent-deployment -n "$NAMESPACE"
kubectl rollout status deployment/insurance-agent-deployment -n "$NAMESPACE"

echo "--- Done ---"
echo "All resources applied to namespace: $NAMESPACE"
