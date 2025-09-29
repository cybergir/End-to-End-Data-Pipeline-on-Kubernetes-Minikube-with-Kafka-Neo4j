#!/bin/bash
set -e

echo "Starting Kafka-Neo4j Data Pipeline Deployment..."
echo "==================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if minikube is running
    if ! minikube status &> /dev/null; then
        print_warning "Minikube is not running. Starting Minikube..."
        minikube start --memory=3500 --cpus=4 --driver=docker
    fi
    
    # Verify kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your configuration."
        exit 1
    fi
    
    print_status "Prerequisites check passed ✓"
}

# Create namespace
create_namespace() {
    print_status "Creating/verifying namespace..."
    kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy Strimzi Kafka Operator
deploy_kafka_operator() {
    print_status "Deploying Strimzi Kafka Operator..."
    kubectl apply -f infrastructure/kafka/strimzi-operator.yaml -n kafka
    
    # Wait for operator to be ready
    print_status "Waiting for Strimzi Operator to be ready..."
    kubectl wait --for=condition=available deployment/strimzi-cluster-operator -n kafka --timeout=300s
}

# Deploy Kafka Cluster
deploy_kafka_cluster() {
    print_status "Deploying Kafka Cluster..."
    kubectl apply -f infrastructure/kafka/kafka-cluster.yaml -n kafka
    
    # Wait for Kafka to be ready
    print_status "Waiting for Kafka cluster to be ready (this may take 5-10 minutes)..."
    kubectl wait --for=condition=ready kafka/data-pipeline-cluster -n kafka --timeout=600s
}

# Deploy Neo4j
deploy_neo4j() {
    print_status "Deploying Neo4j Database..."
    
    # Add Neo4j Helm repo if not already added
    if ! helm repo list | grep -q "neo4j"; then
        print_status "Adding Neo4j Helm repository..."
        helm repo add neo4j https://helm.neo4j.com/neo4j
        helm repo update
    fi
    
    # Deploy Neo4j using Helm values
    helm upgrade --install neo4j neo4j/neo4j \
        --namespace kafka \
        --values infrastructure/neo4j/neo4j-helm-values.yaml \
        --wait --timeout=600s
}

# Deploy Kafka Connect
deploy_kafka_connect() {
    print_status "Deploying Kafka Connect..."
    kubectl apply -f infrastructure/kafka-connect/kafka-connect-cluster.yaml -n kafka
    
    # Wait for Kafka Connect to be ready
    print_status "Waiting for Kafka Connect to be ready..."
    sleep 30  # Give it some time to start
}

# Create Kafka Topics
create_kafka_topics() {
    print_status "Creating Kafka topics..."
    kubectl apply -f infrastructure/kafka/kafka-topics.yaml -n kafka
}

# Deploy Neo4j Sink Connector
deploy_neo4j_connector() {
    print_status "Deploying Neo4j Sink Connector..."
    kubectl apply -f infrastructure/kafka-connect/neo4j-sink-connector.yaml -n kafka
}

# Deploy Producer Application
deploy_producer_app() {
    print_status "Building and deploying Producer Application..."
    
    # Build Docker image
    if docker info &> /dev/null; then
        print_status "Building producer application Docker image..."
        docker build -t kafka-producer:latest applications/producer-app/
        
        # Load image into Minikube
        print_status "Loading image into Minikube..."
        minikube image load kafka-producer:latest
    else
        print_warning "Docker not available, using existing image..."
    fi
    
    # Deploy to Kubernetes
    kubectl apply -f applications/producer-app/k8s-deployment.yaml -n kafka
}

# Verify Deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    echo ""
    echo "Deployment Status:"
    echo "===================="
    
    # Check all pods
    kubectl get pods -n kafka
    
    echo ""
    echo "Waiting for all pods to be ready..."
    
    # Wait for critical pods to be ready
    kubectl wait --for=condition=ready pod -l strimzi.io/name=data-pipeline-cluster-kafka -n kafka --timeout=300s
    kubectl wait --for=condition=ready pod -l app=neo4j -n kafka --timeout=300s
    
    print_status "Deployment verification completed ✓"
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    
    check_prerequisites
    create_namespace
    deploy_kafka_operator
    deploy_kafka_cluster
    deploy_neo4j
    deploy_kafka_connect
    create_kafka_topics
    deploy_neo4j_connector
    deploy_producer_app
    verify_deployment
    
    echo ""
    echo "Deployment completed successfully!"
    echo ""
    echo "Next steps:"
    echo "   - Monitor pods: kubectl get pods -n kafka -w"
    echo "   - Check logs: kubectl logs -f <pod-name> -n kafka"
    echo "   - Access Neo4j: kubectl port-forward svc/neo4j 7474:7474 -n kafka"
    echo "   - Test producer: kubectl logs -f deployment/kafka-producer -n kafka"
    echo ""
    echo "For troubleshooting, see: docs/troubleshooting.md"
}

# Run main function
main "$@"