#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Deploying OTEL Agent"
echo "======================"

# Check for gateway endpoint
if [[ -z "${GATEWAY_ENDPOINT:-}" ]]; then
    echo "❌ ERROR: GATEWAY_ENDPOINT is required"
    echo "   export GATEWAY_ENDPOINT=your-gateway-endpoint:4317"
    echo ""
    echo "💡 Get endpoint from Coralogix team or run:"
    echo "   ./scripts/get-gateway-endpoint.sh"
    exit 1
fi

# Deploy agent
cd "$ROOT_DIR/sample-otel-agent"
echo "🛠️  Applying agent yamls..."
echo "📡 Using gateway endpoint: $GATEWAY_ENDPOINT"

# Create temporary values with endpoint
cp values.yaml values.yaml.bak
sed "s|REPLACE_WITH_GATEWAY_ENDPOINT|$GATEWAY_ENDPOINT|g" values.yaml.bak > values.yaml

kubectl apply -f namespace.yaml
kubectl kustomize . --enable-helm | kubectl apply -f -

# Restore original values
mv values.yaml.bak values.yaml

echo ""
echo "✅ AGENT DEPLOYED!"
echo "📡 Gateway endpoint: $GATEWAY_ENDPOINT"
echo ""
echo "🧪 Optional: Deploy sample apps"
echo "   ./scripts/deploy-samples.sh"