#!/bin/bash
echo "Testing Kafka connectivity..."

# Wait for Kafka pod to be ready
kubectl wait --for=condition=ready pod -l app=kafka -n kafka --timeout=300s

# Test Kafka topics
kubectl exec -it deployment/kafka -n kafka -- kafka-topics.sh --list --bootstrap-server localhost:9092

# Create a test topic
kubectl exec -it deployment/kafka -n kafka -- kafka-topics.sh --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1

echo "Kafka test completed!"
