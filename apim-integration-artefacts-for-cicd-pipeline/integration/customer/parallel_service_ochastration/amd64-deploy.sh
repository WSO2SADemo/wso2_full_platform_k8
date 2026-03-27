#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="1.0.18"

echo "================================================"
echo "  Deploy parallel_service_ochastration_integration"
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
echo "--- Build linux/amd64 image & push (cross-platform for AKS) ---"
docker buildx build \
  --platform linux/amd64 \
  -t "ramilu90/parallel_service_ochastration_integration:${IMAGE_TAG}" \
  --push \
  "$SCRIPT_DIR/target/docker/parallel_service_ochastration_integration/"

echo ""
echo "--- Applying ConfigMap ---"
kubectl apply -f "$SCRIPT_DIR/config-map-parallel_service_ochastration.yaml" -n "$NAMESPACE"

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/parallel_service_ochastration_integration/" -n "$NAMESPACE"

echo ""
echo "--- Ensuring Service exists ---"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: parallel-service-ochastration
  namespace: $NAMESPACE
  labels:
    app: parallel_service_ochastration_integration
spec:
  type: ClusterIP
  selector:
    app: parallel_service_ochastration_integration
  ports:
    - name: orchestration
      port: 9090
      targetPort: 9090
      protocol: TCP
    - name: management
      port: 9264
      targetPort: 9264
      protocol: TCP
EOF

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
echo "--- Applying ConfigMap ---"
kubectl apply -f config-map-parallel_service_ochastration.yaml

echo ""
echo "--- Patching Deployment (keystore volume) ---"
DEPLOYMENT="parallel-servic-deployment"
CONTAINER_NAME=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].name}')

kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --patch "
spec:
  replicas: 1
  template:
    spec:
      volumes:
      - name: keystore-vol
        secret:
          secretName: ballerina-integration-secret
      containers:
      - name: $CONTAINER_NAME
        volumeMounts:
        - name: keystore-vol
          mountPath: /home/ballerina/bre/security
          readOnly: true
"

echo ""
echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/$DEPLOYMENT -n "$NAMESPACE"
kubectl rollout status deployment/$DEPLOYMENT -n "$NAMESPACE" --timeout=120s

echo ""
echo "================================================"
echo "  Done! Namespace: $NAMESPACE"
echo ""
echo "  Scatter-Gather orchestration: port 9090"
echo "    POST /unemployment/lookup   – fan-out to all 10 fund backends"
echo "================================================"
