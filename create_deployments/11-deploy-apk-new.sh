#!/bin/bash
set -e

# ========================================
# Deploy WSO2 APK Data Plane + APIM-APK Agent
# (Includes Kubelet Security Hotfixes, Deadlock bypass, IDP TLS Trust, and Double Tap)
# ========================================

APK_NS="apim-kgw"
APK_RELEASE="kgw"
AGENT_RELEASE="apim-apk-agent"
AGENT_VERSION="1.3.0"
ACP_NS="apim-cp"
ACP_SVC="acp-wso2am-acp-service"

# File Paths
CHART_PATH="k8_deployments/apk-gateway/apk-helm-1.3.0-1.tgz"
VALUES_FILE="k8_deployments/apk-gateway/apk-min.yaml"
TLS_CERT_PATH="create_deployments/new_keys/is-ingress.crt"

echo "========================================================="
echo "🚀 Initiating WSO2 APK Clean Redeployment..."
echo "========================================================="

echo -e "\n🧹 [1/7] Force-uninstalling broken releases..."
helm uninstall "$AGENT_RELEASE" -n "$APK_NS" --ignore-not-found || true
helm uninstall "$APK_RELEASE" -n "$APK_NS" --no-hooks --ignore-not-found || true

echo -e "\n✂️  [2/7] Nuking lingering webhooks and old CA secrets..."
kubectl get validatingwebhookconfigurations -o name | grep -iE 'cert-manager|gateway|apk' | xargs -I {} kubectl delete {} --ignore-not-found=true || true
kubectl get mutatingwebhookconfigurations -o name | grep -iE 'cert-manager|gateway|apk' | xargs -I {} kubectl delete {} --ignore-not-found=true || true
kubectl delete jobs -n "$APK_NS" --all --ignore-not-found=true || true
# Clean old webhook CA secrets so the injector starts fresh
kubectl get secrets -n "$APK_NS" | grep -i "cert-manager-webhook" | awk '{print $1}' | xargs -I {} kubectl delete secret {} -n "$APK_NS" --ignore-not-found=true || true

# Ensure namespace exists
kubectl create namespace "$APK_NS" --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n🔐 [3/7] Creating IDP TLS Trust Secret for Enforcer..."
kubectl delete secret wso2apk-idp-certificates -n "$APK_NS" --ignore-not-found=true
if [ -f "$TLS_CERT_PATH" ]; then
  kubectl create secret generic wso2apk-idp-certificates \
    -n "$APK_NS" \
    --from-file=idp.crt="$TLS_CERT_PATH"
  echo "TLS Secret created successfully!"
else
  echo "⚠️ WARNING: TLS certificate not found at $TLS_CERT_PATH! Enforcer may fail JWKS fetch."
fi

echo -e "\n🚧 [4/7] STAGE 1: Bootstrapping Infrastructure (Bypassing Deadlock)..."
helm upgrade --install "$APK_RELEASE" "$CHART_PATH" \
  -n "$APK_NS" \
  -f "$VALUES_FILE" \
  --set wso2.apk.dp.enabled=false \
  --set certmanager.enableClusterIssuer=false \
  --set certmanager.enableRootCa=false \
  --set gatewaySystem.applyGatewayWehbhookJobs=false \
  --no-hooks

echo -e "\n🩹 [5/7] STAGE 1.5: Injecting Hotfix to bypass Kubelet Security Block..."
sleep 5 

echo "Patching cert-manager components to run as User 1001..."
PATCH_JSON='{"spec": {"template": {"spec": {"securityContext": {"runAsUser": 1001}, "containers": [{"name": "cert-manager-controller", "securityContext": {"runAsUser": 1001}}]}}}}'
kubectl patch deployment kgw-cert-manager -n "$APK_NS" --patch "$PATCH_JSON" || true

PATCH_JSON_WH='{"spec": {"template": {"spec": {"securityContext": {"runAsUser": 1001}, "containers": [{"name": "cert-manager-webhook", "securityContext": {"runAsUser": 1001}}]}}}}'
kubectl patch deployment kgw-cert-manager-webhook -n "$APK_NS" --patch "$PATCH_JSON_WH" || true

PATCH_JSON_CA='{"spec": {"template": {"spec": {"securityContext": {"runAsUser": 1001}, "containers": [{"name": "cert-manager-cainjector", "securityContext": {"runAsUser": 1001}}]}}}}'
kubectl patch deployment kgw-cert-manager-cainjector -n "$APK_NS" --patch "$PATCH_JSON_CA" || true

echo "Waiting for Webhooks to become healthy (this may take a minute)..."
kubectl rollout status deployment/kgw-cert-manager-webhook -n "$APK_NS" --timeout=90s || true
kubectl rollout status deployment/kgw-cert-manager-cainjector -n "$APK_NS" --timeout=90s || true

