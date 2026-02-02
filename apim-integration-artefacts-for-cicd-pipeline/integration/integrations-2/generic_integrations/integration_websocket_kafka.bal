import ballerina/io;
import ballerina/websocket;
import ballerina/lang.runtime;
import ballerinax/kafka;
import ballerina/log;

string kafkaBootstrapServers1 = "kafka-b48cc93efa334420a155bc653b4d46be-mbcpdemo1566161367-chore.i.aivencloud.com:24903";
string kafkaTopic1 = "stock-options"; // Topic for stock option data

// Kafka SSL/TLS configuration for Aiven
string kafkaSecurityProtocol = "SSL";
string kafkaSslCaLocation = "./ca.pem";
string kafkaSslCertLocation = "./service.cert";
string kafkaSslKeyLocation = "./service.key";

// Kafka Consumer configuration
string kafkaConsumerGroup = "stock-websocket-consumers"; // Consumer group for stock data
string kafkaAutoOffsetReset = "latest"; // "latest" for new messages only, "earliest" for all messages
int kafkaPollTimeoutMs = 1000; // Poll timeout in milliseconds

// Initialize Kafka consumer with SSL/TLS configuration
final kafka:Consumer kafkaConsumer = check new (
    bootstrapServers = kafkaBootstrapServers1,
    groupId = kafkaConsumerGroup,
    topics = [kafkaTopic1],
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: kafkaSslCaLocation,
        key: {
            certFile: kafkaSslCertLocation,
            keyFile: kafkaSslKeyLocation
        }
    },
    offsetReset = kafka:OFFSET_RESET_LATEST
);

// WebSocket listener using configured port
listener websocket:Listener wsListener = check new (websocketPort);

// Log server startup
function init() {
    log:printInfo(string `========================================`);
    log:printInfo(string `WebSocket Server Starting...`);
    log:printInfo(string `Port: ${websocketPort}`);
    log:printInfo(string `URL: ws://localhost:${websocketPort}`);
    log:printInfo(string `Kafka Bootstrap: ${kafkaBootstrapServers1}`);
    log:printInfo(string `Kafka Topic: ${kafkaTopic1}`);
    log:printInfo(string `========================================`);
}

// Stock data streaming service - Consumes from Kafka and streams to WebSocket clients
service / on wsListener {
    resource function get .() returns websocket:Service {
        return new StockStreamService();
    }
}

