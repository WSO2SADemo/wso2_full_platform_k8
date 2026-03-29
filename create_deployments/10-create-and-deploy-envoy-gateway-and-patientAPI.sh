#!/bin/bash
set -e

# ========================================
# STEP 10: Deploy Envoy Gateway + Patient APIs + APIM Common Agent
#
# Idempotent — safe to rerun. Each section
# deletes existing resources before recreating.
#
# Deploys:
#   - Envoy Gateway controller (envoy-gateway-system)
#   - Self-signed TLS cert for envoygw.wso2.com
#   - IS CA cert ConfigMap for JWKS TLS trust
#   - GatewayClass, Gateway, ReferenceGrants
#   - HTTPRoute: /patients /appointments /prescriptions /labs
#   - SecurityPolicy: JWT via WSO2 IS
#   - CoreDNS update: envoygw.wso2.com → Envoy proxy ClusterIP
#   - APIM Common Agent: discovers HTTPRoutes and syncs to APIM Publisher
#
# NOTE: After this script, add envoygw.wso2.com to your /etc/hosts on your Mac
#   (same IP as is.wso2.com, gw.wso2.com etc.)
#
# PREREQUISITE: Add EnvoyGateway environment in APIM Admin UI first:
#   https://cp.wso2.com/admin/settings/environments
#   Name: EG, Type: Envoy Gateway, Vhost: envoygw.wso2.com
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EG_DIR="$ROOT_DIR/k8_deployments/envoy-gateway"

EG_NS="envoy-gateway-system"
EG_VERSION="v1.3.0"
GW_NAME="envoy-gateway"
GW_HOST="envoygw.wso2.com"
TLS_SECRET="envoygw-tls"
IS_NS="iam"
IS_SVC="wso2is-identity-server"
ACP_NS="apim-cp"
ACP_SVC="acp-wso2am-acp-service"
AGENT_RELEASE="apim-eg-agent"
AGENT_CHART_VERSION="1.0.0-beta"

echo "================================================"
echo "10. Deploy Envoy Gateway + Patient APIs"
echo "================================================"

# ─── Teardown: delete everything before recreating ────────────────────────────
echo ""
echo "--- Tearing down existing Envoy Gateway resources ---"

# Uninstall APIM Common Agent first
if helm status "$AGENT_RELEASE" -n "$EG_NS" &>/dev/null; then
  echo "  Uninstalling Helm release '${AGENT_RELEASE}' in ${EG_NS}..."
  helm uninstall "$AGENT_RELEASE" -n "$EG_NS" 2>/dev/null || true
fi

# Uninstall Envoy Gateway Helm release (removes the conflicting ConfigMap ownership)
if helm status eg -n "$EG_NS" &>/dev/null; then
  echo "  Uninstalling Helm release 'eg' in ${EG_NS}..."
  helm uninstall eg -n "$EG_NS" 2>/dev/null || true
fi

# Patch finalizers off resources that block deletion when the controller is gone
echo "  Removing finalizers from Gateway API resources..."
kubectl patch gateway "$GW_NAME" -n "$EG_NS" \
  --type=json -p='[{"op":"replace","path":"/metadata/finalizers","value":[]}]' 2>/dev/null || true
kubectl patch gatewayclass "$GW_NAME" \
  --type=json -p='[{"op":"replace","path":"/metadata/finalizers","value":[]}]' 2>/dev/null || true
kubectl patch envoyproxy envoy-proxy-config -n "$EG_NS" \
  --type=json -p='[{"op":"replace","path":"/metadata/finalizers","value":[]}]' 2>/dev/null || true

# Delete all kubectl-applied custom resources (force, ignore if already gone)
echo "  Deleting Gateway API resources..."
kubectl delete -f "$EG_DIR/05-security-policy.yaml"        --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete -f "$EG_DIR/04-patient-apis-httproute.yaml" --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete -f "$EG_DIR/03-reference-grants.yaml"       --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete -f "$EG_DIR/02-gateway.yaml"                --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete -f "$EG_DIR/01-gatewayclass.yaml"           --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete -f "$EG_DIR/00-envoy-proxy-config.yaml"     --ignore-not-found=true --force --grace-period=0 2>/dev/null || true

