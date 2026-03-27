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


kubectl create namespace apim-cp
kubectl create namespace apim-gw
kubectl create namespace iam
kubectl create namespace rabbitmq
kubectl create namespace ballerina
kubectl create namespace icp
kubectl create namespace apim-kgw
kubectl create namespace apim-extgw
kubectl create namespace apim-db

kubectl get ns ingress-nginx >/dev/null 2>&1 || helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update && helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ingress-nginx --create-namespace
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ingress-nginx --create-namespace  --set controller.progressDeadlineSeconds=600


echo "Done!"