import xlibb/pipeline;
import ballerinax/rabbitmq;

final rabbitmq:MessageStore failureStore = check new ("errorhandling.order-failure", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});
final rabbitmq:MessageStore replayStore = check new ("errorhandling.order-replay", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});
final rabbitmq:MessageStore deadLetterStore = check new ("errorhandling.order-deadletter", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});

final pipeline:HandlerChain customerProfilePipeline = check new (
    name = "customer-profile-pipeline",
    processors = [
        step1_getCustomerProfile,
        mapTierToSegment,
        step2_calculatePricing
    ],
    destinations = [
        step3_doPurchase
    ],
    failureStore = failureStore,
    replayListenerConfig = {
        replayStore,
        deadLetterStore
    }
);