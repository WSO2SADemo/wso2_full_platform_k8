import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/rabbitmq;
import ballerinax/moesif as _;
import ballerinax/wso2.icp as _;

// ─── Module init: declare all RabbitMQ queues before listeners start ──────────

function init() returns error? {
    check setupQueues();
    log:printInfo("Store-and-Forward module initialised – queues ready");
    
    log:printInfo("✓ RabbitMQ connection successful");

    // Verify backend connection
    error? backendHealth = verifyBackendConnection();
    if backendHealth is error {
        log:printWarn("Backend health check failed: " + backendHealth.message());
    } else {
        log:printInfo("✓ Backend connection successful");
    }
    
    // Start the consumer in a separate worker thread
    worker consumerWorker {
        error? result = startConsumer();
        if result is error {
            log:printError("Consumer worker failed: " + result.message());
        }
    }
}

// Verify backend connection by calling health endpoint
function verifyBackendConnection() returns error? {
    http:Response response = check backendClient->get("/notifications/health");
    if response.statusCode < 200 || response.statusCode >= 300 {
        return error(string `Backend health check returned status: ${response.statusCode}`);
    }
}

// ─── HTTP Service (port 9085) ─────────────────────────────────────────────────
//
// Published API used by callers to send notifications and manage the DLQ.
//
// POST /notifications/send        – accept a notification, queue it, return 202 immediately
// POST /notifications/retry       – manually retry the oldest DLQ message
// GET  /notifications/dlq-status  – list messages currently awaiting manual retry

listener http:Listener httpListener = check new http:Listener(9085);

service / on httpListener {

    function init() {
        log:printInfo("Store-and-Forward HTTP service started on port 9085");
    }

    // ── SEND ──────────────────────────────────────────────────────────────────
    // Caller posts a notification. The integration immediately:
    //   1. Wraps the payload in a NotificationMessage envelope
    //   2. Publishes to the main RabbitMQ queue
    //   3. Returns 202 Accepted – caller does NOT wait for backend delivery
    resource function post notifications/send(@http:Payload NotificationRequest request)
            returns http:Accepted|http:InternalServerError {

        string msgId = uuid:createType4AsString();
        string now = time:utcToString(time:utcNow());

        NotificationMessage msg = {
            messageId: msgId,
            personId: request.personId,
            notificationType: request.notificationType,
            data: request.data,
            retryCount: 0,
            createdAt: now,
            lastAttemptAt: ""
        };

        rabbitmq:Error? publishResult = publisherClient->publishMessage({
            content: msg.toJson().toJsonString().toBytes(),
            routingKey: MAIN_QUEUE
        });

        if publishResult is rabbitmq:Error {
            log:printError("Failed to enqueue notification: " + publishResult.message());
            return <http:InternalServerError>{body: {
                'error: "Failed to queue message – RabbitMQ unavailable",
                detail: publishResult.message()
            }};
        }

        log:printInfo(string `Notification queued: messageId=${msgId} personId=${request.personId} type=${request.notificationType}`);

        return <http:Accepted>{body: <QueuedResponse>{
            messageId: msgId,
            status: "QUEUED",
            message: "Message accepted and queued for delivery. Automatic retries will occur if the backend is unavailable.",
            timestamp: now
        }};
    }

    // ── MANUAL RETRY ──────────────────────────────────────────────────────────
    // Takes the oldest message from the in-memory DLQ store, resets its retry
    // counter, and re-publishes it to the main queue for another delivery attempt.
    resource function post notifications/'retry() returns RetryResult {
        lock {
            if dlqMessages.length() == 0 {
                return {
                    status: "DLQ_EMPTY",
                    message: "No messages pending manual retry",
                    messageId: ()
                };
            }

            string[] keys = dlqMessages.keys();
            NotificationMessage msg = dlqMessages.remove(keys[0]);

            // Reset the retry counter so the message gets the full 3 automatic
            // retries again from this new delivery attempt.
            NotificationMessage retryMsg = {
                messageId: msg.messageId,
                personId: msg.personId,
                notificationType: msg.notificationType,
                data: msg.data,
                retryCount: 0,
                createdAt: msg.createdAt,
                lastAttemptAt: ""
            };

            rabbitmq:Error? result = publisherClient->publishMessage({
                content: retryMsg.toJson().toJsonString().toBytes(),
                routingKey: MAIN_QUEUE
            });

            if result is rabbitmq:Error {
                dlqMessages[msg.messageId] = msg.cloneReadOnly(); // restore on failure
                log:printError("Manual retry failed to enqueue: " + result.message());
                return {
                    status: "ERROR",
                    message: "Failed to requeue: " + result.message(),
                    messageId: msg.messageId
                };
            }

            log:printInfo(string `Manual retry initiated: messageId=${msg.messageId}`);
            return {
                status: "REQUEUED",
                message: "Message moved back to main queue for delivery",
                messageId: msg.messageId
            };
        }
    }

    // ── DLQ STATUS ────────────────────────────────────────────────────────────
    // Returns all messages currently awaiting manual retry.
    resource function get notifications/dlq\-status() returns DlqStatus {
        int messageCount = 0;
        NotificationMessage[] messageList = [];
        lock {
            messageCount = dlqMessages.length();
            messageList = dlqMessages.toArray().clone();
        }
        return {
            count: messageCount,
            messages: messageList
        };
    }
}
