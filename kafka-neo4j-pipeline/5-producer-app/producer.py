from kafka import KafkaProducer
import json
import time

def create_producer():
    return KafkaProducer(
        bootstrap_servers='localhost:9092',  # Use port-forward in dev
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )

def send_document(producer, doc_id):
    doc = {
        "id": f"doc_{doc_id}",
        "properties": {
            "title": f"Document {doc_id}",
            "content": f"This is sample content for document {doc_id}",
            "timestamp": int(time.time())
        }
    }
    producer.send('documents', value=doc)
    print(f"Sent document {doc_id}")

if __name__ == "__main__":
    producer = create_producer()
    for i in range(1, 6):
        send_document(producer, i)
    producer.flush()