import ballerina/http;
import ballerina/log;
import ballerinax/rabbitmq;

// ─── Connection parameters ────────────────────────────────────────────────────
// Defined in config.bal – env vars (K8s secret) take priority over Config.toml.

// ─── Queue names ──────────────────────────────────────────────────────────────

const string MAIN_QUEUE  = "store-forward-notifications";
const string RETRY_QUEUE = "store-forward-retry";
const string DLQ         = "store-forward-dlq";

// Per-request delivery timeout (backend must respond within this time)
const decimal BACKEND_TIMEOUT_SECONDS = 5.0;

// Maximum number of automatic retransmission attempts (after the initial delivery)
const int MAX_RETRIES = 3;

// How long (ms) a failed message waits in the retry queue before being re-attempted
// (RabbitMQ TTL – 30 s for demo; increase for production)
const int RETRY_TTL_MS = 30000;

// ─── RabbitMQ clients ─────────────────────────────────────────────────────────

// Publisher client – used by the HTTP service to enqueue messages and by the
// consumer to route messages to the retry queue or DLQ.
final rabbitmq:Client publisherClient = check new (rabbitmqHost, rabbitmqPort, {
    auth: {
        username: rabbitmqUser,
        password: rabbitmqPassword
    }
});

// ─── Backend HTTP client ───────────────────────────────────────────────────────

final http:Client backendClient = check new (backendUrl, {
    timeout: BACKEND_TIMEOUT_SECONDS
});

// ─── In-memory DLQ message store ──────────────────────────────────────────────
// Messages that have exhausted all retries are stored here for manual retry via API.
// NOTE: This map is lost on service restart (acceptable for demo; persist to DB for production).

isolated map<NotificationMessage> dlqMessages = {};

// ─── Queue setup ──────────────────────────────────────────────────────────────
// Called once at module init before any listener starts.

function setupQueues() returns error? {
    // Use a dedicated short-lived client for queue setup.
    // A PRECONDITION_FAILED response from RabbitMQ closes the AMQP channel on
    // the client that made the call. By using a separate client here we keep
    // publisherClient's channel clean so it is usable after setup completes.
    rabbitmq:Client setupClient = check new (rabbitmqHost, rabbitmqPort, {
        auth: {
            username: rabbitmqUser,
            password: rabbitmqPassword
        }
    });

    // Main delivery queue (durable – survives broker restart)
    rabbitmq:Error? mainQueueResult = setupClient->queueDeclare(MAIN_QUEUE, {
        durable: true,
        autoDelete: false
    });
    if mainQueueResult is rabbitmq:Error {
        log:printWarn(string `Queue '${MAIN_QUEUE}' already exists, using existing definition.`);
    }

    // Retry queue – messages expire after RETRY_TTL_MS and are automatically
    // dead-lettered back to the main queue via the default exchange.
    rabbitmq:Error? retryQueueResult = setupClient->queueDeclare(RETRY_QUEUE, {
        durable: true,
        autoDelete: false,
        arguments: {
            "x-message-ttl": RETRY_TTL_MS,
            "x-dead-letter-exchange": "",          // default exchange
            "x-dead-letter-routing-key": MAIN_QUEUE
        }
    });
    if retryQueueResult is rabbitmq:Error {
        log:printWarn(string `Queue '${RETRY_QUEUE}' already exists, using existing definition.`);
    }

    // Dead Letter Queue – messages that exhausted all 3 automatic retries.
    // Stays populated until a manual retry is triggered via the API.
    rabbitmq:Error? dlqResult = setupClient->queueDeclare(DLQ, {
        durable: true,
        autoDelete: false
    });
    if dlqResult is rabbitmq:Error {
        log:printWarn(string `Queue '${DLQ}' already exists, using existing definition.`);
    }

    rabbitmq:Error? closeResult = setupClient->close();
    if closeResult is rabbitmq:Error {
        log:printWarn(string `Could not cleanly close setup client: ${closeResult.message()}`);
    }

    log:printInfo(string `RabbitMQ queues ready: ${MAIN_QUEUE}, ${RETRY_QUEUE}, ${DLQ}`);
}
