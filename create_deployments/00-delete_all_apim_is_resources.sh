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

echo "Done!"