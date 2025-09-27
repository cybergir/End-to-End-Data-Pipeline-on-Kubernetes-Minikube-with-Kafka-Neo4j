#!/bin/bash
set -e

echo "🔧 Setting up Minikube for Kafka-Neo4j Pipeline"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if Minikube is installed
check_minikube() {
    if ! command -v minikube &> /dev/null; then
        print_error "Minikube is not installed. Please install Minikube first."
        echo "Installation guide: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    print_status "Minikube is installed ✓"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed. Some features may not work."
    else
        print_status "Docker is available ✓"
    fi
}

# Start Minikube with optimal settings
start_minikube() {
    print_status "Starting Minikube cluster..."
    
    # Check if Minikube is already running
    if minikube status | grep -q "Running"; then
        print_warning "Minikube is already running. Restarting with new configuration..."
        minikube stop
    fi
    
    # Start Minikube with optimal settings for Kafka
    minikube start \
        --memory=3500 \
        --cpus=4 \
        --disk-size=20gb \
        --driver=docker \
        --addons=ingress,metrics-server \
        --embed-certs=true
    
    print_status "Minikube started successfully ✓"
}

# Configure Minikube for better performance
configure_minikube() {
    print_status "Configuring Minikube for better performance..."
    
    # Set Docker environment
    eval $(minikube docker-env)
    
    # Enable metrics server for resource monitoring
    minikube addons enable metrics-server
    
    # Show cluster info
    echo ""
    print_status "Cluster Information:"
    kubectl cluster-info
    echo ""
    kubectl get nodes -o wide
}

# Verify Kubernetes setup
verify_kubernetes() {
    print_status "Verifying Kubernetes setup..."
    
    # Check kubectl connectivity
    if kubectl get nodes &> /dev/null; then
        print_status "Kubernetes cluster is accessible ✓"
    else
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if metrics server is working
    sleep 30  # Give metrics server time to start
    if kubectl top nodes &> /dev/null; then
        print_status "Metrics server is working ✓"
    else
        print_warning "Metrics server may take a few minutes to start"
    fi
}

# Create required namespaces
create_namespaces() {
    print_status "Creating required namespaces..."
    
    kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Namespaces created ✓"
}

# Display next steps
show_next_steps() {
    echo ""
    echo "Minikube setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "   1. Deploy the pipeline: ./scripts/deploy.sh"
    echo "   2. Monitor deployment: kubectl get pods -n kafka -w"
    echo "   3. Access applications:"
    echo "      - Neo4j: kubectl port-forward svc/neo4j 7474:7474 -n kafka"
    echo "      - Kafka: kubectl port-forward svc/data-pipeline-cluster-kafka-bootstrap 9092:9092 -n kafka"
    echo ""
    echo "Useful commands:"
    echo "   - Open Minikube dashboard: minikube dashboard"
    echo "   - Check resources: kubectl top nodes && kubectl top pods -A"
    echo "   - Get service URLs: minikube service list"
}

# Main execution
main() {
    print_status "Starting Minikube setup..."
    
    check_minikube
    check_docker
    start_minikube
    configure_minikube
    verify_kubernetes
    create_namespaces
    show_next_steps
}

main "$@"