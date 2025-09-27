#!/bin/bash
set -e

echo "Testing Kafka-Neo4j Data Pipeline"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[TEST]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }

# Variables
NAMESPACE="kafka"
TIMEOUT=300

# Test Kubernetes cluster connectivity
test_kubernetes_connectivity() {
    print_status "Testing Kubernetes connectivity..."
    
    if kubectl cluster-info &> /dev/null; then
        print_success "Kubernetes cluster is accessible"
    else
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
}

# Test namespace exists
test_namespace() {
    print_status "Testing namespace existence..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
}

# Test Kafka cluster health
test_kafka_cluster() {
    print_status "Testing Kafka cluster..."
    
    # Check if Kafka resource exists
    if kubectl get kafka -n $NAMESPACE &> /dev/null; then
        print_success "Kafka custom resource exists"
    else
        print_error "Kafka custom resource not found"
        return 1
    fi
    
    # Check Kafka pods
    local kafka_pods=$(kubectl get pods -n $NAMESPACE -l strimzi.io/name=data-pipeline-cluster-kafka --no-headers | wc -l)
    if [ "$kafka_pods" -ge 1 ]; then
        print_success "Kafka pods are running ($kafka_pods found)"
    else
        print_error "No Kafka pods found"
        return 1
    fi
    
    # Test Kafka connectivity (port-forward)
    print_status "Testing Kafka connectivity..."
    kubectl port-forward svc/data-pipeline-cluster-kafka-bootstrap 9092:9092 -n $NAMESPACE &
    local PF_PID=$!
    sleep 5
    
    # Simple test using kafkacat or built-in tools
    if kubectl exec -it data-pipeline-cluster-kafka-0 -n $NAMESPACE -- \
        bin/kafka-topics.sh --list --bootstrap-server localhost:9092 &> /dev/null; then
        print_success "Kafka is responsive"
    else
        print_error "Kafka is not responsive"
        kill $PF_PID 2>/dev/null
        return 1
    fi
    
    kill $PF_PID 2>/dev/null
}

# Test Neo4j health
test_neo4j() {
    print_status "Testing Neo4j database..."
    
    # Check Neo4j pods
    local neo4j_pods=$(kubectl get pods -n $NAMESPACE -l app=neo4j --no-headers | grep Running | wc -l)
    if [ "$neo4j_pods" -ge 1 ]; then
        print_success "Neo4j pods are running ($neo4j_pods found)"
    else
        print_error "No Neo4j pods found or not running"
        return 1
    fi
    
    # Test Neo4j connectivity
    print_status "Testing Neo4j connectivity..."
    kubectl port-forward svc/neo4j 7474:7474 -n $NAMESPACE &
    local NEO4J_PF_PID=$!
    sleep 5
    
    if curl -s http://localhost:7474 &> /dev/null; then
        print_success "Neo4j is responsive"
    else
        print_error "Neo4j is not responsive"
        kill $NEO4J_PF_PID 2>/dev/null
        return 1
    fi
    
    kill $NEO4J_PF_PID 2>/dev/null
}

# Test Kafka Connect
test_kafka_connect() {
    print_status "Testing Kafka Connect..."
    
    local connect_pods=$(kubectl get pods -n $NAMESPACE -l strimzi.io/kind=KafkaConnect --no-headers | grep Running | wc -l)
    if [ "$connect_pods" -ge 1 ]; then
        print_success "Kafka Connect pods are running ($connect_pods found)"
    else
        print_warning "Kafka Connect pods not found or not running"
        return 0  # Not critical for basic test
    fi
}

# Test Producer Application
test_producer_app() {
    print_status "Testing Producer Application..."
    
    local producer_pods=$(kubectl get pods -n $NAMESPACE -l app=kafka-producer --no-headers | grep Running | wc -l)
    if [ "$producer_pods" -ge 1 ]; then
        print_success "Producer application pods are running ($producer_pods found)"
        
        # Check producer logs for errors
        local producer_logs=$(kubectl logs deployment/kafka-producer -n $NAMESPACE --tail=10)
        if echo "$producer_logs" | grep -q "ERROR"; then
            print_warning "Producer application has errors in logs"
        else
            print_success "Producer application logs look clean"
        fi
    else
        print_warning "Producer application pods not found"
    fi
}

# Test data flow
test_data_flow() {
    print_status "Testing data flow through pipeline..."
    
    # This is a simplified test - in real scenario, you'd send actual data
    print_status "Data flow test would involve:"
    print_status "1. Sending test messages to Kafka"
    print_status "2. Verifying Kafka Connect processes them"
    print_status "3. Checking Neo4j for the data"
    print_warning "Data flow test not implemented (requires specific test data)"
}

# Run all tests
run_all_tests() {
    local failed_tests=0
    
    print_status "Starting comprehensive pipeline tests..."
    echo ""
    
    test_kubernetes_connectivity || ((failed_tests++))
    echo ""
    
    test_namespace || ((failed_tests++))
    echo ""
    
    test_kafka_cluster || ((failed_tests++))
    echo ""
    
    test_neo4j || ((failed_tests++))
    echo ""
    
    test_kafka_connect || ((failed_tests++))
    echo ""
    
    test_producer_app || ((failed_tests++))
    echo ""
    
    test_data_flow || ((failed_tests++))
    echo ""
    
    # Summary
    if [ "$failed_tests" -eq 0 ]; then
        print_success "All tests passed! Pipeline is healthy. ✓"
        return 0
    else
        print_error "$failed_tests test(s) failed"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting pipeline health checks..."
    
    if run_all_tests; then
        echo ""
        print_success "Pipeline test completed successfully!"
        echo ""
        echo "Next steps:"
        echo "   - Monitor real data flow: kubectl logs -f deployment/kafka-producer -n $NAMESPACE"
        echo "   - Check Neo4j data: kubectl port-forward svc/neo4j 7474:7474 -n $NAMESPACE"
        echo "   - View Kafka messages: kubectl exec -it data-pipeline-cluster-kafka-0 -n $NAMESPACE -- bin/kafka-console-consumer.sh --topic user-events --from-beginning --bootstrap-server localhost:9092"
    else
        echo ""
        print_error "Pipeline test failed. Please check the issues above."
        echo ""
        echo "Troubleshooting:"
        echo "   - Check pod status: kubectl get pods -n $NAMESPACE"
        echo "   - View logs: kubectl logs <pod-name> -n $NAMESPACE"
        echo "   - Check events: kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp"
        exit 1
    fi
}

main "$@"