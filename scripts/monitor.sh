#!/bin/bash

echo "Monitoring Kafka-Neo4j Data Pipeline"
echo "======================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="kafka"

# Function to print colored output
print_header() { echo -e "${BLUE}$1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Display cluster overview
cluster_overview() {
    print_header "Cluster Overview"
    echo "Namespace: $NAMESPACE"
    echo "Timestamp: $(date)"
    echo ""
    
    kubectl get nodes -o wide
    echo ""
}

# Display resource usage
resource_usage() {
    print_header "Resource Usage"
    
    if kubectl top nodes &> /dev/null; then
        echo "Node Resources:"
        kubectl top nodes
        echo ""
        
        echo "Pod Resources:"
        kubectl top pods -n $NAMESPACE
    else
        print_warning "Metrics server not available. Start with: minikube addons enable metrics-server"
    fi
    echo ""
}

# Display pod status
pod_status() {
    print_header "Pod Status"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    
    # Check for non-running pods
    local not_running=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v Running | grep -v Completed | wc -l)
    if [ "$not_running" -gt 0 ]; then
        print_error "There are $not_running pod(s) not running:"
        kubectl get pods -n $NAMESPACE --no-headers | grep -v Running | grep -v Completed
        echo ""
    fi
}

# Display service status
service_status() {
    print_header "Service Status"
    kubectl get svc -n $NAMESPACE
    echo ""
}

# Display Kafka specific metrics
kafka_metrics() {
    print_header "Kafka Metrics"
    
    # Check Kafka topics
    if kubectl get pods -n $NAMESPACE -l strimzi.io/name=data-pipeline-cluster-kafka --no-headers &> /dev/null; then
        print_success "Kafka cluster is running"
        
        # Get topic list (if Kafka is ready)
        if kubectl exec -it data-pipeline-cluster-kafka-0 -n $NAMESPACE -- \
            bin/kafka-topics.sh --list --bootstrap-server localhost:9092 &> /dev/null; then
            echo "Kafka Topics:"
            kubectl exec -it data-pipeline-cluster-kafka-0 -n $NAMESPACE -- \
                bin/kafka-topics.sh --list --bootstrap-server localhost:9092
        else
            print_warning "Kafka not ready for topic listing"
        fi
    else
        print_error "Kafka cluster not found"
    fi
    echo ""
}

# Display Neo4j status
neo4j_status() {
    print_header "🕸️  Neo4j Status"
    
    if kubectl get pods -n $NAMESPACE -l app=neo4j --no-headers &> /dev/null; then
        print_success "Neo4j is running"
        
        # Check Neo4j readiness
        local neo4j_pod=$(kubectl get pods -n $NAMESPACE -l app=neo4j -o jsonpath='{.items[0].metadata.name}')
        if kubectl exec -it $neo4j_pod -n $NAMESPACE -- curl -s http://localhost:7474 &> /dev/null; then
            print_success "Neo4j web interface is accessible"
        else
            print_warning "Neo4j web interface not accessible"
        fi
    else
        print_error "Neo4j not found"
    fi
    echo ""
}

# Display recent events
recent_events() {
    print_header "Recent Events"
    kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp --field-selector type!=Normal | tail -10
    echo ""
}

# Continuous monitoring mode
continuous_monitor() {
    print_header "🔄 Continuous Monitoring (Ctrl+C to stop)"
    watch -n 10 "kubectl get pods -n $NAMESPACE && echo '' && kubectl get svc -n $NAMESPACE"
}

# Interactive menu
interactive_menu() {
    while true; do
        echo ""
        print_header "Monitoring Menu"
        echo "1. Cluster Overview"
        echo "2. Resource Usage"
        echo "3. Pod Status"
        echo "4. Kafka Metrics"
        echo "5. Neo4j Status"
        echo "6. Recent Events"
        echo "7. Continuous Monitor"
        echo "8. Exit"
        echo ""
        read -p "Select option (1-8): " choice
        
        case $choice in
            1) cluster_overview ;;
            2) resource_usage ;;
            3) pod_status ;;
            4) kafka_metrics ;;
            5) neo4j_status ;;
            6) recent_events ;;
            7) continuous_monitor ;;
            8) break ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Main function
main() {
    case "${1:-}" in
        "overview")
            cluster_overview
            ;;
        "resources")
            resource_usage
            ;;
        "pods")
            pod_status
            ;;
        "kafka")
            kafka_metrics
            ;;
        "neo4j")
            neo4j_status
            ;;
        "events")
            recent_events
            ;;
        "continuous")
            continuous_monitor
            ;;
        "interactive"|"")
            interactive_menu
            ;;
        *)
            echo "Usage: $0 [overview|resources|pods|kafka|neo4j|events|continuous|interactive]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"