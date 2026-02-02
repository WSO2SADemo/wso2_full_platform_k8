// This is a standalone WebSocket server file
// Run this file separately with: bal run websocket_server.bal
// 
// NOTE: This file cannot be run together with integration_file.bal 
// because both have main() functions.
//
// To run the WebSocket server:
// 1. Make sure you have the required certificate files (ca.pem, service.cert, service.key)
// 2. Set the websocketPort in Config.toml
// 3. Run: bal run websocket_server.bal
//
// The server will start on ws://localhost:9081 (or your configured port)