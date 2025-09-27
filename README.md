# End-to-End Data Pipeline on Kubernetes with Kafka & Neo4j

![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.29-blue?logo=kubernetes)
![Kafka](https://img.shields.io/badge/Kafka-3.6.0-black?logo=apachekafka)
![Neo4j](https://img.shields.io/badge/Neo4j-5.x-blue?logo=neo4j)
![Python](https://img.shields.io/badge/Python-3.10+-yellow?logo=python)

Real-time data pipeline demonstrating Kafka streaming, Neo4j graph storage, and Kubernetes orchestration.
Features Python microservices for event processing and production-ready DevOps practices.

Real-time data pipeline demonstrating Kafka streaming, Neo4j graph storage, and Kubernetes orchestration.
Features Python microservices for event processing and production-ready DevOps practices.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Python 3.x](https://www.python.org/downloads/) (for producer/consumer apps)
- [Neo4j Browser](https://neo4j.com/download/) (optional, can also access via port-forwarding)

---

## Setup Instructions

### 1. Start Minikube

```bash
minikube start --driver=docker
```

Check cluster status:

```bash
minikube status
```

### 2. Verify Cluster Nodes

```bash
kubectl get nodes
```

### 3. Check Namespaces

```bash
kubectl get namespaces
```

### 4. Create a Namespace for Kafka

```bash
kubectl create namespace kafka
```

Verify:

```bash
kubectl get pods -n kafka
```

### 5. Install Strimzi Operator

```bash
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
```

---

## Kafka Setup

1. 1. Deploy Kafka cluster using Strimzi (YAML included in `k8s-deployments/` folder).
2. Verify Kafka pods:

   ```bash
   kubectl get pods -n kafka
   ```

---

## Running Producer & Consumer Apps

### Producer

Build and run:

```bash
cd applications/producer-app
docker build -t kafka-producer .
kubectl apply -f producer-deployment.yaml
```

Or run locally with Python:

```bash
python producer.py
```

### Consumer

Build and run:

```bash
cd applications/consumer-app
docker build -t kafka-consumer .
kubectl apply -f consumer-deployment.yaml
```

Or run locally with Python:

```bash
python consumer.py
```

---

## Neo4j Setup

Deploy Neo4j:

```bash
kubectl apply -f neo4j-deployment.yaml -n kafka
```

Port-forward to access locally:

```bash
kubectl port-forward -n kafka deployment/neo4j 7474:7474 7687:7687
```

Web UI: [http://localhost:7474](http://localhost:7474)
Bolt (Python/Apps): `bolt://localhost:7687`

---

## End-to-End Test

1. Produce a message:

   ```bash
   kubectl exec -n kafka -it deployment/kafka -- \
   bash -c "echo '{\"user_id\": \"123\", \"action\": \"login\", \"timestamp\": \"2025-09-25T12:00:00Z\"}' \
   | kafka-console-producer.sh --bootstrap-server localhost:9092 --topic user-events"
   ```

2. Consume the message:

   ```bash
   kubectl exec -n kafka -it deployment/kafka -- \
   kafka-console-consumer.sh --bootstrap-server localhost:9092 \
   --topic user-events --from-beginning --max-messages 1
   ```

3. Verify in Neo4j Browser or via API queries.

---
