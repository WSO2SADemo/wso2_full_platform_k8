import ballerina/http;
import ballerina/log;

// HTTP Listener for the service
listener http:Listener httpListener = check new (httpPort);

// Employee Management Service
service /employees on httpListener {

    // Get all employees
    resource function get .() returns Employee[]|http:InternalServerError {
        Employee[]|error employees = getAllEmployees();

        if employees is error {
            log:printError(string `Failed to fetch employees: ${employees.message()}`);
            return http:INTERNAL_SERVER_ERROR;
        }

        return employees;
    }

    // Get employee by ID
    resource function get employee(int id) returns Employee|http:NotFound|http:InternalServerError {
        Employee|error employee = getEmployeeById(id);

        if employee is error {
            log:printError(string `Failed to fetch employee: ${employee.message()}`);
            return http:INTERNAL_SERVER_ERROR;
        }

        return employee;
    }

    // Create new employee
    resource function post add(@http:Payload EmployeeRequest employeeRequest) returns record {|string message; int id;|}|http:InternalServerError {
        int|error result = createEmployee(employeeRequest);

        if result is error {
            log:printError(string `Failed to create employee: ${result.message()}`);
            return http:INTERNAL_SERVER_ERROR;
        }

        return {
            message: "Employee created successfully",
            id: result
        };
    }

    // Delete employee by ID
    resource function delete remove(@http:Query int id) returns record {|string message;|}|http:InternalServerError {
        error? result = deleteEmployee(id);

        if result is error {
            log:printError(string `Failed to delete employee: ${result.message()}`);
            return http:INTERNAL_SERVER_ERROR;
        }

        return {
            message: "Employee deleted successfully"
        };
    }
}

// File Transfer Management Service (separate service with database integration)

