from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import logging
import time
from datetime import datetime
from kafka import KafkaConsumer
import threading
import os
import psutil
import random

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Real-time Dashboard API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ConnectionManager:
    def __init__(self):
        self.active_connections = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New WebSocket connection. Total: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        logger.info(f"WebSocket disconnected. Total: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error sending message: {e}")
                disconnected.append(connection)
        
        for connection in disconnected:
            self.disconnect(connection)

manager = ConnectionManager()

KAFKA_BROKER = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
KAFKA_TOPIC = 'user-events'

def kafka_consumer():
    """Background thread to consume Kafka messages and broadcast via WebSocket"""
    retry_count = 0
    max_retries = 5
    
    while retry_count < max_retries:
        try:
            logger.info(f"🔄 Connecting to Kafka at {KAFKA_BROKER}...")
            
            consumer = KafkaConsumer(
                KAFKA_TOPIC,
                bootstrap_servers=[KAFKA_BROKER],
                auto_offset_reset='latest',
                value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                group_id='dashboard-consumer',
                consumer_timeout_ms=10000
            )
            
            logger.info("Kafka consumer connected!")
            retry_count = 0
            
            for message in consumer:
                data = message.value
                logger.info(f"Kafka message: {data}")
                
                asyncio.run(manager.broadcast({
                    "type": "user_event", 
                    "data": data,
                    "timestamp": data.get('timestamp')
                }))
                logger.info(f"Broadcasted to {len(manager.active_connections)} clients")
                
        except Exception as e:
            retry_count += 1
            logger.error(f"Kafka error ({retry_count}/{max_retries}): {e}")
            time.sleep(10)


async def broadcast_system_metrics():
    """Periodically broadcast system metrics (CPU, memory, etc.)."""
    while True:
        metrics = {
            "cpu": psutil.cpu_percent(),
            "memory": psutil.virtual_memory().percent,
            "disk": psutil.disk_usage('/').percent
        }
        await manager.broadcast({
            "systemMetrics": metrics
        })
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    logger.info("Starting backend services...")
    kafka_thread = threading.Thread(target=kafka_consumer, daemon=True)
    kafka_thread.start()
    logger.info("Dashboard backend ready!")

@app.get("/stats")
async def get_stats():
    return {
        "websocket_connections": len(manager.active_connections),
        "status": "running",
        "kafka_topic": KAFKA_TOPIC
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    client_id = id(websocket)

    try:
        await websocket.send_json({
            "type": "connection_established",
            "client_id": client_id,
            "message": "Connected to real-time dashboard"
        })

        async def send_system_metrics():
            while True:
                try:
                    # Collect real system metrics
                    system_metrics = {
                        "cpu_percent": psutil.cpu_percent(),
                        "memory_percent": psutil.virtual_memory().percent,
                        "disk_usage": psutil.disk_usage('/').percent,
                        "timestamp": datetime.now().isoformat()
                    }
                    
                    # Generate simulated user activity
                    user_activity = {
                        "logins": random.randint(1, 10),
                        "signups": random.randint(1, 5),
                        "purchases": random.randint(1, 8),
                        "page_views": random.randint(10, 50)
                    }
                    
                    # Generate Kafka throughput simulation
                    kafka_metrics = {
                        "in_rate": random.randint(800, 1200),
                        "out_rate": random.randint(700, 950),
                        "timestamp": datetime.now().isoformat()
                    }
                    
                    # Send everything to the client
                    await websocket.send_json({
                        "type": "metrics_update",
                        "systemMetrics": system_metrics,
                        "userActivity": user_activity,
                        "kafkaMetrics": [kafka_metrics],
                        "timestamp": datetime.now().isoformat()
                    })
                    
                    await asyncio.sleep(2)
                    
                except Exception as e:
                    print(f"Error sending metrics: {e}")
                    break
        
        
        metrics_task = asyncio.create_task(send_system_metrics())
        
        while True:
            data = await websocket.receive_text()
            
            try:
                message = json.loads(data)
                message_type = message.get("type")
                
                if message_type == "ping":
                    await websocket.send_json({
                        "type": "pong",
                        "timestamp": datetime.now().isoformat()
                    })
                
                elif message_type == "request_metrics":
                    
                    system_metrics = {
                        "cpu_percent": psutil.cpu_percent(),
                        "memory_percent": psutil.virtual_memory().percent,
                        "disk_usage": psutil.disk_usage('/').percent,
                    }
                    await websocket.send_json({
                        "type": "instant_metrics",
                        "systemMetrics": system_metrics
                    })
                
                elif message_type == "set_refresh_rate":
                    refresh_rate = message.get("rate", 2)
                    
                    await websocket.send_json({
                        "type": "refresh_rate_updated",
                        "rate": refresh_rate
                    })
                    
            except json.JSONDecodeError:
                
                if data == "ping":
                    await websocket.send_text("pong")
    
    except WebSocketDisconnect:
        metrics_task.cancel()
        manager.disconnect(websocket)
        print(f"Client {client_id} disconnected")
    
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket)

async def collect_system_metrics():
    return {
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'latency_ms': random.randint(10, 100),
        'timestamp': datetime.now().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)