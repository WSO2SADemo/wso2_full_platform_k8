#!/bin/bash

set -e

REGISTRY="docker.wso2.com"
IMAGE_NAME="ramilu90/wso2am-universal-gw-custom"
IMAGE_TAG="latest"

echo "Login to ${REGISTRY}"
read -p "Username: " DOCKER_USERNAME
read -s -p "Password: " DOCKER_PASSWORD
echo

echo "$DOCKER_PASSWORD" | docker login "$REGISTRY" -u "$DOCKER_USERNAME" --password-stdin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building image ${IMAGE_NAME}:${IMAGE_TAG} ..."
docker buildx build \
    --no-cache \
    --platform linux/amd64 \
    --provenance=false \
    --load \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
