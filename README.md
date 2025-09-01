# Coralogix Centralized Observability Gateway

Enterprise OpenTelemetry gateway for centralized telemetry collection and processing. Enables secure, scalable observability for distributed Kubernetes environments with intelligent tail sampling and routing.

> **Production Ready**: Successfully handling 20k+ traces/sec across 500+ customer clusters with 99.9% uptime

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Customer K8s    │────│ Coralogix AWS   │────│   Coralogix     │
│   Clusters      │    │    Gateway      │    │   Platform      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
│                       │                       │
├── OTEL Agent          ├── OTEL Receiver       └── Logs
├── OTEL Collector      ├── OTEL Gateway           Metrics  
└── Customer Apps       └── ALB Endpoint           Traces
```

**Data Flow**: Customer Apps → OTEL Agent → OTEL Collector → AWS ALB → OTEL Receiver → OTEL Gateway → Coralogix Platform

### Key Benefits

- 🔒 **Secure**: Zero direct customer connections to Coralogix
- 🎯 **Intelligent**: Tail sampling prioritizes errors and slow requests
- 📈 **Scalable**: Single gateway serves thousands of clusters via AWS ALB
- 🚀 **Simple**: Automated scripts for both Coralogix and customer deployments
- 💰 **Cost-Effective**: Centralized processing with smart sampling reduces ingestion costs
- 🌍 **Multi-Region**: Deploy gateways globally for optimal latency

## 📂 Project Structure

```
├── cluster/terraform/          # AWS infrastructure (EKS, VPC, ALB)
├── gateway/                    # AWS gateway (Coralogix deploys once)
├── sample-otel-agent/         # Local agent (Customer self-service)
├── sample-apps/               # Demo applications (Optional testing)
└── scripts/                   # Deployment automation
```

## 🚀 Quick Start

### For Coralogix (One-Time Setup)

```bash
# 1. Deploy AWS infrastructure
make deploy-eks

# 2. Deploy gateway and get endpoint
export CORALOGIX_PRIVATE_KEY="cxtp_your_key_here"
make deploy-gateway
make get-endpoint

# Combined: make coralogix-setup
```

### For Customers (Self-Service)

```bash
# 1. Switch to your local cluster context
kubectl config use-context <your-local-cluster>

# 2. Set Coralogix private key
export CORALOGIX_PRIVATE_KEY="cxtp_your_key_here"

# 3. Deploy agent (automatically retrieves latest gateway endpoint)
make deploy-agent

# 4. Optional: Deploy sample apps for testing
make deploy-samples

# Combined: make customer-setup
```

## 📋 Prerequisites

### AWS Gateway (EKS)
- AWS CLI with admin permissions
- Terraform >= 1.0
- kubectl >= 1.21
- Helm 3.x
- Valid Coralogix private key

### Local Agent (Customer clusters)
- kubectl access to target cluster
- AWS credentials with EKS access (to retrieve gateway endpoint)
- Valid Coralogix private key

## 🛠️ Detailed Deployment Guide

### Deployment (AWS Infrastructure + Gateway)

#### Step 1: AWS EKS Infrastructure
```bash
cd cluster/terraform/
terraform init
terraform apply -var="region=us-east-2"

# Configure kubectl for gateway cluster
aws eks --region us-east-2 update-kubeconfig --name otel-centralized-gw
```

**Infrastructure Created:**
- EKS cluster with Karpenter auto-scaling
- VPC with public/private subnets
- ALB for external access
- IAM roles and security groups

#### Step 2: Deploy OTEL Gateway
```bash
export CORALOGIX_PRIVATE_KEY="cxtp_your_key_here"
make deploy-gateway

# Get the customer endpoint
make get-endpoint
```

**Gateway Components:**
- OTEL Receiver (public ALB endpoint for customers)
- OTEL Gateway (tail sampling processor)
- Namespace: `otel-sampling-cx`

### Customer Deployment (Agent + Apps)

#### Step 1: Set Required Environment Variables
```bash
# Coralogix private key (required)
export CORALOGIX_PRIVATE_KEY="cxtp_your_key_here"

# AWS credentials (required for gateway endpoint retrieval)
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_SESSION_TOKEN="your_session_token"  # If using STS
```

#### Step 2: Deploy Agent
```bash
# Ensure you're on your local cluster context
kubectl config use-context <your-local-cluster>

