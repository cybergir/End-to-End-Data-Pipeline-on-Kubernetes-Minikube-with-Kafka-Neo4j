kafka-neo4j-pipeline/
├── 1-minikube/
│ └── minikube-setup.md
├── 2-strimzi-kafka/
│ ├── strimzi-install.yaml
│ ├── kafka-cluster.yaml
│ └── kafka-topics.yaml
├── 3-neo4j/
│ ├── neo4j-helm-values.yaml
│ └── neo4j-ingress.yaml
├── 4-kafka-connect/
│ ├── Dockerfile.neo4j-connector
│ ├── kafka-connect-cluster.yaml
│ └── neo4j-sink-connector.yaml
├── 5-producer-app/
│ ├── producer.py
│ └── requirements.txt
└── README.md
