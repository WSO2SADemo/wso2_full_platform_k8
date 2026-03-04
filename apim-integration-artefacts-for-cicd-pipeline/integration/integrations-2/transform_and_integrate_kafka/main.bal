import ballerina/data.jsondata;
import ballerina/data.xmldata;
import ballerina/http;
import ballerina/io;

listener http:Listener httpDefaultListener = http:getDefaultListener();

function init() {
    io:println("INFO: Transform service is initiating...");
}

service /transformService on httpDefaultListener {
    resource function post publish_to_kafka(@http:Payload RequestPayload payload) returns xml|error {
        do {
            Orders orders = json_to_xml(payload);
            foreach Row singleOrder in orders.Row {
                xml xmlOrderResult = check xmldata:toXml(singleOrder);
                check kafkaProducer->send({
                    topic: "order-topic",
                    value: xmlOrderResult
                });
            }
            xml totalOrderXmlResult = check xmldata:toXml(orders);
            return totalOrderXmlResult;
        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }

    resource function post guaranteed_delivery(@http:Payload deliveryRequestPayload payload) returns error|json {
        do {
            MyType backendResponse = check httpClient->post("/", payload);
            json jsonResult = jsondata:toJson(backendResponse);
            return jsonResult;
        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }

}
