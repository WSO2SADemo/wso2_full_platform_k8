// HR domain types

type Employee record {|
    string employeeId;
    string firstName;
    string lastName;
    string email;
    string department;
    string position;
    string joinDate;
    decimal salary;
    string status;
|};

type LeaveRequest record {|
    string leaveId;
    string employeeId;
    string leaveType;
    string startDate;
    string endDate;
    string reason;
    string status;
|};

type LeaveRequestInput record {|
    string employeeId;
    string leaveType;
    string startDate;
    string endDate;
    string reason;
|};

type PayrollRecord record {|
    string payrollId;
    string employeeId;
    string month;
    decimal basicSalary;
    decimal allowances;
    decimal deductions;
    decimal netSalary;
    string paymentStatus;
|};

type AttendanceRecord record {|
    string attendanceId;
    string employeeId;
    string date;
    string checkIn;
    string checkOut;
    string status;
|};

type HrApiResponse record {|
    boolean success;
    string message;
    json data?;
|};
