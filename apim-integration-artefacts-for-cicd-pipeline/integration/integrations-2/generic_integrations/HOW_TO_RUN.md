# How to Run the Services

This project contains multiple services that need to be run separately.

## Services Available

1. **File Transfer Service** (`integration_file.bal`) - FTP to NFS file transfer
2. **Database/Employee Service** (`integration_database.bal`) - HTTP REST API on port 9080
3. **WebSocket/Kafka Service** (`integration_websocket_kafka.bal`) - WebSocket server on port 9081

## Important Note

**You CANNOT run all services together** because:
- `integration_file.bal` has a `main()` function that runs an infinite loop
- When you run `bal run`, it tries to execute all `.bal` files together
- This causes conflicts

## How to Run Each Service

### Option 1: Run File Transfer Service Only

```bash
bal run integration_file.bal
```

This will:
- Start the FTP to NFS file transfer service
- Check for new files every minute
- Log transfers to the database
- Run indefinitely until you press Ctrl+C

### Option 2: Run HTTP + WebSocket Services (Without File Transfer)

To run the HTTP and WebSocket services together, you need to temporarily disable the file transfer service:

1. **Rename the file transfer service**:
   ```bash
   mv integration_file.bal integration_file.bal.disabled
   ```

2. **Run the project**:
   ```bash
   bal run
   ```

3. **This will start**:
   - HTTP REST API on `http://localhost:9080`
   - WebSocket server on `ws://localhost:9081`

4. **When done, restore the file**:
   ```bash
   mv integration_file.bal.disabled integration_file.bal
   ```

### Option 3: Run WebSocket Service Only

```bash
bal run integration_websocket_kafka.bal
```

This will start only the WebSocket server on port 9081.

## Testing Each Service

### Test File Transfer Service

```bash
# Run the service
bal run integration_file.bal

# Watch the logs for file transfer activity
# It checks FTP every minute
```

### Test HTTP Service

```bash
# Get all employees
curl http://localhost:9080/employees

# Get employee by ID
curl http://localhost:9080/employees/employee?id=1

# Create new employee
curl -X POST http://localhost:9080/employees/add \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","address":"123 Main St","mobile":"+1-555-0101"}'
```

### Test WebSocket Service

```bash
# Using websocat (install from: https://github.com/vi/websocat)
websocat ws://localhost:9081

# Then send commands:
{"command": "subscribe", "symbol": "AAPL"}
{"command": "unsubscribe"}
{"command": "stop"}
```

Or use JavaScript:
```javascript
const ws = new WebSocket('ws://localhost:9081');

ws.onopen = () => {
    console.log('Connected');
    ws.send(JSON.stringify({command: "subscribe", symbol: "AAPL"}));
};

ws.onmessage = (event) => {
    console.log('Received:', event.data);
};
```

## Checking Server Logs

When you run any service, you'll see startup logs like:

```
========================================
WebSocket Server Starting...
Port: 9081
URL: ws://localhost:9081
Kafka Bootstrap: kafka-b48cc93efa334420a155bc653b4d46be-mbcpdemo1566161367-chore.i.aivencloud.com:24903
Kafka Topic: stock-options
========================================
```

If you don't see these logs, the server didn't start properly.

## Common Issues

### Issue: "WebSocket error - check if server is running"

**Solution**: Make sure you're running the correct service:
```bash
# Disable file transfer first
mv integration_file.bal integration_file.bal.disabled

# Then run
bal run

# Or run WebSocket service directly
bal run integration_websocket_kafka.bal
```

### Issue: "Port already in use"

**Solution**: Another service is using the port. Either:
1. Stop the other service
2. Change the port in `Config.toml`:
   ```toml
   websocketPort = 9082  # Use a different port
   ```

### Issue: "Kafka connection failed"

**Solution**: Make sure you have the certificate files:
- `ca.pem`
- `service.cert`
- `service.key`

These should be in the project root directory.

## Recommended Development Workflow

1. **For File Transfer Development**:
   ```bash
   bal run integration_file.bal
   ```

2. **For API/WebSocket Development**:
   ```bash
   mv integration_file.bal integration_file.bal.disabled
   bal run
   # Develop and test
   mv integration_file.bal.disabled integration_file.bal
   ```

3. **For Production**: Deploy each service separately as microservices
