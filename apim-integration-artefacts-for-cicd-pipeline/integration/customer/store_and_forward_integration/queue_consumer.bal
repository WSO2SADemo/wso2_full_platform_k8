import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerinax/rabbitmq;

// ─── Main Queue Consumer ──────────────────────────────────────────────────────
//
// Listens on the main delivery queue. For each message:
//   • Tries to POST it to the backend (Fund11 notification receiver)
//   • Success  → ack, done
//   • Failure AND retryCount < MAX_RETRIES
//               → publish to retry queue (TTL 30 s, returns to main queue automatically)
//   • Failure AND retryCount >= MAX_RETRIES
//               → publish to DLQ, store in dlqMessages map for manual retry API

@rabbitmq:ServiceConfig {
    queueName: MAIN_QUEUE,
    autoAck: false
}
service rabbitmq:Service on mqListener {

    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        // ── Deserialise ───────────────────────────────────────────────────────
        byte[] body = check message.content.ensureType(byte[]);
        string contentStr = check string:fromBytes(body);
        json contentJson = check contentStr.fromJsonString();
        NotificationMessage msg = check contentJson.cloneWithType(NotificationMessage);

        string now = time:utcToString(time:utcNow());
        NotificationMessage attemptMsg = {...msg, lastAttemptAt: now};

        log:printInfo(string `[Consumer] Processing messageId=${msg.messageId} attempt=${msg.retryCount + 1}/${MAX_RETRIES + 1}`);

        // ── Attempt delivery to backend ───────────────────────────────────────
        http:Response|error backendResult = backendClient->post("/notifications", attemptMsg.toJson());

        boolean delivered = false;
        if backendResult is http:Response {
            delivered = backendResult.statusCode >= 200 && backendResult.statusCode < 400;
        }

        if delivered {
            log:printInfo(string `[Consumer] Delivered: messageId=${msg.messageId}`);
            check caller->basicAck();
            return;
        }

        // ── Delivery failed ───────────────────────────────────────────────────
        string failReason = backendResult is error
            ? backendResult.message()
            : string `HTTP ${(<http:Response>backendResult).statusCode}`;

        log:printWarn(string `[Consumer] Delivery failed messageId=${msg.messageId} attempt=${msg.retryCount + 1}: ${failReason}`);

        if msg.retryCount < MAX_RETRIES {
            // ── Automatic retry: publish to retry queue with TTL ──────────────
            NotificationMessage retryMsg = {...attemptMsg, retryCount: msg.retryCount + 1};
            check publisherClient->publishMessage({
                content: retryMsg.toJson().toJsonString().toBytes(),
                routingKey: RETRY_QUEUE
            });
            log:printInfo(string `[Consumer] Scheduled retry ${msg.retryCount + 1}/${MAX_RETRIES} for messageId=${msg.messageId} (retry in ${RETRY_TTL_MS / 1000} s)`);
        } else {
            // ── Max retries exhausted: move to DLQ ────────────────────────────
            check publisherClient->publishMessage({
                content: attemptMsg.toJson().toJsonString().toBytes(),
                routingKey: DLQ
            });
            // Track in memory for manual retry API
            lock {
                dlqMessages[msg.messageId] = attemptMsg;
            }
            log:printError(string `[Consumer] Max retries (${MAX_RETRIES}) exhausted for messageId=${msg.messageId} → moved to DLQ`);
        }

        // Always ack the original message: we have either re-queued it (retry
        // queue) or moved it to the DLQ. Nacking would cause infinite redelivery.
        check caller->basicAck();
    }
}
