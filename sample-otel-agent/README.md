# Sample OTEL Agent

This folder contains a sample OpenTelemetry collector agent configuration that communicates with the gateway deployed in the cluster.

## Configuration

The agent is configured to:
- Run as a DaemonSet to collect host metrics from each node
- Send telemetry data to the OTEL gateway via OTLP
- Include Kubernetes metadata attributes

## Setup

1. Update the gateway endpoint in `values.yaml`:
   ```yaml
   global:
     gatewayEndpoint: "your-alb-dns-here:4317"
   ```

2. Deploy the agent:
   ```bash
   kubectl apply -k .
   ```

## Variables

- `gatewayEndpoint`: The ALB DNS endpoint for the OTEL gateway (format: `hostname:port`)

## What it collects

- Host metrics (CPU, memory, filesystem, disk, load, network, process)
- Kubernetes metadata (pod name, namespace, deployment, node info)
- Custom resource attribute: `sample.agent=true`