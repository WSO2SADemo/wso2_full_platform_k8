import ballerina/sql;
import ballerina/log;
import ballerina/lang.value;

// Create file transfer record in database
function createFileTransferRecord(FileTransferRequest transferRequest) returns int|error {
    sql:ParameterizedQuery insertQuery = `
        INSERT INTO file_transfers (file_name, file_size, source_location, destination_location, transfer_status)
        VALUES (${transferRequest.fileName}, ${transferRequest.fileSize}, ${transferRequest.sourceLocation}, 
                ${transferRequest.destinationLocation}, ${transferRequest.transferStatus})
    `;
    
    sql:ExecutionResult|sql:Error result = mysqlClient->execute(insertQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to create file transfer record: ${result.message()}`);
        return result;
    }
    
    int|string? lastInsertId = result.lastInsertId;
    if lastInsertId is int {
        return lastInsertId;
    }
    
    return error("Failed to retrieve last insert ID");
}

// Get all file transfer records
function getAllFileTransfers() returns FileTransfer[]|error {
    sql:ParameterizedQuery selectQuery = `SELECT id, file_name, file_size, source_location, destination_location, 
                                          transfer_status, transferred_at FROM file_transfers ORDER BY id DESC`;
    
    stream<FileTransfer, sql:Error?> resultStream = mysqlClient->query(selectQuery);
    
    FileTransfer[] transfers = [];
    error? streamResult = resultStream.forEach(function(FileTransfer transfer) {
        transfers.push(transfer);
    });
    
    if streamResult is error {
        log:printError(string `Failed to fetch file transfers: ${streamResult.message()}`);
        return streamResult;
    }
    
    return transfers;
}

// Get file transfer by ID
function getFileTransferById(int transferId) returns FileTransfer|error {
    sql:ParameterizedQuery selectQuery = `SELECT id, file_name, file_size, source_location, destination_location, 
                                          transfer_status, transferred_at FROM file_transfers WHERE id = ${transferId}`;
    
    FileTransfer|sql:Error result = mysqlClient->queryRow(selectQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to fetch file transfer with ID ${transferId}: ${result.message()}`);
        return result;
    }
    
    return result;
}

// Update file transfer status
function updateFileTransferStatus(int transferId, string newStatus) returns error? {
    sql:ParameterizedQuery updateQuery = `UPDATE file_transfers SET transfer_status = ${newStatus} WHERE id = ${transferId}`;
    
    sql:ExecutionResult|sql:Error result = mysqlClient->execute(updateQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to update file transfer status: ${result.message()}`);
        return result;
    }
    
    return;
}

// Delete file transfer record
function deleteFileTransferRecord(int transferId) returns error? {
    sql:ParameterizedQuery deleteQuery = `DELETE FROM file_transfers WHERE id = ${transferId}`;
    
    sql:ExecutionResult|sql:Error result = mysqlClient->execute(deleteQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to delete file transfer record: ${result.message()}`);
        return result;
    }
    
    return;
}

// Create employee record in database
function createEmployee(EmployeeRequest employeeRequest) returns int|error {
    sql:ParameterizedQuery insertQuery = `
        INSERT INTO employee (name, address, mobile)
        VALUES (${employeeRequest.name}, ${employeeRequest.address}, ${employeeRequest.mobile})
    `;
    
    sql:ExecutionResult|sql:Error result = mysqlClient->execute(insertQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to create employee: ${result.message()}`);
        return result;
    }
    
    int|string? lastInsertId = result.lastInsertId;
    if lastInsertId is int {
        return lastInsertId;
    }
    
    return error("Failed to retrieve last insert ID");
}

// Get all employees
function getAllEmployees() returns Employee[]|error {
    sql:ParameterizedQuery selectQuery = `SELECT id, name, address, mobile FROM employee ORDER BY id`;
    
    stream<Employee, sql:Error?> resultStream = mysqlClient->query(selectQuery);
    
    Employee[] employees = [];
    error? streamResult = resultStream.forEach(function(Employee employee) {
        employees.push(employee);
    });
    
    if streamResult is error {
        log:printError(string `Failed to fetch employees: ${streamResult.message()}`);
        return streamResult;
    }
    
    return employees;
}

// Get employee by ID
function getEmployeeById(int employeeId) returns Employee|error {
    sql:ParameterizedQuery selectQuery = `SELECT id, name, address, mobile FROM employee WHERE id = ${employeeId}`;
    
    Employee|sql:Error result = mysqlClient->queryRow(selectQuery);
    
    if result is sql:Error {
        log:printError(string `Failed to fetch employee with ID ${employeeId}: ${result.message()}`);
        return result;
    }
    
    return result;
}

// Helper function to filter Kafka messages by stock symbol
public function filterMessageBySymbol(string message, string targetSymbol) returns boolean {
    // Try to parse the message as JSON to extract the symbol
    json|error jsonMsg = value:fromJsonString(message);

    if jsonMsg is json {
        // Check if the message contains the target symbol
        json|error symbolField = jsonMsg.symbol;
        if symbolField is string {
            return symbolField == targetSymbol;
        }
    }

    // If JSON parsing fails, try simple string matching
    return message.includes(targetSymbol);
}

// Helper function to extract stock symbol from a message
public function extractSymbolFromMessage(string message) returns string? {
    json|error jsonMsg = value:fromJsonString(message);

    if jsonMsg is json {
        json|error symbolField = jsonMsg.symbol;
        if symbolField is string {
            return symbolField;
        }
    }

    return ();
}
