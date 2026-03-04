import ballerina/http;

http:Client cp = check new ("http://localhost:9090",
    auth = {
        tokenUrl:"https://localhost:9443/oauth2/token",
        clientId: "Ggq4IFfDtPFXLEk6cc0etaihi1Aa",
        clientSecret: "pSgk9z2m2rHp35v660diXidzr7Aa"
    }
);

public function main() returns error? {
   json result = check cp->/test.get();
}