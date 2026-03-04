// Mock database for bank accounts
map<BankAccount> accountDatabase = {
    "john_doe": {
        username: "john_doe",
        accountNumber: "ACC001234567",
        savingsBalance: 15000.50,
        currentAccountBalance: 3500.75,
        status: "ACTIVE"
    },
    "emma_premier": {
        username: "emma_premier",
        accountNumber: "ACC002345678",
        savingsBalance: 45000.00,
        currentAccountBalance: 12000.25,
        status: "ACTIVE"
    },
    "alex_cashier": {
        username: "alex_cashier",
        accountNumber: "ACC003456789",
        savingsBalance: 8500.30,
        currentAccountBalance: 2100.50,
        status: "ACTIVE"
    },
    "sarah_williams": {
        username: "sarah_williams",
        accountNumber: "ACC004567890",
        savingsBalance: 22000.00,
        currentAccountBalance: 5500.00,
        status: "ACTIVE"
    },
    "michael_brown": {
        username: "michael_brown",
        accountNumber: "ACC005678901",
        savingsBalance: 67000.75,
        currentAccountBalance: 18000.00,
        status: "ACTIVE"
    },
    "lisa_anderson": {
        username: "lisa_anderson",
        accountNumber: "ACC006789012",
        savingsBalance: 12500.50,
        currentAccountBalance: 4200.30,
        status: "SUSPENDED"
    },
    "david_martinez": {
        username: "david_martinez",
        accountNumber: "ACC007890123",
        savingsBalance: 31000.00,
        currentAccountBalance: 9800.00,
        status: "ACTIVE"
    },
    "jennifer_taylor": {
        username: "jennifer_taylor",
        accountNumber: "ACC008901234",
        savingsBalance: 5500.25,
        currentAccountBalance: 1200.75,
        status: "ACTIVE"
    },
    "rami.desilva@auth0.com": {
        username: "rami.desilva@auth0.com",
        accountNumber: "ACC009012345",
        savingsBalance: 10000.00,
        currentAccountBalance: 2500.00,
        status: "ACTIVE"
    },
    "rami.desilva.pri@auth0.com": {
        username: "rami.desilva.pri@auth0.com",
        accountNumber: "ACC009012344",
        savingsBalance: 10234.00,
        currentAccountBalance: 1490.00,
        status: "ACTIVE"
    },
    "customUser": {
        username: "customUser",
        accountNumber: "ACC0090123454",
        savingsBalance: 156.00,
        currentAccountBalance: 149.00,
        status: "ACTIVE"
    }
};

// Mock transaction history database
map<Transaction[]> transactionDatabase = {
    "john_doe": [
        {
            transactionId: "TXN001",
            transactionType: "DEPOSIT",
            amount: 5000.00,
            fromAccount: "external",
            toAccount: "savings",
            timestamp: "2024-01-15T10:30:00Z",
            status: "COMPLETED"
        },
        {
            transactionId: "TXN002",
            transactionType: "TRANSFER",
            amount: 1000.00,
            fromAccount: "savings",
            toAccount: "current",
            timestamp: "2024-01-20T14:15:00Z",
            status: "COMPLETED"
        }
    ],
    "emma_premier": [
        {
            transactionId: "TXN003",
            transactionType: "WITHDRAWAL",
            amount: 2000.00,
            fromAccount: "current",
            toAccount: "external",
            timestamp: "2024-01-18T09:45:00Z",
            status: "COMPLETED"
        }
    ]
};

// Mock contact info database
map<ContactInfo> contactDatabase = {
    "john_doe": {
        email: "john.doe@email.com",
        phone: "+1-555-0101",
        address: "123 Main St, New York, NY 10001"
    },
    "emma_premier": {
        email: "emma.premier@email.com",
        phone: "+1-555-0102",
        address: "456 Oak Ave, Los Angeles, CA 90001"
    },
    "alex_cashier": {
        email: "alex.cashier@email.com",
        phone: "+1-555-0103",
        address: "789 Pine Rd, Chicago, IL 60601"
    }
};

// Mock loan applications database
map<LoanApplicationResponse> loanApplicationsDatabase = {};
