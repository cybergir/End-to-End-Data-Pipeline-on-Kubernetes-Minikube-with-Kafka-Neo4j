#kafka-neo4j-pipeline/
##├── 1-minikube/
##│ └── minikube-setup.md
##├── 2-strimzi-kafka/
##│ ├── strimzi-install.yaml
##│ ├── kafka-cluster.yaml
##│ └── kafka-topics.yaml
##├── 3-neo4j/
##│ ├── neo4j-helm-values.yaml
##│ └── neo4j-ingress.yaml
##├── 4-kafka-connect/
##│ ├── Dockerfile.neo4j-connector
##│ ├── kafka-connect-cluster.yaml
##│ └── neo4j-sink-connector.yaml
##├── 5-producer-app/
##│ ├── producer.py
##│ └── requirements.txt
##└── README.md

# Start Minikube cluster

minikube start --driver=docker --cpus=2 --memory=4000

# Enable required addons

minikube addons enable ingress
minikube addons enable metrics-server

# Verify

kubectl get nodes
minikube status

# End-to-End Data Pipeline on Minikube

## Components

1. Minikube Kubernetes cluster
2. Strimzi Kafka with Zookeeper
3. Neo4j database
4. Kafka Connect with Neo4j Sink Connector
5. Python Producer Application

## Setup Instructions

1. Start Minikube: `minikube start`
2. Deploy Kafka: `kubectl apply -f 2-strimzi-kafka/`
3. Install Neo4j: `helm install -f 3-neo4j/neo4j-helm-values.yaml`
4. Deploy Kafka Connect: `kubectl apply -f 4-kafka-connect/`
5. Run producer: `python 5-producer-app/producer.py`
