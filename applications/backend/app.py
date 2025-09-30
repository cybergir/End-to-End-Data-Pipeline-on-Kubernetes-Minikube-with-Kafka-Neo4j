from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import asyncio
import json
import logging
from kafka import KafkaConsumer, KafkaProducer
import threading
import os

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

# Store active WebSocket connections
class ConnectionManager:
    def __init__(self):
        self.active_connections = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New WebSocket connection. Total: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
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
        
        # Remove disconnected clients
        for connection in disconnected:
            self.disconnect(connection)

manager = ConnectionManager()

# Kafka configuration
KAFKA_BROKER = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
KAFKA_TOPIC = 'user-events'

def kafka_consumer():
    """Background thread to consume Kafka messages and broadcast via WebSocket"""
    try:
        consumer = KafkaConsumer(
            KAFKA_TOPIC,
            bootstrap_servers=[KAFKA_BOOTSTRAP_SERVERS],
            auto_offset_reset='latest',
            value_deserializer=lambda x: json.loads(x.decode('utf-8'))
        )
        
        logger.info("Kafka consumer started for dashboard")
        
        for message in consumer:
            data = message.value
            # Broadcast to all WebSocket clients
            asyncio.run(manager.broadcast({
                "type": "user_event",
                "data": data,
                "timestamp": data.get('timestamp')
            }))
            
    except Exception as e:
        logger.error(f"Kafka consumer error: {e}")

@app.on_event("startup")
async def startup_event():
    """Start Kafka consumer in background thread on startup"""
    logger.info("Starting Kafka consumer thread...")
    kafka_thread = threading.Thread(target=kafka_consumer, daemon=True)
    kafka_thread.start()
    logger.info("Dashboard backend started successfully!")

@app.get("/")
async def root():
    return {"message": "Real-time Dashboard API", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "dashboard-backend"}

@app.get("/stats")
async def get_stats():
    """Get current dashboard statistics"""
    return {
        "websocket_connections": len(manager.active_connections),
        "status": "running",
        "kafka_topic": KAFKA_TOPIC
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive - client can send ping/pong
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)