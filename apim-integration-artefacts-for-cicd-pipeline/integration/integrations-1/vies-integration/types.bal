// SAP-MDM Request format
type SapMdmVatRequest record {|
    string countryCode;
    string vatNumber;
|};

// SAP-MDM Response format
type SapMdmVatResponse record {|
    string countryCode;
    string vatNumber;
    boolean valid;
    string? name;
    string? address;
    string requestDate;
|};

// VIES SOAP Response structure
type ViesCheckVatResponse record {|
    string countryCode;
    string vatNumber;
    string requestDate;
    boolean valid;
    string name;
    string address;
|};

// SAP-MDM Approximate VAT Request format
type SapMdmVatApproxRequest record {|
    string countryCode;
    string vatNumber;
    string? traderName?;
    string? traderCompanyType?;
    string? traderStreet?;
    string? traderPostcode?;
    string? traderCity?;
|};

// SAP-MDM Approximate VAT Response format
type SapMdmVatApproxResponse record {|
    string countryCode;
    string vatNumber;
    boolean valid;
    string? traderName;
    string? traderCompanyType;
    string? traderStreet;
    string? traderPostcode;
    string? traderCity;
    string? traderNameMatch;
    string? traderCompanyTypeMatch;
    string? traderStreetMatch;
    string? traderPostcodeMatch;
    string? traderCityMatch;
    string requestDate;
    string? traderAddress;
|};
