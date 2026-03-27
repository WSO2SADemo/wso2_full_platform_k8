#!/bin/bash
set -e

# ========================================
# STEP 5: Deploy APIM Gateways (Internal + External)
# Run AFTER CP is up and truststores are updated
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Verify apim-secrets.yaml has a valid Moesif key before proceeding ────────
APIM_SECRETS_YAML="$ROOT_DIR/k8_deployments/am-control-plane/apim-secrets.yaml"

ENCODED_KEY=$(grep -v '^\s*#' "$APIM_SECRETS_YAML" | grep 'MOESIF_API_KEY:' | awk '{print $2}')
if [ -z "$ENCODED_KEY" ]; then
  echo "ERROR: MOESIF_API_KEY is missing in $APIM_SECRETS_YAML. Update it and re-run."
  exit 1
fi

DECODED_KEY=$(echo "$ENCODED_KEY" | base64 --decode 2>/dev/null)
if [ -z "$DECODED_KEY" ]; then
  echo "ERROR: MOESIF_API_KEY in $APIM_SECRETS_YAML is not valid base64. Update it and re-run."
  exit 1
fi

KEY_PREVIEW="${DECODED_KEY:0:8}...${DECODED_KEY: -4}"
echo "MOESIF_API_KEY in apim-secrets.yaml: $KEY_PREVIEW"
read -r -p "Is this the correct Moesif key? [y/N]: " KEY_CONFIRMED
case "$KEY_CONFIRMED" in
  [yY][eE][sS]|[yY]) ;;
  *)
    echo "Aborted. Update MOESIF_API_KEY in $APIM_SECRETS_YAML and re-run."
    exit 1
    ;;
esac

# ── Apply apim-secrets (single source of truth for Moesif key) ───────────────
echo "Applying apim-secrets..."
kubectl apply -f "$APIM_SECRETS_YAML"

# ── Ask whether to deploy the external gateway ────────────────────────────────
read -r -p "Deploy external gateway (extgw)? [y/N]: " DEPLOY_EXTGW
case "$DEPLOY_EXTGW" in
  [yY][eE][sS]|[yY]) DEPLOY_EXTGW=true ;;
  *) DEPLOY_EXTGW=false ;;
esac

echo "================================================"
echo "5a. Deploying Internal Gateway (gw)"
echo "================================================"

helm uninstall gw -n apim-gw 2>/dev/null || true

helm install gw "$ROOT_DIR/k8_deployments/am-gateway/wso2am-universal-gw" \
  -n apim-gw \
  -f "$ROOT_DIR/k8_deployments/am-gateway/gw-min.yaml"

echo "Waiting for internal GW pod to be ready..."
kubectl rollout status deployment -l app=wso2am-universal-gw,release=gw -n apim-gw --timeout=300s || {
  echo "Internal GW not ready yet. Check: kubectl get pods -n apim-gw"
}

if [ "$DEPLOY_EXTGW" = true ]; then
  echo "================================================"
  echo "5b. Deploying External Gateway (extgw)"
  echo "================================================"

  helm uninstall extgw -n apim-gw 2>/dev/null || true

  helm install extgw "$ROOT_DIR/k8_deployments/am-gateway/wso2am-universal-gw" \
    -n apim-gw \
    -f "$ROOT_DIR/k8_deployments/am-gateway/extgw-min.yaml"

  echo "Waiting for external GW pod to be ready..."
  kubectl rollout status deployment -l app=wso2am-universal-gw,release=extgw -n apim-gw --timeout=300s || {
    echo "External GW not ready yet. Check: kubectl get pods -n apim-gw"
  }
else
  echo "Skipping external gateway (extgw) deployment."
fi

echo ""
echo "Deployment complete."
echo "Verify: kubectl get pods -n apim-gw"
echo "Ingresses: kubectl get ingress -n apim-gw"
