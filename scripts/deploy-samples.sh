#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Deploying Sample Apps"
echo "========================"

# Deploy samples
cd "$ROOT_DIR/sample-apps"
echo "🛠️  Applying sample app yamls..."

kubectl apply -f deployment.yaml

echo ""
echo "✅ SAMPLE APPS DEPLOYED!"
echo "🗑️  To cleanup: kubectl delete namespace cx-sample"