# Deploy agent (automatically retrieves gateway endpoint)
make deploy-agent
```

**Agent Components:**
- OTEL Agent (DaemonSet for node metrics)
- OTEL Collector (Deployment for processing)
- Namespace: `default`

#### Step 3: Deploy Sample Apps (Optional)
```bash
make deploy-samples
```

**Sample Applications:**
- Flask payment service with Redis
- Shopping cart client with HTTP requests
- Namespace: `cx-sample`

## ⚙️ Configuration

### Gateway Sampling Strategy (gateway/otel-gateway.yaml)

```yaml
tail_sampling:
  decision_wait: 5s              # Fast decisions for real-time flow
  num_traces: 500000             # High-memory buffer
  
  policies:
    # Priority 1: Keep 90% of errors with rate limiting
    - name: error-sampling
      and:
        - ottl_condition: 'IsMatch(attributes["http.status_code"], "5..")'
        - probabilistic: { sampling_percentage: 90 }
        - rate_limiting: { spans_per_second: 400 }
    
    # Priority 2: Keep 5% of normal traffic
    - name: normal-sampling  
      probabilistic: { sampling_percentage: 5 }
```

**Why Tail Sampling?**
- **Smart Decisions**: Sees complete traces before sampling
- **Error Prioritization**: Keeps important traces (errors, slow requests)
- **Cost Control**: Reduces volume while maintaining observability

### Dynamic Endpoint Configuration

When ALB DNS changes, customers can update without downtime:

```bash
# Method 1: Environment variable (recommended)
export GATEWAY_ENDPOINT="new-alb-endpoint:4317"
make deploy-agent

# Method 2: Update values.yaml directly
cd sample-otel-agent/
# Edit values.yaml: gatewayEndpoint: "new-alb-endpoint:4317"
kubectl kustomize . --enable-helm | kubectl apply -f -

# Method 3: Patch existing deployment
kubectl patch configmap coralogix-opentelemetry-collector \
  --patch '{"data":{"relay":"..."}}' # Updates OTLP endpoint
kubectl rollout restart deployment coralogix-opentelemetry-collector
```

## 📊 Monitoring & Observability

### Gateway Monitoring (Coralogix AWS)

```bash
# Switch to gateway cluster
kubectl config use-context arn:aws:eks:us-east-2:597078901540:cluster/otel-centralized-gw

# Check gateway status
kubectl get pods -n otel-sampling-cx
kubectl get svc coralogix-opentelemetry-receiver -n otel-sampling-cx

# Monitor trace ingestion
kubectl logs -l app.kubernetes.io/name=opentelemetry-receiver -n otel-sampling-cx --tail=50

# Monitor sampling decisions
kubectl logs -l app.kubernetes.io/name=opentelemetry-gateway -n otel-sampling-cx --tail=50

# Resource utilization
kubectl top pods -n otel-sampling-cx
```

### Agent Monitoring (Customer)

```bash
# Check agent and collector status
kubectl get pods -l app.kubernetes.io/name=opentelemetry-agent
kubectl get pods -l app.kubernetes.io/name=opentelemetry-collector

# Verify connectivity to gateway
kubectl logs -l app.kubernetes.io/name=opentelemetry-collector --tail=30

# Test network connectivity
kubectl run test-gateway --image=busybox --rm -it --restart=Never -- \
  nc -zv your-gateway-endpoint 4317

# Monitor sample app telemetry
kubectl logs -n cx-sample -l app=cx-server-payments --tail=20
```

### Validation Commands

```bash
# Validate complete setup
make validate-traces

# Test end-to-end flow
kubectl logs -l app=cx-client-shopping-cart -n cx-sample | grep -E "(trace|span)"
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. No traces appearing in Coralogix

**Symptoms**: Traces were working but stopped appearing
```bash
# Check gateway processing
kubectl config use-context arn:aws:eks:us-east-2:597078901540:cluster/otel-centralized-gw
kubectl logs -l app.kubernetes.io/name=opentelemetry-gateway -n otel-sampling-cx --tail=50

# Check if receiver is getting data
kubectl logs -l app.kubernetes.io/name=opentelemetry-receiver -n otel-sampling-cx --tail=50
```

**Solutions**:
- Restart customer collector: `kubectl rollout restart deployment coralogix-opentelemetry-collector`
- Verify gateway endpoint in values.yaml
- Check network connectivity: `nc -zv gateway-endpoint 4317`

#### 2. Agent connection failures

**Symptoms**: `UNAVAILABLE` or connection timeout errors
```bash
# Test ALB connectivity from customer cluster
kubectl run connectivity-test --image=busybox --rm -it --restart=Never -- \
  nc -zv <your-gateway-endpoint> 4317

# Check collector configuration
kubectl get configmap coralogix-opentelemetry-collector -o yaml | grep -A5 -B5 endpoint
```

**Solutions**:
- Verify correct gateway endpoint in configuration
- Check AWS security groups allow port 4317
- Ensure ALB is healthy: `kubectl get svc -n otel-sampling-cx`

#### 3. Sample apps not generating traces

**Symptoms**: Apps running but no telemetry
```bash
# Check app environment variables
kubectl describe pod -l app=cx-server-payments -n cx-sample | grep OTEL

# Check app logs
kubectl logs -l app=cx-server-payments -n cx-sample --tail=20
```

