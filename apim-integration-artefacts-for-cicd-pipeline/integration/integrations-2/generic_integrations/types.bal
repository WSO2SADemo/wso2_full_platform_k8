// File transfer record type
type FileTransfer record {|
    int id?;
    string fileName;
    int fileSize;
    string sourceLocation;
    string destinationLocation;
    string transferStatus;
    string transferredAt?;
|};

// Request payload for creating file transfer record
type FileTransferRequest record {|
    string fileName;
    int fileSize;
    string sourceLocation;
    string destinationLocation;
    string transferStatus;
|};

// Employee record type
type Employee record {|
    int id?;
    string name;
    string address;
    string mobile;
|};

// Request payload for creating employee
type EmployeeRequest record {|
    string name;
    string address;
    string mobile;
|};

// WebSocket message type for Kafka integration
type KafkaWebSocketMessage record {|
    string messageType;
    string content;
    string timestamp?;
|};

// Command types that clients can send
public type CommandType "subscribe"|"unsubscribe"|"stop";

// Incoming command from WebSocket client for stock data
public type StockCommand record {|
    CommandType command;
    string? symbol?;  // Stock symbol/index (e.g., "AAPL", "GOOGL")
|};

// Stock option data structure (adjust fields based on your actual data)
public type StockOptionData record {|
    string symbol;
    string optionType?;  // "call" or "put"
    float? strikePrice?;
    string? expirationDate?;
    float? bidPrice?;
    float? askPrice?;
    float? lastPrice?;
    int? volume?;
    int? openInterest?;
    map<string|float|int|boolean>? additionalData?;  // For flexible data structure
|};

// Stock response sent back to client
public type StockResponse record {|
    string symbol;
    StockOptionData|map<string|float|int> data;
    string timestamp;
|};

// Error response
public type ErrorResponse record {|
    string 'error;
    string message;
|};

// Status response
public type StatusResponse record {|
    string status;
    string message;
|};
