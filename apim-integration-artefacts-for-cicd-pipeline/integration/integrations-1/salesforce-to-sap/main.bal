// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;
import ballerina/random;
import ballerinax/sap.s4hana.api_sales_order_srv as salesorder;

configurable int httpPort = 8080;
listener http:Listener httpListener = check new (httpPort);
configurable S4HanaClientConfig s4hanaClientConfig = ?;
final salesorder:Client salesOrderClient = check new ({
        auth: {
            username: s4hanaClientConfig.username,
            password: s4hanaClientConfig.password
        }
    },
    s4hanaClientConfig.hostname
);
function init() {
    log:printInfo("SAP integration service started");
}

service /sap_integration on httpListener {
    resource function post opportunity(@http:Payload OpportunityPayload payload) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Received opportunity payload from Salesforce");

        if !payload.isClosed {
            log:printInfo("Opportunity is not closed. Skipping order creation.");
            return <http:BadRequest>{body: "Opportunity is not closed"};
        }

        if !payload.isWon {
            log:printInfo("Opportunity is not won. Skipping order creation.");
            return <http:BadRequest>{body: "Opportunity is not won"};
        }

        if payload.items.length() == 0 {
            log:printInfo("No items found in the opportunity. Skipping order creation.");
            return <http:BadRequest>{body: "No items found in the opportunity"};
        }

        salesorder:CreateA_SalesOrder|error salesOrder = transformOrderData(payload.items);
        if salesOrder is error {
            log:printError("Error while transforming order: " + salesOrder.message());
            return <http:InternalServerError>{body: "Error transforming order data"};
        }

        salesorder:A_SalesOrderWrapper|error aSalesOrder = salesOrderClient->createA_SalesOrder(salesOrder);
        if aSalesOrder is error {
            log:printError("Error while creating SAP order: " + aSalesOrder.message(), aSalesOrder);
            return <http:InternalServerError>{body: "Error creating SAP order"};
        }

        string salesOrderId = aSalesOrder.d?.SalesOrder ?: "";
        log:printInfo(string `Successfully created an SAP sales order with id: ${salesOrderId}`);
        return <http:Created>{body: {salesOrderId: salesOrderId}};
    }
}

isolated function transformOrderData(SfOpportunityItem[] salesforceItems) returns salesorder:CreateA_SalesOrder|error {
    int salesOrderId = check random:createIntInRange(5000000, 5999999);
    salesorder:CreateA_SalesOrder salesOrder = {
        SalesOrder: salesOrderId.toString(),
        SalesOrderType: SALES_ORDER_TYPE,
        SalesOrganization: SALES_ORGANIZATION,
        DistributionChannel: DISTRIBUTION_CHANNEL,
        OrganizationDivision: ORG_DIVISION,
        SoldToParty: SOLD_TO_PARTY
    };
    if salesforceItems.length() == 0 {
        log:printInfo("No items found in the opportunity. Skipping item creation in order creation.");
        log:printInfo("printing sales order");
        log:printInfo(salesOrder.toString());
        return salesOrder;
    }

    salesorder:CreateA_SalesOrderItem[] orderItems = [];
    foreach int i in 0 ... salesforceItems.length() - 1 {
        string productCode = salesforceItems[i].ProductCode;
        S4HanaMaterial? material = CODE_TO_MATERIAL[productCode];
        if material is () {
            log:printError(string `Material mapping to Product Code is not found for ${productCode}`);
            continue;
        }
        orderItems.push({
            SalesOrderItem: (i + 1).toString(),
            Material: material.Material,
            SalesOrderItemText: salesforceItems[i].Name,
            SalesOrderItemCategory: material.SalesOrderItemCategory,
            RequestedQuantity: salesforceItems[i].Quantity.toString(),
            RequestedQuantityUnit: material.RequestedQuantityUnit
        });
    }
    salesOrder.to_Item = {
        results: orderItems
    };
    log:printInfo("printing sales order");
    log:printInfo(salesOrder.toString());
    return salesOrder;
}