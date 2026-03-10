import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;
import ballerinax/rabbitmq;

// ─── Main Queue Consumer ──────────────────────────────────────────────────────
//
// Consumes messages from the main delivery queue. For each message:
//   • Tries to POST it to the backend (Fund11 notification receiver)
//   • Success  → ack, done
//   • Failure AND retryCount < MAX_RETRIES
//               → publish to retry queue (TTL 30 s, returns to main queue automatically)
//   • Failure AND retryCount >= MAX_RETRIES
//               → publish to DLQ, store in dlqMessages map for manual retry API

// Consumer client for reading messages from the queue
final rabbitmq:Client consumerClient = check new (rabbitmqHost, rabbitmqPort, {
    auth: {
        username: rabbitmqUser,
        password: rabbitmqPassword
    }
});

// Background task that continuously processes messages from the main queue
function startConsumer() returns error? {
    log:printInfo("[Consumer] Starting message consumer for queue: " + MAIN_QUEUE);
    
    while true {
        runtime:sleep(0.1);
        rabbitmq:AnydataMessage|error message = consumerClient->consumeMessage(MAIN_QUEUE, autoAck = false);
        
        if message is error {
            log:printDebug("[Consumer] No messages in queue, skipping.");
            continue;
        }
        
        error? processResult = processMessage(message);
        
        if processResult is error {
            log:printError("[Consumer] Error processing message: " + processResult.message());
            // Acknowledge anyway to prevent infinite redelivery
            error? ackResult = consumerClient->basicAck(message);
            if ackResult is error {
                log:printError("[Consumer] Failed to ack message: " + ackResult.message());
            }
        } else {
            // Successfully processed, acknowledge the message
            error? ackResult = consumerClient->basicAck(message);
            if ackResult is error {
                log:printError("[Consumer] Failed to ack message: " + ackResult.message());
            }
        }
    }
}

function processMessage(rabbitmq:AnydataMessage message) returns error? {
    // ── Deserialise ───────────────────────────────────────────────────────
    anydata messageContent = message.content;
    byte[] body = check messageContent.ensureType();
    string contentStr = check string:fromBytes(body);
    json contentJson = check contentStr.fromJsonString();
    NotificationMessage msg = check contentJson.cloneWithType();

    string now = time:utcToString(time:utcNow());
    NotificationMessage attemptMsg = {
        messageId: msg.messageId,
        personId: msg.personId,
        notificationType: msg.notificationType,
        data: msg.data,
        retryCount: msg.retryCount,
        createdAt: msg.createdAt,
        lastAttemptAt: now
    };

    log:printInfo(string `[Consumer] Processing messageId=${msg.messageId} attempt=${msg.retryCount + 1}/${MAX_RETRIES + 1}`);

    // ── Attempt delivery to backend ───────────────────────────────────────
    http:Response|error backendResult = backendClient->post("/notifications", attemptMsg.toJson());

    boolean delivered = false;
    if backendResult is http:Response {
        delivered = backendResult.statusCode >= 200 && backendResult.statusCode < 400;
    }

    if delivered {
        log:printInfo(string `[Consumer] Delivered: messageId=${msg.messageId}`);
        return;
    }

    // ── Delivery failed ───────────────────────────────────────────────────
    string failReason = backendResult is error
        ? backendResult.message()
        : string `HTTP ${(<http:Response>backendResult).statusCode}`;

    log:printWarn(string `[Consumer] Delivery failed messageId=${msg.messageId} attempt=${msg.retryCount + 1}: ${failReason}`);

    if msg.retryCount < MAX_RETRIES {
        // ── Automatic retry: publish to retry queue with TTL ──────────────
        NotificationMessage retryMsg = {
            messageId: attemptMsg.messageId,
            personId: attemptMsg.personId,
            notificationType: attemptMsg.notificationType,
            data: attemptMsg.data,
            retryCount: msg.retryCount + 1,
            createdAt: attemptMsg.createdAt,
            lastAttemptAt: attemptMsg.lastAttemptAt
        };
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
            dlqMessages[attemptMsg.messageId] = attemptMsg.cloneReadOnly();
        }
        log:printError(string `[Consumer] Max retries (${MAX_RETRIES}) exhausted for messageId=${msg.messageId} → moved to DLQ`);
    }
}
