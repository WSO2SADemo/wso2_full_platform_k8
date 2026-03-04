
type RequestPayloadItem record {|
    string order_id;
    string sku;
    int qty;
    decimal price;
|};

type RequestPayload RequestPayloadItem[];

type Row record {
    int index;
    string order_id;
    string sku;
    int qty;
    decimal price;
};

type Orders record {
    Row[] Row;
};

type employeeReqPayload record {|
    string employeeId;
|};

type reqPayload record {|
    string employeeId;
|};

type deliveryRequestPayload record {|
    string employeeId;
|};

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

type MyType record {|
    boolean found;
    Employee employee;
    string message;
|};
