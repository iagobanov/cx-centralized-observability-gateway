#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-otel-sampling-cx}"
REGION="${AWS_REGION:-us-east-2}"
CLUSTER_NAME="${CLUSTER_NAME:-otel-centralized-gw}"

echo "🔍 Getting Gateway Endpoint"
echo "=========================="

# Check if we're in the right context
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ ! "$CURRENT_CONTEXT" == *"$CLUSTER_NAME"* ]]; then
    echo "⚠️  WARNING: Not connected to gateway cluster"
    echo "   Current context: $CURRENT_CONTEXT"
    echo "   Expected cluster: $CLUSTER_NAME"
    echo ""
    echo "🔧 Switching to gateway cluster..."
    aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"
fi

# Wait for ingress to be ready
echo "⏳ Waiting for ALB to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/coralogix-opentelemetry-receiver -n "$NAMESPACE" || {
    echo "❌ Gateway receiver not ready"
    exit 1
}

# Get the endpoint
echo "📡 Retrieving ALB endpoint..."
ALB_ENDPOINT=""
for i in {1..30}; do
    ALB_ENDPOINT=$(kubectl get svc coralogix-opentelemetry-receiver -n "$NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [[ -n "$ALB_ENDPOINT" ]]; then
        break
    fi
    
    echo "   Attempt $i/30: Waiting for ALB hostname..."
    sleep 10
done

if [[ -z "$ALB_ENDPOINT" ]]; then
    echo "❌ ERROR: Could not get ALB endpoint"
    echo "   Check ingress status:"
    kubectl get ingress -n "$NAMESPACE"
    exit 1
fi

FULL_ENDPOINT="$ALB_ENDPOINT:4317"

echo ""
echo "✅ GATEWAY ENDPOINT READY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Endpoint: $FULL_ENDPOINT"
echo ""
echo "🎯 Customer deployment command:"
echo "   export GATEWAY_ENDPOINT=$FULL_ENDPOINT"
echo "   ./scripts/deploy-agent.sh"
echo ""
echo "🧪 Optional: Test connectivity from customer cluster"
echo "   kubectl run test-gateway --image=busybox --rm -it --restart=Never -- \\"
echo "     wget -qO- --timeout=5 http://$ALB_ENDPOINT/health"