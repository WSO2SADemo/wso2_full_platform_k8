#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="1.0.3"

echo "================================================"
echo "  Deploy customer_backends"
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
  -t "ramilu90/customer_backends:${IMAGE_TAG}" \
  --push \
  "$SCRIPT_DIR/target/docker/customer_backends/"

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/customer_backends/" -n "$NAMESPACE"

echo ""
echo "--- Ensuring Service exists ---"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: customer-backends
  namespace: $NAMESPACE
  labels:
    app: customer_backends
spec:
  type: ClusterIP
  selector:
    app: customer_backends
  ports:
    - name: fund1-aea
      port: 9091
      targetPort: 9091
      protocol: TCP
    - name: fund2-unionen
      port: 9092
      targetPort: 9092
      protocol: TCP
    - name: fund3-akademikernas
      port: 9093
      targetPort: 9093
      protocol: TCP
    - name: fund4-ifmetall
      port: 9094
      targetPort: 9094
      protocol: TCP
    - name: fund5-kommunal
      port: 9095
      targetPort: 9095
      protocol: TCP
    - name: fund6-handels
      port: 9096
      targetPort: 9096
      protocol: TCP
    - name: fund7-vision
      port: 9097
      targetPort: 9097
      protocol: TCP
    - name: fund8-transport
      port: 9098
      targetPort: 9098
      protocol: TCP
    - name: fund9-seko
      port: 9099
      targetPort: 9099
      protocol: TCP
    - name: fund10-fastighets
      port: 9100
      targetPort: 9100
      protocol: TCP
    - name: fund11-notification
      port: 9101
      targetPort: 9101
      protocol: TCP
    - name: order-customer-profile
      port: 9110
      targetPort: 9110
      protocol: TCP
    - name: order-inventory
      port: 9111
      targetPort: 9111
      protocol: TCP
    - name: order-pricing
      port: 9112
      targetPort: 9112
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
DEPLOYMENT="customer-backen-deployment"
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
echo "  Fund services (lookup): ports 9091-9100"
echo "  Fund 7 & 8 : HIGH LATENCY (3.5s / 4.0s) – trigger client timeout"
echo "  Fund 9     : always HTTP 500 (error)"
echo "  Fund 10    : always empty 200 (blank)"
echo "  Fund 11    : Notification Receiver – port 9101"
echo "    POST /notifications               – receive notification from store-and-forward"
echo "    POST /notifications/admin/toggle  – toggle online/offline (simulate outage)"
echo "    GET  /notifications/admin/status  – check availability"
echo ""
echo "  Order Pipeline backends:"
echo "  Customer Profile Service  – port 9110"
echo "    GET  /customer/profile/{customerId}  (CUST-001 GOLD / CUST-002 SILVER / CUST-003 BRONZE)"
echo "  Inventory Service         – port 9111"
echo "    POST /inventory/check   (PROD-A1 Laptop / PROD-B2 Mouse / PROD-C3 Hub (OOS) / PROD-D4 Monitor)"
echo "  Pricing Service           – port 9112"
echo "    POST /pricing/calculate (tier discount + warehouse shipping + credit-limit payment terms)"
echo "================================================"
