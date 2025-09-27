from kafka import KafkaConsumer
from neo4j import GraphDatabase
import json
import os
import logging
import uuid
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
NEO4J_URI = os.getenv('NEO4J_URI', 'bolt://neo4j:7687')
NEO4J_USER = os.getenv('NEO4J_USER', 'neo4j')
NEO4J_PASSWORD = os.getenv('NEO4J_PASSWORD', 'password')
TOPIC_NAME = 'user-events'

class Neo4jConnection:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def close(self):
        self.driver.close()
    
    def create_user_action(self, user_data):
        with self.driver.session() as session:
            result = session.execute_write(self._create_user_action, user_data)
            return result
    
    @staticmethod
    def _create_user_action(tx, user_data):
        # Convert timestamp to ISO format for Neo4j
        timestamp = user_data['timestamp']
        if isinstance(timestamp, int):
            # Convert Unix timestamp to ISO string
            iso_timestamp = datetime.fromtimestamp(timestamp).isoformat()
        else:
            iso_timestamp = timestamp
            
        # Create or update user node
        user_query = """
        MERGE (u:User {id: $user_id})
        SET u.last_seen = datetime($timestamp)
        SET u.last_action = $action
        """
        tx.run(user_query, 
               user_id=user_data['user_id'],
               timestamp=iso_timestamp,
               action=user_data['action'])
        
        # Create action node with simple UUID
        action_id = str(uuid.uuid4())
        action_query = """
        MATCH (u:User {id: $user_id})
        CREATE (a:Action {
            id: $action_id,
            type: $action,
            timestamp: datetime($timestamp),
            page: $page
        })
        CREATE (u)-[:PERFORMED {timestamp: datetime($timestamp)}]->(a)
        RETURN a
        """
        result = tx.run(action_query,
                       user_id=user_data['user_id'],
                       action_id=action_id,
                       action=user_data['action'],
                       timestamp=iso_timestamp,
                       page=user_data.get('data', {}).get('page', 'unknown'))
        return result.single()

def create_kafka_consumer():
    try:
        consumer = KafkaConsumer(
            TOPIC_NAME,
            bootstrap_servers=[KAFKA_BOOTSTRAP_SERVERS],
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            group_id='neo4j-consumer-group',
            value_deserializer=lambda x: json.loads(x.decode('utf-8'))
        )
        logger.info("Connected to Kafka at %s", KAFKA_BOOTSTRAP_SERVERS)
        return consumer
    except Exception as e:
        logger.error("Failed to connect to Kafka: %s", e)
        return None

def process_messages():
    # Create connections
    consumer = create_kafka_consumer()
    neo4j_conn = Neo4jConnection(NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)
    
    if not consumer:
        logger.error("Cannot create Kafka consumer. Exiting.")
        return
    
    logger.info("Starting Kafka Consumer...")
    logger.info("Waiting for messages...")
    
    try:
        for message in consumer:
            data = message.value
            logger.info("Received message: User %s performed %s", data['user_id'], data['action'])
            
            # Process the message and store in Neo4j
            try:
                result = neo4j_conn.create_user_action(data)
                logger.info("Stored in Neo4j: User %s -> %s", data['user_id'], data['action'])
                
            except Exception as e:
                logger.error("Error storing message in Neo4j: %s", e)
                
    except KeyboardInterrupt:
        logger.info("Consumer stopped by user")
    except Exception as e:
        logger.error("Error in consumer loop: %s", e)
    finally:
        consumer.close()
        neo4j_conn.close()
        logger.info("Connections closed")

if __name__ == "__main__":
    process_messages()
