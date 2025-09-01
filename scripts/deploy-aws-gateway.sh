#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REGION="${AWS_REGION:-us-east-2}"
CLUSTER_NAME="otel-centralized-gw"

echo "🚀 Deploying OTEL Gateway (Single-Shot Setup)"
echo "=============================================="

# Validate Coralogix key
if [[ -z "${CORALOGIX_PRIVATE_KEY:-}" ]]; then
    echo "❌ ERROR: CORALOGIX_PRIVATE_KEY is required"
    echo "   export CORALOGIX_PRIVATE_KEY=cxtp_xxxx"
    exit 1
fi

# Deploy AWS infrastructure
echo "📦 1/3 Deploying AWS infrastructure..."
cd "$ROOT_DIR/cluster/terraform"
terraform init -upgrade
terraform apply -var="region=$REGION" -auto-approve

# Configure kubectl
echo "🔧 2/3 Configuring cluster access..."
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"
kubectl cluster-info

# Deploy gateway
echo "🛠️  3/3 Deploying gateway components..."
cd "$ROOT_DIR/gateway"
./create-secret.sh
kubectl kustomize . --enable-helm | kubectl apply -f -

# Wait for readiness
echo "⏳ Waiting for gateway to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/coralogix-opentelemetry-gateway -n otel-sampling-cx
kubectl wait --for=condition=available --timeout=600s deployment/coralogix-opentelemetry-receiver -n otel-sampling-cx

# Get endpoint
ALB_ENDPOINT=$(kubectl get ingress coralogix-opentelemetry-receiver-http -n otel-sampling-cx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

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