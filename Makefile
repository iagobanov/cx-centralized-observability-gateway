.PHONY: help deploy-aws deploy-agent deploy-samples get-endpoint validate-traces cleanup-all cleanup-agent cleanup-samples

help: ## Show this help message
	@echo "Coralogix Centralized OTEL Gateway"
	@echo "================================="
	@echo ""
	@echo "Available targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deploy-eks: ## Deploy EKS infrastructure (AWS side)
	@echo "🏗️ Deploying EKS infrastructure..."
	@./scripts/deploy-eks.sh

deploy-gateway: ## Deploy OTEL gateway (AWS side)
	@echo "🚀 Deploying OTEL gateway..."
	@./scripts/deploy-gateway.sh

deploy-agent: ## Deploy agent (customer side)
	@echo "🛠️ Deploying OTEL agent..."
	@./scripts/deploy-agent.sh

deploy-samples: ## Deploy sample applications (customer side, optional)
	@echo "🧪 Deploying sample applications..."
	@./scripts/deploy-samples.sh

get-endpoint: ## Get gateway ALB endpoint for customer configuration
	@echo "🔍 Retrieving gateway endpoint..."
	@./scripts/get-gateway-endpoint.sh

validate-traces: ## Validate end-to-end trace flow
	@echo "🔍 Validating trace flow..."
	@echo "📱 Checking sample app telemetry..."
	@kubectl logs -l app=cx-server-payments -n cx-sample --tail=10 | grep -E "(trace|span|exported)" || echo "⚠️  No recent app telemetry found"
	@echo "🔄 Checking collector processing..."
	@kubectl logs -l app.kubernetes.io/name=opentelemetry-collector --tail=10 | grep -E "(exported|batch)" || echo "⚠️  No collector exports found"
	@echo "🌐 Testing gateway connectivity..."
	@kubectl run connectivity-test --image=busybox --rm --restart=Never -- nc -zv $$(kubectl get configmap coralogix-opentelemetry-collector -o jsonpath='{.data.relay}' | grep -oP 'endpoint: \K[^:]+') 4317 2>/dev/null && echo "✅ Gateway reachable" || echo "❌ Gateway unreachable"

cleanup-all: cleanup-agent cleanup-samples ## Clean up everything (agent + samples)

cleanup-agent: ## Remove agent deployment
	@echo "🗑️ Cleaning up agent deployment..."
	@kubectl delete -k sample-otel-agent/ --ignore-not-found=true

cleanup-samples: ## Remove sample applications
	@echo "🗑️ Cleaning up sample applications..."
	@kubectl delete namespace cx-sample --ignore-not-found=true

# Development targets
dev-aws: ## Deploy AWS gateway in development mode
	@echo "🔧 Deploying in development mode..."
	@export AWS_REGION=us-east-2; ./scripts/deploy-aws-gateway.sh

dev-local: ## Setup complete local test environment
	@echo "🏠 Setting up local test environment..."
	@$(MAKE) deploy-agent GATEWAY_ENDPOINT=localhost:4317
	@$(MAKE) deploy-samples

# Combined workflows
coralogix-setup: deploy-eks deploy-gateway ## Deploy EKS + Gateway (Coralogix workflow)
	@echo ""
	@echo "✅ CORALOGIX SETUP COMPLETE!"
	@echo "🔗 Share endpoint with customers"

customer-setup: deploy-agent deploy-samples ## Deploy agent + samples (customer workflow)
	@echo ""
	@echo "✅ CUSTOMER SETUP COMPLETE!"
	@echo "📊 Telemetry flowing to Coralogix"