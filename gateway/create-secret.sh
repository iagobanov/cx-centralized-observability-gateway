#!/bin/bash

# Create Coralogix private key secret for OTEL integration
# Usage: ./create-secret.sh

NAMESPACE="otel-sampling-cx"
SECRET_NAME="coralogix-keys"
PRIVATE_KEY=""

echo "Creating secret $SECRET_NAME in namespace $NAMESPACE..."

kubectl create secret generic $SECRET_NAME \
  --from-literal=PRIVATE_KEY="$PRIVATE_KEY" \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully."