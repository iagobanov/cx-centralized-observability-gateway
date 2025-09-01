#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REGION="${AWS_REGION:-us-east-2}"
CLUSTER_NAME="otel-centralized-gw"

echo "🏗️ Deploying EKS Infrastructure"
echo "================================"

# Deploy AWS infrastructure
echo "📦 Deploying AWS EKS cluster and networking..."
cd "$ROOT_DIR/cluster/terraform"
terraform init -upgrade
terraform apply -var="region=$REGION" -auto-approve

# Configure kubectl
echo "🔧 Configuring cluster access..."
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"
kubectl cluster-info

echo ""
echo "✅ EKS INFRASTRUCTURE READY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  Cluster: $CLUSTER_NAME"
echo "🌍 Region: $REGION"
echo ""
echo "🎯 Next step: Deploy OTEL Gateway"
echo "   ./scripts/deploy-gateway.sh"