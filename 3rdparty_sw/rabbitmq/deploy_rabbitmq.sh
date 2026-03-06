#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RABBITMQ_DIR="$SCRIPT_DIR"
COREDNS_FILE="$ROOT_DIR/create_deployments/coredns-custom.yaml"

echo "================================================"
echo "  Deploy RabbitMQ"
echo "================================================"

echo ""
echo "--- Creating namespace ---"
kubectl apply -f "$RABBITMQ_DIR/namespace.yaml"

echo ""
echo "--- Applying Secret ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-secret.yaml" -n rabbitmq

echo ""
echo "--- Applying ConfigMap ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-configmap.yaml" -n rabbitmq

echo ""
echo "--- Applying StatefulSet ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-statefulset.yaml" -n rabbitmq

echo ""
echo "--- Applying Services ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-service.yaml" -n rabbitmq

echo ""
echo "--- Applying Ingress ---"
kubectl apply -f "$RABBITMQ_DIR/rabbitmq-ingress.yaml" -n rabbitmq

echo ""
echo "--- Updating CoreDNS (coredns-custom) ---"
kubectl apply -f "$COREDNS_FILE"
kubectl rollout restart deployment/coredns -n kube-system
echo "Waiting for CoreDNS to restart..."
kubectl rollout status deployment/coredns -n kube-system --timeout=60s

echo ""
echo "--- Waiting for RabbitMQ to be ready ---"
kubectl rollout status statefulset/rabbitmq -n rabbitmq --timeout=120s

echo ""
echo "================================================"
echo "  RabbitMQ is ready!"
echo "================================================"
echo ""
echo "  Management UI : http://rabbitmq.wso2.com"
echo "  Username       : admin"
echo "  Password       : admin123"
echo ""
echo "  In-cluster AMQP: amqp://admin:admin123@rabbitmq.rabbitmq.svc.cluster.local:5672"
echo ""
echo "  Make sure your /etc/hosts contains:"
echo "  127.0.0.1  extgw.wso2.com icp.wso2.com gw.wso2.com cp.wso2.com is.wso2.com rabbitmq.wso2.com"
echo "================================================"
