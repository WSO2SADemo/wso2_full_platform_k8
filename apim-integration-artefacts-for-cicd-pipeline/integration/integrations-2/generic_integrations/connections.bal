import ballerinax/mysql;

// MySQL Client with ODBC connection
final mysql:Client mysqlClient = check new (
    host = mysqlHost,
    port = mysqlPort,
    user = mysqlUser,
    password = mysqlPassword,
    database = mysqlDatabase,
    options = {
        connectTimeout: 30,
        socketTimeout: 0
    }
);
