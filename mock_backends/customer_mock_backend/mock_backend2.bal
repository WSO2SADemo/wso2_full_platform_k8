import ballerina/http;
import ballerina/log;

// ============================================================================
// EMPLOYEE SERVICE - Port 9094
// ============================================================================

// Employee details type
type Employee record {|
    string employeeId;
    string firstName;
    string lastName;
    string email;
    string department;
    string position;
    decimal salary;
    string hireDate;
|};

// Employee lookup request type
type EmployeeLookupRequest record {|
    string employeeId;
|};

// Employee lookup response type
type EmployeeLookupResponse record {|
    boolean found;
    Employee? employee;
    string message;
|};

// In-memory employee database
map<Employee> employeeDatabase = {
    "EMP001": {
        employeeId: "EMP001",
        firstName: "Anna",
        lastName: "Andersson",
        email: "anna.andersson@company.se",
        department: "Engineering",
        position: "Senior Developer",
        salary: 45000.0,
        hireDate: "2020-03-15"
    },
    "EMP002": {
        employeeId: "EMP002",
        firstName: "Erik",
        lastName: "Eriksson",
        email: "erik.eriksson@company.se",
        department: "Human Resources",
        position: "HR Manager",
        salary: 42000.0,
        hireDate: "2019-06-01"
    },
    "EMP003": {
        employeeId: "EMP003",
        firstName: "Maria",
        lastName: "Svensson",
        email: "maria.svensson@company.se",
        department: "Finance",
        position: "Financial Analyst",
        salary: 38000.0,
        hireDate: "2021-01-10"
    },
    "EMP004": {
        employeeId: "EMP004",
        firstName: "Johan",
        lastName: "Johansson",
        email: "johan.johansson@company.se",
        department: "Engineering",
        position: "DevOps Engineer",
        salary: 43000.0,
        hireDate: "2020-09-20"
    },
    "EMP005": {
        employeeId: "EMP005",
        firstName: "Lisa",
        lastName: "Karlsson",
        email: "lisa.karlsson@company.se",
        department: "Marketing",
        position: "Marketing Specialist",
        salary: 36000.0,
        hireDate: "2022-02-14"
    }
};

listener http:Listener employeeListener = check new (9094);

service /employee on employeeListener {

    // Get employee details by employee ID (JSON payload)
    resource function post details(@http:Payload EmployeeLookupRequest request) returns EmployeeLookupResponse {
        
        log:printInfo(string `Employee Service: Looking up employee ${request.employeeId}`);
        
        if employeeDatabase.hasKey(request.employeeId) {
            Employee? employee = employeeDatabase[request.employeeId];
            
            log:printInfo(string `Employee Service: Employee ${request.employeeId} found`);
            
            return {
                found: true,
                employee: employee,
                message: "Employee found successfully"
            };
        }
        
        log:printInfo(string `Employee Service: Employee ${request.employeeId} not found`);
        
        return {
            found: false,
            employee: (),
            message: "Employee not found"
        };
    }

    // Get all employees
    resource function get all() returns Employee[] {
        
        log:printInfo("Employee Service: Retrieving all employees");
        
        Employee[] allEmployees = employeeDatabase.toArray();
        return allEmployees;
    }

    // Health check endpoint
    resource function get health() returns string {
        return "Employee Service is running on port 9094";
    }
}
