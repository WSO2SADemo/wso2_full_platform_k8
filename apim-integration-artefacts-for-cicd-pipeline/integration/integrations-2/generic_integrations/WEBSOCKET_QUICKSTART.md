# WebSocket Server Quick Start Guide

## Problem

When you run `bal run integration_websocket_kafka.bal`, the file transfer service's `main()` function also runs and blocks the WebSocket server from accepting connections.

## Solution: Run WebSocket Server Only

### Option 1: Temporarily Disable File Transfer (Recommended)

```bash
# 1. Rename the file transfer service
mv integration_file.bal integration_file.bal.disabled

# 2. Run the WebSocket server
bal run integration_websocket_kafka.bal integration_database.bal

# 3. When done, restore the file
mv integration_file.bal.disabled integration_file.bal
```

### Option 2: Comment Out main() Function

Edit `integration_file.bal` and comment out the `main()` function:

```ballerina
// public function main() returns error? {
//     ... entire function ...
// }
```

Then run:
```bash
bal run
```

## Verify WebSocket Server is Running

You should see these logs:

```
========================================
WebSocket Server Starting...
Port: 9081
URL: ws://localhost:9081
Kafka Bootstrap: kafka-...
Kafka Topic: stock-options
========================================
```

## Test the WebSocket Connection

### Using JavaScript (Browser Console or Node.js)

```javascript
const ws = new WebSocket('ws://localhost:9081');

ws.onopen = () => {
    console.log('✓ Connected to WebSocket server');
    
    // Subscribe to Apple stock
    ws.send(JSON.stringify({
        command: "subscribe",
        symbol: "AAPL"
    }));
};

ws.onmessage = (event) => {
    console.log('Received:', event.data);
};

ws.onerror = (error) => {
    console.error('WebSocket Error:', error);
};

ws.onclose = (event) => {
    console.log('Disconnected:', event.code, event.reason);
};
```

### Using websocat (Command Line)

```bash
# Install websocat first: https://github.com/vi/websocat
# macOS: brew install websocat
# Linux: Download from releases

websocat ws://localhost:9081

# Then type commands:
{"command": "subscribe", "symbol": "AAPL"}
{"command": "unsubscribe"}
{"command": "stop"}
```

### Using Python

```python
import websocket
import json

def on_message(ws, message):
    print(f"Received: {message}")

def on_open(ws):
    print("✓ Connected to WebSocket server")
    ws.send(json.dumps({"command": "subscribe", "symbol": "AAPL"}))

ws = websocket.WebSocketApp(
    "ws://localhost:9081",
    on_open=on_open,
    on_message=on_message
)

ws.run_forever()
```

### Using curl (with wscat)

```bash
# Install wscat: npm install -g wscat
wscat -c ws://localhost:9081

# Then type:
{"command": "subscribe", "symbol": "AAPL"}
```

## Available Commands

### Subscribe to a Stock Symbol
```json
{"command": "subscribe", "symbol": "AAPL"}
```

### Unsubscribe from Current Symbol
```json
{"command": "unsubscribe"}
```

### Stop Streaming
```json
{"command": "stop"}
```

## Expected Responses

### Connection Success
```json
{
  "status": "connected",
  "message": "Connected to stock data stream. Send {\"command\": \"subscribe\", \"symbol\": \"AAPL\"} to start receiving stock data."
}
```

### Subscription Success
```json
{
  "status": "subscribed",
  "message": "Subscribed to AAPL. Streaming stock data..."
}
```

### Stock Data (from Kafka)
The actual stock data will be forwarded from the Kafka topic `stock-options`, filtered by your subscribed symbol.

## Troubleshooting

### Issue: "Connection refused" or "Failed to connect"

**Cause**: The WebSocket server is not running or blocked by the file transfer service.

**Solution**: 
1. Stop the current process (Ctrl+C)
2. Disable the file transfer service:
   ```bash
   mv integration_file.bal integration_file.bal.disabled
   ```
3. Run again:
   ```bash
   bal run integration_websocket_kafka.bal integration_database.bal
   ```

### Issue: "No logs showing WebSocket server starting"

**Cause**: The file transfer service's `main()` function is running first.

**Solution**: Follow Option 1 above to disable the file transfer service.

### Issue: "Kafka connection errors"

**Cause**: Missing certificate files or incorrect Kafka configuration.

**Solution**: 
1. Ensure these files exist in your project root:
   - `ca.pem`
   - `service.cert`
   - `service.key`
2. Verify Kafka bootstrap server is accessible

## Running All Services Separately

For production or development, run each service in a separate terminal:

**Terminal 1 - File Transfer Service:**
```bash
bal run integration_file.bal
```

**Terminal 2 - HTTP + WebSocket Services:**
```bash
# Temporarily disable file transfer
mv integration_file.bal integration_file.bal.disabled
bal run integration_websocket_kafka.bal integration_database.bal
# Restore when done
mv integration_file.bal.disabled integration_file.bal
```

## Quick Test Script

Create a file `test_websocket.js`:

```javascript
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:9081');

ws.on('open', function open() {
    console.log('✓ Connected to WebSocket server');
    console.log('Subscribing to AAPL...');
    ws.send(JSON.stringify({
        command: "subscribe",
        symbol: "AAPL"
    }));
});

ws.on('message', function message(data) {
    console.log('Received:', data.toString());
});

ws.on('error', function error(err) {
    console.error('❌ WebSocket Error:', err.message);
});

ws.on('close', function close() {
    console.log('Disconnected from server');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nClosing connection...');
    ws.close();
    process.exit(0);
});
```

Run with:
```bash
node test_websocket.js
```
