#!/bin/bash
set -e

# ========================================
# Build and push the WSO2 ICP Docker image
#
# Image:   ramilu90/wso2icp:2.0.0
# Source:  k8_deployments/integration-control-plane/
# Target:  linux/amd64 (AKS)
#
# The build context is the full ICP source tree — the Dockerfile is kept here
# in this directory and passed via -f. Keep it in sync with the source repo's
# Dockerfile at k8_deployments/integration-control-plane/Dockerfile.
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ICP_SOURCE_DIR="$ROOT_DIR/k8_deployments/integration-control-plane"

IMAGE_NAME="ramilu90/wso2icp"
IMAGE_TAG="2.0.0"

# ── Preflight ─────────────────────────────────────────────────────────────────
if [ ! -d "$ICP_SOURCE_DIR" ]; then
  echo "ERROR: ICP source not found at $ICP_SOURCE_DIR"
  exit 1
fi

for required in gradlew icp_server frontend www conf distribution build.gradle; do
  if [ ! -e "$ICP_SOURCE_DIR/$required" ]; then
    echo "ERROR: Required source item missing: $ICP_SOURCE_DIR/$required"
    exit 1
  fi
done

echo "================================================"
echo "  WSO2 ICP Image Builder"
echo "  Image:   $IMAGE_NAME:$IMAGE_TAG"
echo "  Context: $ICP_SOURCE_DIR"
echo "  Platform: linux/amd64"
echo "================================================"
echo ""

# ── Build + Push ──────────────────────────────────────────────────────────────
# --platform linux/amd64 : AKS nodes are x86_64 (cross-compile from Apple Silicon)
# -f                     : use the Dockerfile from this image_builder directory
# --push                 : push directly to Docker Hub after build
docker buildx build \
  --platform linux/amd64 \
  -f "$SCRIPT_DIR/Dockerfile" \
  -t "$IMAGE_NAME:$IMAGE_TAG" \
  --push \
  "$ICP_SOURCE_DIR"

echo ""
echo "================================================"
echo "  Done! Image pushed: $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "  Update k8s deployment if needed:"
echo "    kubectl rollout restart deployment/icp-deployment -n icp"
echo "================================================"
