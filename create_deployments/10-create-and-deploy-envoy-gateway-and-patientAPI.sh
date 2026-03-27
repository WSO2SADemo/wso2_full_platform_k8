#!/bin/bash
set -e

# ========================================
# STEP 10: Deploy Envoy Gateway + Patient APIs
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
#
# NOTE: After this script, add to /etc/hosts on your Mac:
#   127.0.0.1  envoygw.wso2.com
# Then port-forward:
#   kubectl port-forward svc/<envoy-svc> 8443:443 -n envoy-gateway-system
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

echo "================================================"
echo "10. Deploy Envoy Gateway + Patient APIs"
echo "================================================"

# ─── Step 1: Namespace ────────────────────────────────────────────────────────
echo ""
echo "--- Ensuring namespace ${EG_NS} exists ---"
kubectl get namespace "$EG_NS" &>/dev/null || kubectl create namespace "$EG_NS"

# ─── Step 2: Install / upgrade Envoy Gateway ──────────────────────────────────
echo ""
echo "--- Installing Envoy Gateway ${EG_VERSION} ---"
helm upgrade --install eg \
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

# ─── Step 10: Verify ──────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "Verification"
echo "================================================"
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
echo "BackendTLSPolicy:"
kubectl get backendtlspolicy -n "$IS_NS"
echo ""
echo "Envoy proxy Service:"
kubectl get svc -n "$EG_NS" \
  -l "gateway.envoyproxy.io/owning-gateway-name=${GW_NAME}"

# Print port-forward command for local access
EG_SVC=$(kubectl get svc -n "$EG_NS" \
  -l "gateway.envoyproxy.io/owning-gateway-name=${GW_NAME}" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "<envoy-svc>")

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
echo "================================================"
