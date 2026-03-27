#!/bin/bash
set -e

NAMESPACE="ballerina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEYSTORE_DIR="/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/integration"
NEW_KEYS_DIR="/Users/ramindu/wso2/general_demo/demo_resources/k8-artefacts-apim-bi-elk/create_deployments/new_keys"

echo "================================================"
echo "  Deploy insurance_agent (arm64)"
echo "================================================"

echo ""
echo "--- Building Ballerina project ---"
cd "$SCRIPT_DIR"
/Library/Ballerina/bin/bal clean
/Library/Ballerina/bin/bal build

# Derive image name/tag from what the build just produced
IMAGE=$(grep 'image:' "$SCRIPT_DIR/target/kubernetes/insurance_agent/insurance_agent.yaml" | head -1 | awk '{print $2}' | tr -d '"')

echo ""
echo "--- Docker login ---"
docker login

echo ""
echo "--- Build arm64 image & push ($IMAGE) ---"
docker build \
  -t "$IMAGE" \
  "$SCRIPT_DIR/target/docker/insurance_agent/"

docker push "$IMAGE"

echo ""
echo "--- Adding certs to truststore ---"

# Gateway internal cert (gw-wso2am-universal-gw-service.apim-gw.svc.cluster.local)
keytool -delete -alias gw-internal-cert -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 -storepass ballerina -noprompt 2>/dev/null || true
keytool -importcert \
  -alias gw-internal-cert \
  -file "$NEW_KEYS_DIR/wso2carbon-gw.crt" \
  -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

# Gateway ingress cert
keytool -delete -alias gw-ingress-cert -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 -storepass ballerina -noprompt 2>/dev/null || true
keytool -importcert \
  -alias gw-ingress-cert \
  -file "$NEW_KEYS_DIR/gw-ingress.crt" \
  -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

# IS ingress cert (is.wso2.com)
keytool -delete -alias is-ingress-cert -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 -storepass ballerina -noprompt 2>/dev/null || true
keytool -importcert \
  -alias is-ingress-cert \
  -file "$NEW_KEYS_DIR/is-ingress.crt" \
  -keystore "$KEYSTORE_DIR/truststore.p12" \
  -storetype PKCS12 \
  -storepass ballerina \
  -noprompt

echo ""
echo "--- Recreating ballerina-integration-secret ---"
kubectl delete secret ballerina-integration-secret -n "$NAMESPACE" --ignore-not-found=true
kubectl create secret generic ballerina-integration-secret \
  --from-file=keystore.p12="$KEYSTORE_DIR/keystore.p12" \
  --from-file=truststore.p12="$KEYSTORE_DIR/truststore.p12" \
  -n "$NAMESPACE"
echo "ballerina-integration-secret created"

echo ""
echo "--- Applying secrets ---"
kubectl apply -f "$SCRIPT_DIR/ballerina-insurance-agent-secrets.yaml"

echo ""
echo "--- Applying ConfigMap ---"
kubectl apply -f "$SCRIPT_DIR/config-map-insurance_agent.yaml" -n "$NAMESPACE"

echo ""
echo "--- Applying generated Kubernetes deployment ---"
kubectl apply -f "$SCRIPT_DIR/target/kubernetes/insurance_agent/insurance_agent.yaml" -n "$NAMESPACE"

echo ""
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

echo ""
echo "--- Setting maxReplicas to 1 ---"
kubectl patch hpa insurance-agent -n "$NAMESPACE" --patch '{"spec":{"maxReplicas":1}}' || true

echo ""
echo "--- Restarting deployment to pick up changes ---"
kubectl rollout restart deployment/insurance-agent-deployment -n "$NAMESPACE"
kubectl rollout status deployment/insurance-agent-deployment -n "$NAMESPACE" --timeout=120s

echo ""
echo "================================================"
echo "  Done! Namespace: $NAMESPACE"
echo ""
echo "  Insurance Agent:"
echo "    Chat API:           POST /insurance_agent/chat"
echo "    Privileged Chat:    POST /insurance_agent/privilege_chat"
echo "    Port:               9090"
echo "================================================"
