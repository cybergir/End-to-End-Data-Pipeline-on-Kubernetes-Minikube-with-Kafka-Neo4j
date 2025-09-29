# Deployment Guide

## Prerequisites

- Minikube installed
- kubectl configured
- Helm installed

## Quick Start

```bash
# 1. Start Minikube with sufficient resources
minikube start --memory=4096 --cpus=4

# 2. Deploy entire pipeline
./scripts/deploy.sh

# 3. Monitor deployment
kubectl get pods -n kafka -w
```

## Step-by-Step Deployment

### 1. Kubernetes Cluster Setup

```bash
# Start Minikube
minikube start --memory=4096 --cpus=4

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Deploy Kafka Cluster

```bash
# Create namespace
kubectl create namespace kafka

# Deploy Strimzi operator
kubectl apply -f infrastructure/kafka/strimzi-operator.yaml -n kafka

# Deploy Kafka cluster
kubectl apply -f infrastructure/kafka/kafka-cluster.yaml -n kafka

# Wait for Kafka to be ready
kubectl wait kafka/data-pipeline-cluster --for=condition=Ready --timeout=300s -n kafka
```

### 3. Deploy Neo4j

```bash
# Add Helm repository
helm repo add neo4j https://helm.neo4j.com/neo4j
helm repo update

# Deploy Neo4j
kubectl apply -f infrastructure/neo4j/neo4j-helm-values.yaml -n kafka
```

### 4. Deploy Kafka Connect

```bash
# Build custom connector image
docker build -t kafka-connect-neo4j -f applications/kafka-connect-plugins/Dockerfile.neo4j-connector .

# Deploy Kafka Connect cluster
kubectl apply -f infrastructure/kafka-connect/kafka-connect-cluster.yaml -n kafka

# Deploy Neo4j sink connector
kubectl apply -f infrastructure/kafka-connect/neo4j-sink-connector.yaml -n kafka
```

### 5. Deploy Producer Application

```bash
# Build producer image
docker build -t kafka-producer -f applications/producer-app/Dockerfile .

# Deploy to Kubernetes
kubectl apply -f applications/producer-app/k8s-deployment.yaml -n kafka
```

## Verification

```bash
# Check all pods are running
kubectl get pods -n kafka

# Check Kafka topics
kubectl exec -it data-pipeline-cluster-kafka-0 -n kafka -- bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Test Neo4j connection
kubectl port-forward svc/neo4j 7474:7474 -n kafka
# Open browser: http://localhost:7474
```

## Troubleshooting

```bash
# Check pod logs
kubectl logs <pod-name> -n kafka

# Describe pod for errors
kubectl describe pod <pod-name> -n kafka

# Check events in namespace
kubectl get events -n kafka --sort-by=.lastTimestamp
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f infrastructure/ -n kafka
kubectl delete namespace kafka

# Stop Minikube
minikube stop
```