# Delete and recreate the namespace for a fully clean slate
echo "  Deleting namespace ${EG_NS}..."
kubectl delete namespace "$EG_NS" --ignore-not-found=true &
DELETE_PID=$!

# Wait up to 30s for graceful namespace termination
for i in {1..30}; do
  kubectl get namespace "$EG_NS" &>/dev/null || break
  sleep 1
done

# If namespace is stuck in Terminating (finalizer issue), force-clear it
if kubectl get namespace "$EG_NS" &>/dev/null; then
  echo "  Namespace stuck — force-clearing namespace finalizers..."
  kubectl get namespace "$EG_NS" -o json \
    | python3 -c "import sys,json; ns=json.load(sys.stdin); ns['spec']['finalizers']=[]; print(json.dumps(ns))" \
    | kubectl replace --raw "/api/v1/namespaces/${EG_NS}/finalize" -f - 2>/dev/null || true
fi
wait "$DELETE_PID" 2>/dev/null || true

# ─── Step 1: Namespace ────────────────────────────────────────────────────────
echo ""
echo "--- Creating namespace ${EG_NS} ---"
kubectl create namespace "$EG_NS"

# ─── Step 2: Install Envoy Gateway ────────────────────────────────────────────
echo ""
echo "--- Installing Envoy Gateway ${EG_VERSION} ---"
helm install eg \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" \
  -n "$EG_NS"

echo "Waiting for Envoy Gateway controller to be ready..."
kubectl rollout status deployment/envoy-gateway -n "$EG_NS" --timeout=120s

# ─── Step 3: TLS cert — delete existing, generate new ────────────────────────
echo ""
echo "--- Generating TLS certificate for ${GW_HOST} ---"
kubectl delete secret "$TLS_SECRET" -n "$EG_NS" --ignore-not-found=true

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Use openssl config file for SAN — compatible with macOS LibreSSL and Linux OpenSSL
cat > "$TMP_DIR/san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[req_distinguished_name]
CN = ${GW_HOST}

[v3_req]
subjectAltName = DNS:${GW_HOST}
EOF

openssl req -x509 -newkey rsa:2048 \
  -keyout "$TMP_DIR/tls.key" \
  -out    "$TMP_DIR/tls.crt" \
  -days 365 -nodes \
  -config "$TMP_DIR/san.cnf" \
  -extensions v3_req

kubectl create secret tls "$TLS_SECRET" \
  --cert="$TMP_DIR/tls.crt" \
  --key="$TMP_DIR/tls.key" \
  -n "$EG_NS"

echo "TLS secret '${TLS_SECRET}' created in ${EG_NS}"

# ─── Step 4: IS CA cert ConfigMap for JWKS TLS trust ────────────────────────
# Extracts the WSO2 IS self-signed CA cert from the local JKS and creates a
# ConfigMap in envoy-gateway-system so the BackendTLSPolicy can trust it
# when Envoy fetches JWKS from https://wso2is-identity-server.iam:9443/oauth2/jwks
echo ""
echo "--- Creating IS CA cert ConfigMap from is-ingress.crt ---"

IS_CERT="$SCRIPT_DIR/new_keys/is-ingress.crt"
kubectl delete configmap wso2-is-ca-cert -n "$EG_NS" --ignore-not-found=true
kubectl create configmap wso2-is-ca-cert \
  --from-file=ca.crt="$IS_CERT" \
  -n "$EG_NS"
echo "  ConfigMap wso2-is-ca-cert created in ${EG_NS} from ${IS_CERT}"

# ─── Step 5: EnvoyProxy config + GatewayClass + Gateway ──────────────────────
echo ""
echo "--- Applying EnvoyProxy config, GatewayClass, and Gateway ---"
# EnvoyProxy sets service type=ClusterIP so k3s svclb does not try to bind
# hostPort 443 (which is already taken by nginx ingress on this node)
kubectl apply -f "$EG_DIR/00-envoy-proxy-config.yaml"
kubectl apply -f "$EG_DIR/01-gatewayclass.yaml"
kubectl apply -f "$EG_DIR/02-gateway.yaml"

