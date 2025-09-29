from kafka import KafkaProducer
import json
import time
import random
import os


# Get Kafka bootstrap servers from environment or use default
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
TOPIC_NAME = 'user-events'

conf = {"bootstrap.servers": "localhost:29092"}

producer = KafkaProducer(...)

def create_producer():
    try:
        producer = KafkaProducer(
            bootstrap_servers=[KAFKA_BOOTSTRAP_SERVERS],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            retries=5
        )
        print(f"Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except Exception as e:
        print(f"Failed to connect to Kafka: {e}")
        return None

def produce_sample_data():
    producer = create_producer()
    if not producer:
        print("Cannot create producer. Exiting.")
        return

    user_actions = ['login', 'purchase', 'view', 'logout', 'search']
    
    try:
        for i in range(10):
            message = {
                'user_id': f"user_{random.randint(1000, 9999)}",
                'action': random.choice(user_actions),
                'timestamp': int(time.time()),
                'data': {'page': f'/products/{random.randint(1, 100)}'}
            }
            
            producer.send(TOPIC_NAME, value=message)
            print(f"Sent message {i+1}: {message}")
            time.sleep(2)
            
        producer.flush()
        print("All messages sent successfully!")
        
    except Exception as e:
        print(f"Error producing messages: {e}")
    finally:
        if producer:
            producer.close()

if __name__ == "__main__":
    print("🚀 Starting Kafka Producer...")
    produce_sample_data()