echo "Giving cainjector 20 seconds to initially inject the CA bundles into the K8s API..."
sleep 20

echo -e "\n📦 [6/7] STAGE 2: Applying Custom Resources (The Double Tap)..."
echo "Applying Data Plane and Certs (Run 1 - Expecting x509 warning)..."
helm upgrade --install "$APK_RELEASE" "$CHART_PATH" \
  -n "$APK_NS" \
  -f "$VALUES_FILE" || true

echo "Helm may have just wiped the K8s API trust! Waiting for cainjector to repatch it..."
echo "Polling until webhook CA bundle is injected (up to 90s)..."
for i in $(seq 1 18); do
  CA=$(kubectl get validatingwebhookconfiguration kgw-cert-manager-webhook \
    -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null)
  if [ -n "$CA" ]; then
    echo "CA bundle injected after $((i*5))s. Proceeding..."
    break
  fi
  sleep 5
done

echo "Trust should be restored. Running Stage 2 one final time..."
# Run 2: Trust is back. Helm successfully applies everything.
helm upgrade --install "$APK_RELEASE" "$CHART_PATH" \
  -n "$APK_NS" \
  -f "$VALUES_FILE"

echo -e "\n📡 [7/7] Installing APIM-APK Agent ${AGENT_VERSION}..."
helm repo add wso2apkagent "https://github.com/wso2/product-apim-tooling/releases/download/${AGENT_VERSION}" 2>/dev/null || true
helm repo update wso2apkagent

helm upgrade --install "$AGENT_RELEASE" wso2apkagent/apim-apk-agent \
  --version "$AGENT_VERSION" \
  -n "$APK_NS" \
  --set controlPlane.enabled=true \
  --set controlPlane.serviceURL="https://${ACP_SVC}.${ACP_NS}.svc.cluster.local:9443/" \
  --set controlPlane.username=admin \
  --set controlPlane.password=admin \
  --set controlPlane.environmentLabels="APK-GW" \
  --set controlPlane.skipSSLVerification=true \
  --set "controlPlane.eventListeningEndpoints=amqp://admin:admin@${ACP_SVC}.${ACP_NS}.svc.cluster.local:5672?retries='10'&connectdelay='30'" \
  --set dataPlane.enabled=true \
  --set dataPlane.k8ResourceEndpoint="https://kgw-wso2-apk-config-ds-service.${APK_NS}.svc.cluster.local:9443/api/configurator/apis/generate-k8s-resources" \
  --set dataPlane.namespace="$APK_NS" \
  --set agent.mode=CPtoDP \
  --set certmanager.enabled=false \
  --timeout 5m0s --wait

echo -e "\n🔐 [7.5/8] Granting wso2agent-platform cluster-scope access to dp.wso2.com CRDs..."
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: wso2agent-platform-dp-crd-reader
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: wso2agent-platform-dp-crd-reader-binding
subjects:
- kind: ServiceAccount
  name: wso2agent-platform
  namespace: apim-kgw
roleRef:
  kind: ClusterRole
  name: wso2agent-platform-dp-crd-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo -e "\n🔑 [8/8] Patching IS TokenIssuers with JWKS TLS certificate..."
echo "Waiting for TokenIssuers to be created by APK agent (up to 60s)..."
for i in $(seq 1 12); do
  COUNT=$(kubectl get tokenissuer -n "$APK_NS" --no-headers 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    echo "TokenIssuers found ($COUNT). Applying JWKS TLS cert patch..."
    break
  fi
  sleep 5
done

TLS_PATCH='{
  "spec": {
    "signatureValidation": {
      "jwks": {
        "tls": {
          "secretRef": {
            "name": "wso2apk-idp-certificates",
            "key": "idp.crt"
          }
        }
      }
    }
  }
}'

# Patch all IS-issuer TokenIssuers (both chart-created and agent-created from CP)
for TI in $(kubectl get tokenissuer -n "$APK_NS" -o json 2>/dev/null \
    | python3 -c "
import sys, json
items = json.load(sys.stdin).get('items', [])
for ti in items:
    issuer = ti.get('spec', {}).get('issuer', '')
    if 'is.wso2.com' in issuer:
        print(ti['metadata']['name'])
"); do
  kubectl patch tokenissuer "$TI" -n "$APK_NS" --type=merge -p "$TLS_PATCH" 2>&1 \
    && echo "Patched TokenIssuer: $TI"
done

echo -e "\n✅ Deployment completed successfully!"
echo "========================================================="
sleep 3
kubectl get pods -n "$APK_NS"