echo "Waiting for Gateway to be Programmed..."
for i in {1..24}; do
  STATUS=$(kubectl get gateway "$GW_NAME" -n "$EG_NS" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")
  if [ "$STATUS" = "True" ]; then
    echo "  Gateway is Programmed."
    break
  fi
  echo "  Gateway not ready yet... ($i/24)"
  sleep 5
done

# ─── Step 6: ReferenceGrants ──────────────────────────────────────────────────
echo ""
echo "--- Applying ReferenceGrants ---"
kubectl apply -f "$EG_DIR/03-reference-grants.yaml"

# ─── Step 7: HTTPRoute ────────────────────────────────────────────────────────
echo ""
echo "--- Applying Patient APIs HTTPRoute ---"
kubectl apply -f "$EG_DIR/04-patient-apis-httproute.yaml"

# ─── Step 8: SecurityPolicy + BackendTLSPolicy ────────────────────────────────
echo ""
echo "--- Applying BackendTLSPolicy and SecurityPolicy ---"
kubectl apply -f "$EG_DIR/05-security-policy.yaml"

# ─── Step 9: CoreDNS update — envoygw.wso2.com → Envoy proxy ClusterIP ───────
# CoreDNS is in-cluster DNS — must use the Envoy Gateway service's own ClusterIP
# (e.g. 10.43.X.Y), NOT 10.43.78.65 which is nginx ingress (no rule for envoygw).
# The script patches the live ConfigMap directly so the file value does not matter.
# For /etc/hosts on your Mac, add envoygw.wso2.com to your existing host line
# (same IP you use for is.wso2.com, gw.wso2.com etc).
echo ""
echo "--- Updating CoreDNS with envoygw.wso2.com → Envoy Gateway ClusterIP ---"

EG_PROXY_IP=""
for i in {1..12}; do
  EG_PROXY_IP=$(kubectl get svc -n "$EG_NS" \
    -l "gateway.envoyproxy.io/owning-gateway-name=${GW_NAME},gateway.envoyproxy.io/owning-gateway-namespace=${EG_NS}" \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || true)
  if [ -n "$EG_PROXY_IP" ] && [ "$EG_PROXY_IP" != "None" ] && [ "$EG_PROXY_IP" != "null" ]; then
    break
  fi
  echo "  Waiting for Envoy proxy ClusterIP... ($i/12)"
  sleep 5
done

if [ -z "$EG_PROXY_IP" ] || [ "$EG_PROXY_IP" = "None" ] || [ "$EG_PROXY_IP" = "null" ]; then
  echo "WARNING: Could not get Envoy proxy ClusterIP — CoreDNS not updated."
  echo "         Get it with: kubectl get svc -n $EG_NS -l gateway.envoyproxy.io/owning-gateway-name=$GW_NAME"
  echo "         Then rerun this script."
else
  echo "  Envoy proxy ClusterIP: ${EG_PROXY_IP}"

  # Write the ClusterIP into coredns-custom.yaml (in-place).
  # Replaces any existing value (placeholder or previous IP) on the envoygw line.
  # ClusterIP is stable across redeployments — only changes on full Service deletion.
  # If that happens, rerun this script to update the file again.
  sed -i '' "s|[^ ]* envoygw\.wso2\.com|${EG_PROXY_IP} envoygw.wso2.com|" \
    "$SCRIPT_DIR/coredns-custom.yaml"
  echo "  coredns-custom.yaml updated: envoygw.wso2.com → ${EG_PROXY_IP}"

  # Apply the updated file and restart CoreDNS
  kubectl apply -f "$SCRIPT_DIR/coredns-custom.yaml"
  kubectl rollout restart deployment/coredns -n kube-system
  kubectl rollout status deployment/coredns -n kube-system --timeout=60s
  echo "  CoreDNS updated."
fi

# ─── Step 10: APIM Common Agent (EG API Discovery) ───────────────────────────
# The agent watches HTTPRoutes in envoy-gateway-system and syncs them into
# APIM Publisher as discovered APIs.
echo ""
echo "--- Installing APIM Common Agent (EG API Discovery) ---"

# Add helm repo (idempotent)
helm repo remove agent 2>/dev/null || true
helm repo add agent https://github.com/wso2-extensions/apim-gw-connectors/releases/download/apim-k8s-common-gw-connector-${AGENT_CHART_VERSION}
helm repo update agent

# Create TLS secret for agent gRPC server — chart mounts subPath tls.crt/tls.key
# Self-signed with CN matching the in-cluster service name (stable across restarts)
kubectl delete secret common-agent-server-cert -n "$EG_NS" --ignore-not-found=true
openssl req -x509 -newkey rsa:2048 \
  -keyout /tmp/agent-tls.key \
  -out    /tmp/agent-tls.crt \
  -days 3650 -nodes \
  -subj "/CN=apim-agent-service.${EG_NS}.svc" 2>/dev/null
kubectl create secret tls common-agent-server-cert \
  --cert=/tmp/agent-tls.crt \
  --key=/tmp/agent-tls.key \
  -n "$EG_NS"
rm -f /tmp/agent-tls.crt /tmp/agent-tls.key

# Install the agent
# dataPlane.enabled=false: no APK data plane needed for EG discovery
# certmanager.enabled=false: we provide the cert secret manually above
helm install "$AGENT_RELEASE" agent/apim-k8s-common-gw-helm \
  --version "$AGENT_CHART_VERSION" \
  -n "$EG_NS" \
  --set controlPlane.serviceURL="https://${ACP_SVC}.${ACP_NS}.svc.cluster.local:9443/" \
  --set "controlPlane.eventListeningEndpoints=amqp://admin:admin@${ACP_SVC}.${ACP_NS}.svc.cluster.local:5672?retries='10'&connectdelay='30'" \
  --set controlPlane.skipSSLVerification=true \
  --set certmanager.enabled=false \
  --set dataPlane.enabled=false \
  --set dataPlane.namespace="$EG_NS"

# Remove liveness/readiness probes — the health check script uses IPv4 (127.0.0.1)
# but the gRPC server binds on IPv6 (:::18000), causing a permanent probe failure
# and restart loop. EG discovery works correctly without the probes.
kubectl patch deployment ${AGENT_RELEASE}-wso2-common-agent-deployment \
  -n "$EG_NS" \
  --type=json \
  -p='[
    {"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"},
    {"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}
  ]' 2>/dev/null || true

echo "Waiting for Common Agent to be ready..."
kubectl rollout status deployment/${AGENT_RELEASE}-wso2-common-agent-deployment \
  -n "$EG_NS" --timeout=120s || {
  echo "  Agent not ready yet. Check: kubectl logs -l app=wso2-common-agent -n ${EG_NS}"
}

# ─── Step 12: Verify ──────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "Verification"
echo "================================================"
echo ""
echo "Pods:"
kubectl get pods -n "$EG_NS"
echo ""
echo "Gateway:"
kubectl get gateway -n "$EG_NS"
echo ""
echo "HTTPRoute:"
kubectl get httproute -n "$EG_NS"
echo ""
echo "SecurityPolicy:"
kubectl get securitypolicy -n "$EG_NS"
echo ""
echo "Envoy proxy Service:"
kubectl get svc -n "$EG_NS" \
  -l "gateway.envoyproxy.io/owning-gateway-name=${GW_NAME}"

echo ""
echo "================================================"
echo "Done!"
echo ""
echo "Add envoygw.wso2.com to your existing /etc/hosts line on your Mac:"
echo "  (same IP you use for is.wso2.com, gw.wso2.com etc.)"
echo ""
echo "Test (get a token from WSO2 IS first):"
echo "  curl -k https://${GW_HOST}:8443/patients       -H 'Authorization: Bearer <token>'"
echo "  curl -k https://${GW_HOST}:8443/appointments   -H 'Authorization: Bearer <token>'"
echo "  curl -k https://${GW_HOST}:8443/prescriptions  -H 'Authorization: Bearer <token>'"
echo "  curl -k https://${GW_HOST}:8443/labs           -H 'Authorization: Bearer <token>'"
echo ""
echo "API Discovery:"
echo "  Check APIM Publisher for discovered APIs: https://cp.wso2.com/publisher"
echo "  Agent logs: kubectl logs -l app=wso2-common-agent -n ${EG_NS} --tail=20"
echo "================================================"
