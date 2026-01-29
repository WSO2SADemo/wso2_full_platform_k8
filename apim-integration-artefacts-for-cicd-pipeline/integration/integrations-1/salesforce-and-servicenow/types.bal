type Metadata record {|
    string id;
    string name;
    string description;
    string version;
    string created_at;
    string updated_at;
|};

type Attributes record {|
    string 'type;
    string url;
|};

type Product2 record {|
    Attributes attributes;
    string Name;
    string ProductCode;
|};

type PricebookEntry record {|
    Attributes attributes;
    Product2 Product2;
|};

type RecordsItem record {|
    Attributes attributes;
    string Id;
    decimal Quantity;
    decimal UnitPrice;
    PricebookEntry PricebookEntry;
|};

type Records RecordsItem[];

type OrderItems record {|
    int totalSize;
    boolean done;
    Records records;
|};

type Order record {|
    OrderItems OrderItems;
    Attributes attributes;
    string OrderNumber;
    string Id;
    decimal TotalAmount;
    string EffectiveDate;
|};

type OrderRecord record {|
    Order value;
|};

type OrderTicketRequest record {|
    string orderId;
    string payload;
|};

type OrderTicketResponse record {|
    string orderId;
    string orderNumber;
    string accountName;
    decimal totalAmount;
    string status;
    string ticketNumber;
    string ticketSysId;
    string message;
|};

type ChatRequest record {|
    string message;
    string sessionId?;
|};

type ChatResponse record {|
    string message;
|};