// StockStreamService - Consumes stock data from Kafka and streams to WebSocket clients
service class StockStreamService {
    *websocket:Service;

    private boolean isStreaming = false;
    private string? subscribedSymbol = ();

    remote function onOpen(websocket:Caller caller) returns error? {
        string connectionId = caller.getConnectionId();
        log:printInfo(string `✓ WebSocket client connected: ${connectionId}`);
        io:println(string `Stock stream client connected: ${connectionId}`);

        // Send welcome message
        StatusResponse welcomeMsg = {
            status: "connected",
            message: string `Connected to stock data stream. Send {\"command\": \"subscribe\", \"symbol\": \"AAPL\"} to start receiving stock data.`
        };
        check caller->writeMessage(welcomeMsg.toJsonString());

        return;
    }

    remote function onMessage(websocket:Caller caller, string text) returns error? {
        string trimmedText = text.trim();

        if trimmedText == "" {
            return;
        }

        // Parse incoming command
        json|error messageJson = trimmedText.fromJsonString();
        if messageJson is error {
            ErrorResponse errResponse = {
                'error: "Invalid JSON",
                message: "Please send valid JSON. Example: {\"command\": \"subscribe\", \"symbol\": \"AAPL\"}"
            };
            check caller->writeMessage(errResponse.toJsonString());
            return;
        }

        // Convert to StockCommand type
        StockCommand|error cmd = messageJson.cloneWithType();
        if cmd is error {
            ErrorResponse errResponse = {
                'error: "Invalid command format",
                message: "Valid commands: subscribe, unsubscribe, stop. Example: {\"command\": \"subscribe\", \"symbol\": \"AAPL\"}"
            };
            check caller->writeMessage(errResponse.toJsonString());
            return;
        }

        // Handle different commands
        match cmd.command {
            "subscribe" => {
                // Check if symbol is provided
                string? symbolValue = cmd?.symbol;
                if symbolValue is () {
                    ErrorResponse errResponse = {
                        'error: "Missing symbol",
                        message: "Please provide a stock symbol. Example: {\"command\": \"subscribe\", \"symbol\": \"AAPL\"}"
                    };
                    check caller->writeMessage(errResponse.toJsonString());
                    return;
                }

                string symbol = symbolValue;

                // Stop current streaming if any
                if self.isStreaming {
                    StatusResponse msg = {
                        status: "switching",
                        message: string `Switching from ${self.subscribedSymbol.toString()} to ${symbol}`
                    };
                    check caller->writeMessage(msg.toJsonString());
                    self.isStreaming = false;
                    runtime:sleep(0.5); // Give time for current stream to stop
                }

                // Start streaming for new symbol
                self.subscribedSymbol = symbol;
                self.isStreaming = true;

                StatusResponse ackMsg = {
                    status: "subscribed",
                    message: string `Subscribed to ${symbol}. Streaming stock data...`
                };
                check caller->writeMessage(ackMsg.toJsonString());

                // Start Kafka polling
                _ = start self.pollKafkaAndStream(caller, symbol);
            }
            "unsubscribe" => {
                if !self.isStreaming {
                    StatusResponse msg = {
                        status: "info",
                        message: "No active subscription to unsubscribe"
                    };
                    check caller->writeMessage(msg.toJsonString());
                    return;
                }

                self.isStreaming = false;
                string? previousSymbol = self.subscribedSymbol;
                self.subscribedSymbol = ();

                StatusResponse msg = {
                    status: "unsubscribed",
                    message: string `Unsubscribed from ${previousSymbol.toString()}`
                };
                check caller->writeMessage(msg.toJsonString());
            }
            "stop" => {
                self.isStreaming = false;
                self.subscribedSymbol = ();

                StatusResponse msg = {
                    status: "stopped",
                    message: "Streaming stopped"
                };
                check caller->writeMessage(msg.toJsonString());
            }
        }

        return;
    }

    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        io:println(string `Stock stream client disconnected: ${caller.getConnectionId()} - Code: ${statusCode}, Reason: ${reason}`);
        self.isStreaming = false;
        self.subscribedSymbol = ();
    }

    remote function onError(websocket:Caller caller, error err) {
        io:println(string `Error occurred in stock stream connection ${caller.getConnectionId()}: ${err.message()}`);
        self.isStreaming = false;
        self.subscribedSymbol = ();
    }

    // Poll Kafka and stream filtered stock messages to WebSocket client
    function pollKafkaAndStream(websocket:Caller caller, string symbol) returns error? {
        io:println(string `Started Kafka polling for symbol '${symbol}' - client: ${caller.getConnectionId()}`);

        while self.isStreaming && self.subscribedSymbol == symbol {
            // Poll Kafka for messages
            kafka:BytesConsumerRecord[]|error records = kafkaConsumer->poll(<decimal>kafkaPollTimeoutMs / 1000.0);

            if records is error {
                io:println(string `Error polling Kafka: ${records.message()}`);
                ErrorResponse errResponse = {
                    'error: "Kafka polling error",
                    message: string `Failed to poll Kafka: ${records.message()}`
                };
                error? writeErr = caller->writeMessage(errResponse.toJsonString());
                if writeErr is error {
                    io:println(string `Error writing to client: ${writeErr.message()}`);
                    self.isStreaming = false;
                    break;
                }
                // Wait before retrying
                runtime:sleep(2);
                continue;
            }

            // Process each record
            foreach kafka:BytesConsumerRecord consumerRecord in records {
                if !self.isStreaming || self.subscribedSymbol != symbol {
                    break;
                }

                // Extract message value
                byte[] messageBytes = consumerRecord.value;
                string messageStr = check string:fromBytes(messageBytes);

                // Filter by stock symbol
                if filterMessageBySymbol(messageStr, symbol) {
                    // Forward matching message to WebSocket client
                    error? writeErr = caller->writeMessage(messageStr);
                    if writeErr is error {
                        io:println(string `Error writing message to client ${caller.getConnectionId()}: ${writeErr.message()}`);
                        self.isStreaming = false;
                        break;
                    }

                    io:println(string `✓ Forwarded ${symbol} data to client ${caller.getConnectionId()}`);
                } else {
                    // Log filtered out messages (optional, can remove for production)
                    string? extractedSymbol = extractSymbolFromMessage(messageStr);
                    if extractedSymbol is string {
                        io:println(string `Filtered out message for symbol: ${extractedSymbol}`);
                    }
                }
            }

            // Small delay to prevent tight loop when no messages
            if records.length() == 0 {
                runtime:sleep(0.5);
            }
        }

        io:println(string `Stopped Kafka polling for symbol '${symbol}' - client: ${caller.getConnectionId()}`);
        return;
    }
}