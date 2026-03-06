import ballerina/http;
import ballerina/log;
import ballerinax/rabbitmq;

// ─── Configurable connection parameters ───────────────────────────────────────
// Override in Config.toml or via BAL_CONFIG_DATA in ConfigMap for K8s

configurable string rabbitmqHost = "localhost";
configurable int rabbitmqPort = 5672;
configurable string rabbitmqUser = "admin";
configurable string rabbitmqPassword = "admin123";

// Backend notification receiver (Fund11 mock backend)
configurable string backendUrl = "http://localhost:9101";

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
    username: rabbitmqUser,
    password: rabbitmqPassword
});

// Consumer listener – shared by the main-queue and DLQ consumer services.
final rabbitmq:Listener mqListener = check new (rabbitmqHost, rabbitmqPort, {
    username: rabbitmqUser,
    password: rabbitmqPassword
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
    // Main delivery queue (durable – survives broker restart)
    check publisherClient->queueDeclare(MAIN_QUEUE, {
        durable: true,
        autoDelete: false
    });

    // Retry queue – messages expire after RETRY_TTL_MS and are automatically
    // dead-lettered back to the main queue via the default exchange.
    check publisherClient->queueDeclare(RETRY_QUEUE, {
        durable: true,
        autoDelete: false,
        arguments: {
            "x-message-ttl": RETRY_TTL_MS,
            "x-dead-letter-exchange": "",          // default exchange
            "x-dead-letter-routing-key": MAIN_QUEUE
        }
    });

    // Dead Letter Queue – messages that exhausted all 3 automatic retries.
    // Stays populated until a manual retry is triggered via the API.
    check publisherClient->queueDeclare(DLQ, {
        durable: true,
        autoDelete: false
    });

    log:printInfo(string `RabbitMQ queues declared: ${MAIN_QUEUE}, ${RETRY_QUEUE}, ${DLQ}`);
}
