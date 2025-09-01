#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Deploying OTEL Agent"
echo "======================"

# Auto-retrieve gateway endpoint if not provided
if [[ -z "${GATEWAY_ENDPOINT:-}" ]]; then
    echo "🔍 Auto-retrieving gateway endpoint..."
    
    # Switch to EKS context to get ALB endpoint
    REGION="${AWS_REGION:-us-east-2}"
    CLUSTER_NAME="otel-centralized-gw"
    
    # Configure EKS access
    echo "🔧 Configuring EKS access for cluster: $CLUSTER_NAME in region: $REGION"
    if ! aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"; then
        echo "❌ ERROR: Failed to configure EKS access. Check AWS credentials."
        exit 1
    fi
    
    # Get ALB endpoint
    echo "🔍 Retrieving ALB endpoint from service..."
    GATEWAY_ENDPOINT=$(kubectl get svc coralogix-opentelemetry-receiver -n otel-sampling-cx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:4317' 2>/dev/null)
    
    if [[ -z "$GATEWAY_ENDPOINT" || "$GATEWAY_ENDPOINT" == ":4317" ]]; then
        echo "🔍 Trying alternative service name..."
        GATEWAY_ENDPOINT=$(kubectl get svc -n otel-sampling-cx -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}:4317' 2>/dev/null)
    fi
    
    if [[ -z "$GATEWAY_ENDPOINT" || "$GATEWAY_ENDPOINT" == ":4317" ]]; then
        echo "❌ ERROR: Could not retrieve gateway endpoint"
        echo "   Make sure gateway is deployed: make deploy-gateway"
        exit 1
    fi
    
    echo "📡 Retrieved endpoint: $GATEWAY_ENDPOINT"
    echo "⚠️  NOTE: You must switch to your local cluster context before running this script"
    echo "   kubectl config use-context k3d-otel-local-v2"
fi

# Check for Coralogix private key
if [[ -z "${CORALOGIX_PRIVATE_KEY:-}" ]]; then
    echo "❌ ERROR: CORALOGIX_PRIVATE_KEY is required"
    echo "   export CORALOGIX_PRIVATE_KEY=your-private-key"
    exit 1
fi

# Deploy agent
cd "$ROOT_DIR/sample-otel-agent"
echo "🛠️  Applying agent yamls..."
echo "📡 Using gateway endpoint: $GATEWAY_ENDPOINT"

# Create temporary values with endpoint
cp values.yaml values.yaml.bak
sed "s|REPLACE_WITH_GATEWAY_ENDPOINT|$GATEWAY_ENDPOINT|g" values.yaml.bak > values.yaml

# Create cx-sample namespace first (needed for secret creation)
echo "🏗️  Creating cx-sample namespace..."
kubectl create namespace cx-sample --dry-run=client -o yaml | kubectl apply -f -

# Create secret in both namespaces
echo "🔑 Creating Coralogix secret..."
kubectl create secret generic coralogix-keys \
  --from-literal=PRIVATE_KEY="$CORALOGIX_PRIVATE_KEY" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic coralogix-keys \
  --from-literal=PRIVATE_KEY="$CORALOGIX_PRIVATE_KEY" \
  --namespace=cx-sample \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f namespace.yaml
kubectl kustomize . --enable-helm | kubectl apply -f -

# Keep updated values, remove backup
rm values.yaml.bak

echo ""
echo "✅ AGENT DEPLOYED!"
echo "📡 Gateway endpoint: $GATEWAY_ENDPOINT"
echo ""
echo "🧪 Optional: Deploy sample apps"
echo "   ./scripts/deploy-samples.sh"