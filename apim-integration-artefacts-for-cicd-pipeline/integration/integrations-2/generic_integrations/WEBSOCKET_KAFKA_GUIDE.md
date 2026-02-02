# WebSocket-Kafka Integration Guide

## Overview

This integration provides a real-time bidirectional communication system using WebSocket and Kafka:
- **WebSocket Service**: Accepts client connections and receives messages
- **Kafka Producer**: Publishes messages from WebSocket clients to Kafka topics
- **Kafka Consumer**: Consumes messages from Kafka and broadcasts to all connected WebSocket clients

## Architecture

```
WebSocket Clients <--> WebSocket Service <--> Kafka Broker
                            ^                      |
                            |                      |
                            +-- Kafka Consumer <---+
```

## Configuration

Add these environment variables:

```bash
# Kafka Configuration
export kafkaBootstrapServers="localhost:9092"
export kafkaGroupId="websocket-consumer-group"
export kafkaTopic="websocket-messages"

# WebSocket Configuration (optional, defaults to 9090)
# websocketPort is configurable in config.bal
```

## Running the Services

### 1. Start the WebSocket Service (with HTTP services)
```bash
bal run
```

This starts:
- WebSocket service on port 9090 (configurable)
- HTTP services on port 8080
- File transfer automation

### 2. Start the Kafka Consumer (separate process)
```bash
bal run --observability-included kafka_consumer_main.bal
```

This starts the Kafka consumer that broadcasts messages to WebSocket clients.

## WebSocket API

### Endpoint
```
ws://localhost:9090/ws
```

### Message Format

All messages should be JSON with this structure:

```json
{
  "messageType": "USER",
  "content": "Your message here",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Message Types:**
- `USER` - User-generated messages
- `SYSTEM` - System notifications
- `ACK` - Acknowledgments
- `ERROR` - Error messages

### Client Connection Flow

1. **Connect**: Client connects to `ws://localhost:9090/ws`
2. **Welcome**: Server sends welcome message with client ID
3. **Send Messages**: Client sends JSON messages
4. **Receive**: Client receives messages from Kafka (broadcast to all clients)
5. **Disconnect**: Client closes connection

## Example Usage

### JavaScript WebSocket Client

```javascript
const ws = new WebSocket('ws://localhost:9090/ws');

ws.onopen = () => {
    console.log('Connected to WebSocket');
    
    // Send a message
    const message = {
        messageType: 'USER',
        content: 'Hello from client!',
        timestamp: new Date().toISOString()
    };
    
    ws.send(JSON.stringify(message));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};

ws.onerror = (error) => {
    console.error('WebSocket error:', error);
};

ws.onclose = () => {
    console.log('Disconnected from WebSocket');
};
```

### Python WebSocket Client

```python
import websocket
import json
from datetime import datetime

def on_message(ws, message):
    data = json.loads(message)
    print(f"Received: {data}")

def on_open(ws):
    print("Connected to WebSocket")
    
    # Send a message
    message = {
        "messageType": "USER",
        "content": "Hello from Python!",
        "timestamp": datetime.now().isoformat()
    }
    
    ws.send(json.dumps(message))

ws = websocket.WebSocketApp(
    "ws://localhost:9090/ws",
    on_message=on_message,
    on_open=on_open
)

ws.run_forever()
```

## Message Flow

### Publishing to Kafka (Client → Kafka)

1. Client sends JSON message to WebSocket
2. WebSocket service validates message format
3. Message is published to Kafka topic
4. Client receives ACK or ERROR response

### Broadcasting from Kafka (Kafka → Clients)

1. Kafka consumer polls for messages
2. Messages are received from Kafka topic
3. Messages are broadcast to all connected WebSocket clients
4. Each client receives the message in real-time

## Features

- **Real-time Communication**: Instant message delivery via WebSocket
- **Scalable Messaging**: Kafka handles message persistence and distribution
- **Multiple Clients**: Supports multiple concurrent WebSocket connections
- **Error Handling**: Comprehensive error handling and logging
- **Client Tracking**: Each client gets a unique ID
- **Broadcast Support**: Messages from Kafka are broadcast to all clients

## Monitoring

Check logs for:
- Client connections/disconnections
- Message publishing to Kafka
- Message broadcasting to clients
- Error conditions

## Troubleshooting

**WebSocket connection fails:**
- Check if port 9090 is available
- Verify WebSocket service is running

**Messages not publishing to Kafka:**
- Verify Kafka broker is running
- Check `kafkaBootstrapServers` configuration
- Ensure topic exists or auto-creation is enabled

**Messages not received from Kafka:**
- Ensure Kafka consumer is running (kafka_consumer_main.bal)
- Check Kafka topic has messages
- Verify consumer group configuration
