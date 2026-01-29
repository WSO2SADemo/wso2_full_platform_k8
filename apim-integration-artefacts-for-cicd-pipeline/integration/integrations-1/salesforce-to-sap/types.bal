type SfListenerConfig record {|
    string username;
    string password;
    boolean isSandbox;
|};

type SfClientConfig record {|
    string baseUrl;
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl;
|};

type S4HanaClientConfig record {|
    string hostname;
    string username;
    string password;
|};

type SfOpportunityItem record {
    string ProductCode;
    decimal Quantity;
    string Name;
};

type S4HanaMaterial record {|
    string Material;
    string SalesOrderItemCategory;
    string RequestedQuantityUnit;
|};