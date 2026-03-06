#!/bin/bash

# Clean up all resources in apim-cp, apim-gw, and iam namespaces
for ns in apim-cp apim-gw iam; do
  echo "=== Cleaning namespace: $ns ==="
  kubectl delete ingress --all -n $ns
  kubectl delete services --all -n $ns
  kubectl delete deployments --all -n $ns
  kubectl delete statefulsets --all -n $ns
  kubectl delete configmaps --all -n $ns
  kubectl delete secrets --all -n $ns
  kubectl delete pods --all -n $ns
  echo ""
done

echo "=== Cleaning namespace: rabbitmq ==="
kubectl delete ingress --all -n rabbitmq --ignore-not-found=true
kubectl delete services --all -n rabbitmq --ignore-not-found=true
kubectl delete statefulsets --all -n rabbitmq --ignore-not-found=true
kubectl delete configmaps --all -n rabbitmq --ignore-not-found=true
kubectl delete secrets --all -n rabbitmq --ignore-not-found=true
kubectl delete pods --all -n rabbitmq --ignore-not-found=true
kubectl delete pvc --all -n rabbitmq --ignore-not-found=true
echo ""

echo "Done!"