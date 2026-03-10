#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="1.0.4"
IMAGE_NAME="purchase_service_orchestration_pipeline"

echo "================================================"
echo "  Deploy error_handling_integration"
echo "  (Service Orchestration Pipeline – 3 steps)"
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
  -t "ramilu90/${IMAGE_NAME}:${IMAGE_TAG}" \
  --push \
  "$SCRIPT_DIR/target/docker/${IMAGE_NAME}/"

echo ""
echo "--- Applying ConfigMap ---"
kubectl apply -f "$SCRIPT_DIR/config-map-error-handling.yaml" -n "$NAMESPACE"

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/${IMAGE_NAME}/" -n "$NAMESPACE"

echo ""
echo "--- Ensuring Service exists ---"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: error-handling-integration
  namespace: $NAMESPACE
  labels:
    app: ${IMAGE_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${IMAGE_NAME}
  ports:
    - name: orders
      port: 9086
      targetPort: 9086
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
echo "--- Patching Deployment (keystore volume) ---"
DEPLOYMENT="purchase-servic-deployment"
CONTAINER_NAME=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].name}')

kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" --patch "
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
echo "--- Injecting RabbitMQ credentials from secret ---"
kubectl set env deployment/"$DEPLOYMENT" \
  --from=secret/rabbitmq-credentials \
  --keys=RABBITMQ_USER,RABBITMQ_PASSWORD \
  -n "$NAMESPACE" --overwrite

echo ""
echo "--- Injecting ConfigMap env vars ---"
kubectl set env deployment/"$DEPLOYMENT" \
  --from=configmap/ballerina-values-error-handling-flow \
  -n "$NAMESPACE" --overwrite

echo ""
echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE"
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s

echo ""
echo "================================================"
echo "  Done! Namespace: $NAMESPACE"
echo ""
echo "  Service Orchestration Pipeline: port 9086"
echo "    POST /orders/process  – 3-step pipeline:"
echo "      Step 1: GET  /customer/profile/{id}   (port 9110)"
echo "      Step 2: POST /pricing/calculate        (port 9112)"
echo "      Step 3: POST /purchase/confirm         (port 9113)"
echo "================================================"
