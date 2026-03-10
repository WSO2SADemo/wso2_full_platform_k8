#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RABBITMQ_DIR="$SCRIPT_DIR"
COREDNS_FILE="$ROOT_DIR/create_deployments/coredns-custom.yaml"
NAMESPACE="ballerina"

echo "================================================"
echo "  Deploy RabbitMQ"
echo "================================================"

echo ""
echo "--- Creating namespace (if not exists) ---"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "--- Applying Credentials Secret ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-secret.yaml" --namespace "$NAMESPACE"

echo ""
echo "--- Deploying RabbitMQ manifests ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-configmap.yaml" --namespace "$NAMESPACE"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-service.yaml" --namespace "$NAMESPACE"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-statefulset.yaml" --namespace "$NAMESPACE"

echo ""
echo "--- Applying Ingress ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-ingress.yaml" --namespace "$NAMESPACE"

echo ""
echo "--- Updating CoreDNS (coredns-custom) ---"
kubectl apply -f "$COREDNS_FILE"
kubectl rollout restart deployment/coredns -n kube-system
echo "Waiting for CoreDNS to restart..."
kubectl rollout status deployment/coredns -n kube-system --timeout=60s

echo ""
echo "--- Waiting for RabbitMQ to be ready ---"
kubectl rollout status statefulset/rabbitmq -n "$NAMESPACE" --timeout=120s

echo ""
echo "================================================"
echo "  RabbitMQ is ready!"
echo "================================================"
echo ""
echo "  Management UI : http://rabbitmq.wso2.com"
echo "  Credentials   : see secret 'rabbitmq-credentials' in namespace '$NAMESPACE'"
echo ""
echo "  In-cluster AMQP: amqp://rabbitmq.$NAMESPACE.svc.cluster.local:5672"
echo ""
echo "  Make sure your /etc/hosts contains:"
echo "  127.0.0.1  extgw.wso2.com icp.wso2.com gw.wso2.com cp.wso2.com is.wso2.com rabbitmq.wso2.com"
echo "================================================"
