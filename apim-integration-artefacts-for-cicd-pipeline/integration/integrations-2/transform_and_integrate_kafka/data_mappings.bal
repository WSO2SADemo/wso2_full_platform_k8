function json_to_xml(RequestPayload jsonRequestPayload) returns Orders => {
    Row: from var jsonRequestPayloadItem in jsonRequestPayload
        select {order_id: jsonRequestPayloadItem.order_id, sku: jsonRequestPayloadItem.sku, qty: jsonRequestPayloadItem.qty, price: jsonRequestPayloadItem.price, index: <int>jsonRequestPayload.indexOf(jsonRequestPayloadItem)}
};
