#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REGION="${AWS_REGION:-us-east-2}"
CLUSTER_NAME="otel-centralized-gw"

echo "🚀 Deploying OTEL Gateway"
echo "========================="

# Validate Coralogix key
if [[ -z "${CORALOGIX_PRIVATE_KEY:-}" ]]; then
    echo "❌ ERROR: CORALOGIX_PRIVATE_KEY is required"
    echo "   export CORALOGIX_PRIVATE_KEY=cxtp_xxxx"
    exit 1
fi

# Ensure kubectl is configured for gateway cluster
echo "🔧 Configuring cluster access..."
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"
kubectl cluster-info

# Deploy gateway
echo "🛠️  Deploying gateway components..."
cd "$ROOT_DIR/gateway"

# Ensure namespace exists first
echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

# Create secret (now that namespace exists)
./create-secret.sh

# Apply remaining resources
kubectl kustomize . --enable-helm | kubectl apply -f -

# Wait for readiness
echo "⏳ Waiting for gateway to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/coralogix-opentelemetry-gateway -n otel-sampling-cx
kubectl wait --for=condition=available --timeout=300s deployment/coralogix-opentelemetry-receiver -n otel-sampling-cx

# Get endpoint
ALB_ENDPOINT=$(kubectl get svc coralogix-opentelemetry-receiver -n otel-sampling-cx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "✅ GATEWAY DEPLOYMENT COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Customer Endpoint: $ALB_ENDPOINT:4317"
echo "🔗 Share this endpoint with customers for agent deployment"
echo ""
echo "🎯 Customer deployment command:"
echo "   export GATEWAY_ENDPOINT=$ALB_ENDPOINT:4317"
echo "   ./scripts/deploy-agent.sh"
echo ""
echo "🔍 Monitor gateway:"
echo "   kubectl get pods -n otel-sampling-cx"
echo "   kubectl logs -l app.kubernetes.io/name=opentelemetry-gateway -n otel-sampling-cx"