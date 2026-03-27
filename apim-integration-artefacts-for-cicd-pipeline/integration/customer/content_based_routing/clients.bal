import xlibb/pipeline;
import ballerinax/rabbitmq;

// final rabbitmq:MessageStore failureStore = check new ("contentbasedrouting.order-failure", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});
final rabbitmq:MessageStore failureStore = check new ("contentbasedrouting.order-failure", {
    host: rabbitmqHost,
    port: rabbitmqPort,
    connectionData: {
        username: rabbitmqUser,
        password: rabbitmqPassword
    },
    declareQueue: {
        queueConfig: {autoDelete: false}
    }
});

// final rabbitmq:MessageStore replayStore = check new ("contentbasedrouting.order-replay", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});
final rabbitmq:MessageStore replayStore = check new ("contentbasedrouting.order-replay", {
    host: rabbitmqHost,
    port: rabbitmqPort,
    connectionData: {
        username: rabbitmqUser,
        password: rabbitmqPassword
    },
    declareQueue: {
        queueConfig: {autoDelete: false}
    }
});

// final rabbitmq:MessageStore deadLetterStore = check new ("contentbasedrouting.order-deadletter", {host: rabbitmqHost, port: rabbitmqPort, connectionData: {username: rabbitmqUser, password: rabbitmqPassword}});
final rabbitmq:MessageStore deadLetterStore = check new ("contentbasedrouting.order-deadletter", {
    host: rabbitmqHost,
    port: rabbitmqPort,
    connectionData: {
        username: rabbitmqUser,
        password: rabbitmqPassword
    },
    declareQueue: {
        queueConfig: {autoDelete: false}
    }
});

final pipeline:HandlerChain soapRoutingPipeline = check new (
    name = "soap-routing-pipeline",
    processors = [
        dummyTransformer
    ],
    destinations = [
        forwardNotification
    ],
    failureStore = failureStore,
    replayListenerConfig = {
        replayStore,
        deadLetterStore
    }
);