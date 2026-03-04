// import ballerina/ai;
import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;

// Customer API listener on port 8080
listener http:Listener customerListener = check new http:Listener(8080);

// Employee API listener on port 8081
listener http:Listener employeeListener = check new http:Listener(8081);

// Customer-facing API service
service /bank/customer on customerListener {

    function init() {
        log:printInfo("Customer service initialized on port 8080");
    }

    // Get account details by username
    resource function post account(@http:Payload UsernameRequest request) returns AccountResponse|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        AccountResponse accountResponse = {
            accountNumber: bankAccount.accountNumber,
            savingsBalance: bankAccount.savingsBalance,
            currentAccountBalance: bankAccount.currentAccountBalance,
            status: bankAccount.status
        };
        return accountResponse;
    }

    // Transfer funds between accounts
    resource function post transfer(@http:Payload TransferRequest request) returns SuccessResponse|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        // Validate account types
        if request.fromAccount != "savings" && request.fromAccount != "current" {
            ErrorResponse errorResponse = {
                message: "Invalid fromAccount. Must be 'savings' or 'current'"
            };
            return errorResponse;
        }

        if request.toAccount != "savings" && request.toAccount != "current" {
            ErrorResponse errorResponse = {
                message: "Invalid toAccount. Must be 'savings' or 'current'"
            };
            return errorResponse;
        }

        if request.fromAccount == request.toAccount {
            ErrorResponse errorResponse = {
                message: "Cannot transfer to the same account"
            };
            return errorResponse;
        }

        // Check sufficient balance
        decimal fromBalance = request.fromAccount == "savings" ? bankAccount.savingsBalance : bankAccount.currentAccountBalance;
        if fromBalance < request.amount {
            ErrorResponse errorResponse = {
                message: "Insufficient balance in " + request.fromAccount + " account"
            };
            return errorResponse;
        }

        // Perform transfer
        if request.fromAccount == "savings" {
            bankAccount.savingsBalance = bankAccount.savingsBalance - request.amount;
            bankAccount.currentAccountBalance = bankAccount.currentAccountBalance + request.amount;
        } else {
            bankAccount.currentAccountBalance = bankAccount.currentAccountBalance - request.amount;
            bankAccount.savingsBalance = bankAccount.savingsBalance + request.amount;
        }

        // Update account in database
        accountDatabase[username] = bankAccount;

        // Create transaction record
        time:Utc currentTime = time:utcNow();
        string timestamp = time:utcToString(currentTime);
        string transactionId = "TXN" + currentTime[0].toString();

        Transaction newTransaction = {
            transactionId: transactionId,
            transactionType: "TRANSFER",
            amount: request.amount,
            fromAccount: request.fromAccount,
            toAccount: request.toAccount,
            timestamp: timestamp,
            status: "COMPLETED"
        };

        // Add to transaction history
        Transaction[]? existingTransactions = transactionDatabase[username];
        if existingTransactions is () {
            transactionDatabase[username] = [newTransaction];
        } else {
            existingTransactions.push(newTransaction);
        }

        SuccessResponse successResponse = {
            message: "Transfer of $" + request.amount.toString() + " from " + request.fromAccount + " to " + request.toAccount + " completed successfully"
        };
        return successResponse;
    }

    // Get transaction history
    resource function post transactions(@http:Payload UsernameRequest request) returns Transaction[]|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        Transaction[]? userTransactions = transactionDatabase[username];
        if userTransactions is () {
            return [];
        }

        return userTransactions;
    }

    // Update contact information
    resource function post contact/update(@http:Payload ContactUpdateRequest request) returns SuccessResponse|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        ContactInfo? existingContact = contactDatabase[username];
        ContactInfo updatedContact = existingContact is () ? {
                email: "",
                phone: "",
                address: ""
            } : existingContact;

        // Update only provided fields
        string? emailValue = request.email;
        if emailValue is string {
            updatedContact.email = emailValue;
        }
        string? phoneValue = request.phone;
        if phoneValue is string {
            updatedContact.phone = phoneValue;
        }
        string? addressValue = request.address;
        if addressValue is string {
            updatedContact.address = addressValue;
        }

        contactDatabase[username] = updatedContact;

        SuccessResponse successResponse = {
            message: "Contact information updated successfully"
        };
        return successResponse;
    }

    // Get contact information
    resource function post contact(@http:Payload UsernameRequest request) returns ContactInfo|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        ContactInfo? userContact = contactDatabase[username];
        if userContact is () {
            ErrorResponse errorResponse = {
                message: "Contact information not found for username: " + username
            };
            return errorResponse;
        }

        return userContact;
    }

    // Submit loan application
    resource function post loan/apply(@http:Payload LoanRequest request) returns LoanApplicationResponse|ErrorResponse {
        string username = request.username;
        BankAccount? bankAccount = accountDatabase[username];

        if bankAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        // Check account status
        if bankAccount.status != "ACTIVE" {
            ErrorResponse errorResponse = {
                message: "Cannot apply for loan. Account status is: " + bankAccount.status
            };
            return errorResponse;
        }

        // Validate loan type
        if request.loanType != "PERSONAL" && request.loanType != "HOME" && request.loanType != "AUTO" {
            ErrorResponse errorResponse = {
                message: "Invalid loan type. Must be 'PERSONAL', 'HOME', or 'AUTO'"
            };
            return errorResponse;
        }

        // Generate application ID
        time:Utc currentTime = time:utcNow();
        string applicationId = "LOAN" + currentTime[0].toString();

        // Simple approval logic based on savings balance
        string approvalStatus = "PENDING";
        string responseMessage = "Your loan application has been submitted and is under review";

        if bankAccount.savingsBalance >= request.amount * 0.2d {
            approvalStatus = "APPROVED";
            responseMessage = "Congratulations! Your loan application has been approved";
        } else if bankAccount.savingsBalance < request.amount * 0.1d {
            approvalStatus = "REJECTED";
            responseMessage = "Unfortunately, your loan application has been rejected due to insufficient savings";
        }

        LoanApplicationResponse loanResponse = {
            applicationId: applicationId,
            status: approvalStatus,
            message: responseMessage
        };

        // Store loan application
        loanApplicationsDatabase[applicationId] = loanResponse;

        return loanResponse;
    }
}

// Employee-facing API service
service /bank/employee on employeeListener {

    function init() {
        log:printInfo("Employee service initialized on port 8081");
    }

    // List all user accounts
    resource function get accounts() returns BankAccount[] {
        BankAccount[] allAccounts = accountDatabase.toArray();
        return allAccounts;
    }

    // Delete user account by username
    resource function post account/delete(@http:Payload UsernameRequest request) returns SuccessResponse|ErrorResponse {
        string username = request.username;
        BankAccount? removedAccount = accountDatabase.removeIfHasKey(username);

        if removedAccount is () {
            ErrorResponse errorResponse = {
                message: "Account not found for username: " + username
            };
            return errorResponse;
        }

        SuccessResponse successResponse = {
            message: "Account deleted successfully for username: " + username
        };
        return successResponse;
    }
}

// listener ai:Listener bankAgentListener = new (listenOn = check http:getDefaultListener());

// service /bankAgent on bankAgentListener {
//     private final ai:Agent bankAgentAgent;

//     function init() returns error? {
//         self.bankAgentAgent = check new (
//             systemPrompt = {role: string ``, instructions: string ``}, model = aiWso2modelprovider, tools = [aiMcpbasetoolkit]
//         );
//     }

//     isolated resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
//         string stringResult = check self.bankAgentAgent.run(request.message, request.sessionId);
//         return {message: stringResult};
//     }
// }