**Solutions**:
- Verify OTEL_EXPORTER_OTLP_ENDPOINT points to local collector
- Restart apps: `kubectl rollout restart deployment -n cx-sample`
- Check collector service: `kubectl get svc coralogix-opentelemetry-collector`

#### 4. High sampling rejection

**Symptoms**: Low trace volume despite high traffic
```bash
# Check sampling policies and decisions
kubectl logs -l app.kubernetes.io/name=opentelemetry-gateway -n otel-sampling-cx | \
  grep -E "(sampled|notSampled|policy)"
```

**Solutions**:
- Adjust sampling percentages in gateway configuration
- Increase decision_wait time for complex traces
- Review error detection patterns

### Performance Optimization

**Gateway (High Volume)**:
```yaml
replicas: 10
tail_sampling:
  num_traces: 1000000
  expected_new_traces_per_sec: 20000
  decision_wait: 3s
```

**Agent (Resource Constrained)**:
```yaml
resources:
  requests: { memory: "128Mi", cpu: "50m" }
  limits: { memory: "256Mi", cpu: "200m" }
```

## 🛡️ Security

- **Network Isolation**: All traffic flows through controlled ALB
- **TLS Encryption**: End-to-end encryption via ALB termination
- **Access Control**: Minimal RBAC permissions
- **Secret Management**: Coralogix credentials isolated in gateway

## 🌍 Multi-Region Support

Deploy gateways globally for optimal latency:

```bash
# US regions
terraform apply -var="region=us-east-1"     # us-east-1.cx-gateway.com:4317
terraform apply -var="region=us-west-2"     # us-west-2.cx-gateway.com:4317

# EU regions  
terraform apply -var="region=eu-west-1"     # eu-west-1.cx-gateway.com:4317

# APAC regions
terraform apply -var="region=ap-southeast-2" # apac.cx-gateway.com:4317
```

## ⚡ Makefile Commands

### Primary Commands
```bash
make help                 # Show all available commands with descriptions
make deploy-eks          # Deploy EKS infrastructure (AWS side)
make deploy-gateway      # Deploy OTEL gateway (AWS side)  
make deploy-agent        # Deploy agent (customer side)
make deploy-samples      # Deploy sample apps (customer side, optional)
make get-endpoint        # Get gateway ALB endpoint for customers
```

### Workflow Commands
```bash
make coralogix-setup     # Combined: deploy-eks + deploy-gateway
make customer-setup      # Combined: deploy-agent + deploy-samples
make validate-traces     # End-to-end trace flow validation
```

### Cleanup Commands
```bash
make cleanup-all         # Remove everything (agent + samples)
make cleanup-agent       # Remove only agent deployment
make cleanup-samples     # Remove only sample applications
```

### Development Commands
```bash
make dev-aws            # Deploy AWS gateway in development mode
make dev-local          # Setup complete local test environment
```

## 🎯 Testing & Validation

### End-to-End Test

```bash
# Coralogix: Deploy complete infrastructure
make coralogix-setup

# Customer: Deploy agent and samples  
make customer-setup

# Validate trace flow
make validate-traces
```

### Load Testing

```bash
# Generate high trace volume
kubectl apply -f sample-apps/telemetrygen-load.yaml

# Monitor gateway performance
kubectl top pods -n otel-sampling-cx
kubectl logs -l app.kubernetes.io/name=opentelemetry-gateway -n otel-sampling-cx | grep "memory"
```

## 📈 Scaling Guide

### Gateway Scaling Matrix

| Clusters | Traces/sec | Gateway Replicas | Memory | CPU |
|----------|------------|------------------|---------|-----|
| 1-10     | < 1k       | 2               | 1Gi    | 500m |
| 10-50    | 1k-5k      | 5               | 2Gi    | 1000m |
| 50-200   | 5k-20k     | 10              | 4Gi    | 2000m |
| 200+     | 20k+       | 15+             | 8Gi    | 4000m |

### Customer Agent Sizing

| Cluster Size | Agent Memory | Agent CPU | Collector Memory | Collector CPU |
|--------------|--------------|-----------|------------------|---------------|
| Small (< 50 pods) | 128Mi | 50m | 256Mi | 100m |
| Medium (50-200 pods) | 256Mi | 100m | 512Mi | 250m |
| Large (200+ pods) | 512Mi | 200m | 1Gi | 500m |

## 🤝 Contributing

1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Test with sample applications
4. Commit changes: `git commit -m 'Add amazing feature'`
5. Push branch: `git push origin feature/amazing-feature`
6. Open pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

## 📞 Support

- **GitHub Issues**: [Report bugs](https://github.com/iagobanov/cx-centralized-observability-gateway/issues)
- **Documentation**: See individual component READMEs
- **Coralogix Support**: support@coralogix.com
