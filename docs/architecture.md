## Architecture Diagram

┌─────────────────┐ ┌──────────────────┐ ┌─────────────────┐
│ Producer App │───▶│ Kafka Cluster │───▶│ Consumer App │
│ (Python) │ │ (Strimzi) │ │ (Python) │
└─────────────────┘ └──────────────────┘ └─────────────────┘
│ │ │
└───────────────────────┼───────────────────────┘
│
┌──────────────────┐
│ Neo4j Database │
│ (Helm) │
└──────────────────┘

## Components

### 2. Data Processing Layer

- Apache Kafka: Distributed streaming platform
  - Topics: `user-events`, `neo4j-commands`
  - Brokers: 1-node cluster (scalable to multiple nodes)
- Python Consumer: Custom consumer application that processes Kafka messages and stores them in Neo4j

### 4. Application Layer

- Python Producer: Generates sample user event data
- Python Consumer: Processes real-time data and persists to Neo4j

## Data Flow

1. Producer → Kafka Topic (user-events)
2. Python Consumer consumes from topic and processes data
3. Neo4j stores graph relationships for querying
4. Applications query Neo4j for insights
